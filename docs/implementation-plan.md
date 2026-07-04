# Implementation Plan — Unsticking the Parser with a Two-Pass Model

Companion to [`design.md`](./design.md). That doc explains *why* the parser needs
two passes; this doc is the *how* and *in what order*, given the code that exists
today.

---

## 0. Where the code actually is

| File            | State                                                                                   |
|-----------------|-----------------------------------------------------------------------------------------|
| `model.ml`      | **Done.** Full target AST for the whole org-syntax, `[@@deriving sexp]`.                 |
| `parse.ml`      | **Pass 2 only, partial.** Angstrom object parsers: plain text, entity, markup, links, macro. ~13 objects stubbed. |
| `primitive.ml`  | Char predicates. Fine, will be extended.                                                |
| `appendix.ml`   | Entity table. Fine.                                                                      |
| `tests/`        | One trivial test.                                                                        |

**The blocker:** there is no Pass 1. No line scanner, no element layer, no
`parse_document`. Every parser written so far lives *inside* a paragraph (objects).
The project got stuck trying to reach elements through Angstrom — which the design
doc says can't work. So this plan is mostly *net-new code* (Pass 1), not rework.

---

## 1. The one decision that shapes everything: how the two passes meet

`design.md §5` sketches an AST where inline-bearing fields (title, paragraph body,
cell) are held as **raw strings first**, then replaced by `object_ list` in Pass 2.

But the real `model.ml` has **no raw-string stage** — `title` is already
`object_ list`, `Lelt_Paragraph` is already `object_ list`. So we must pick:

- **(A) Separate skeleton type.** Add a parallel `element` type with raw strings,
  produce it in Pass 1, then transform → `Model.element`. Cost: a second full ADT
  that mirrors `model.ml`, plus a transform. Rejected — duplicates the AST.
- **(B) Invoke Pass 2 inline during the scan. (recommended)** The scanner holds raw
  text only in *local accumulators*. When it finalizes a paragraph / title / cell,
  it immediately runs the object parser on that fragment and stores the resulting
  `object_ list` straight into `Model`. The "two passes" stay conceptually distinct
  (structure decided without objects; objects parsed per-fragment, no global state),
  but the raw-string skeleton is transient and never enters the AST.

**We go with (B).** It keeps `model.ml` untouched and needs no second type. Concretely,
Pass 2 is exposed to Pass 1 as one function:

```ocaml
(* in parse.ml *)
val parse_inline : string -> Model.object_ list
(* = Angstrom.parse_string ~consume:All parse_object, with a plain-text fallback
   on parse failure so a malformed fragment never crashes the document parse *)
```

Everything below assumes (B).

### 1.1 Is (B) actually correct? (verified)

The worry with (B) is timing: if we parse a fragment's objects *mid-scan*, could a
later part of the document have changed the result? That can only happen if
`parse_object` depends on document-global state. **It does not** — `parse.ml:390`
`parse_object` is a pure `fix` combinator: no `ref`, no `mutable`, no `Hashtbl`, no
document argument. So `parse_inline frag` is a pure function of `frag`, and for
every implemented object + the entire core subset, **(B) ≡ (A): invocation timing
cannot change the result.**

Two rules make this hold, and both are about *fragment granularity, not timing* —
follow them and (B) is correct:

1. **Pass each whole inline-bearing region to `parse_inline` in one call.** Never
   split it. A paragraph's lines must be joined (newlines preserved) and parsed as
   one string, because objects (e.g. bold) can wrap across lines, and the PRE-char
   condition (the FIXME at `parse.ml:115`) needs the full left context. Table cells
   are independent regions (markup never crosses `|`), so per-cell parsing is correct.
2. **Keep macros unexpanded.** `{{{name}}}` stays an `Obj_Macro` node; expansion is
   downstream. Then `#+MACRO:` creates no parse-order dependency.

**The one boundary where (B-strict) genuinely fails — document-global objects:**

| Object                | Why it needs the whole document first                              |
|-----------------------|--------------------------------------------------------------------|
| Radio target / link   | `<<<foo>>>` defined *anywhere* (even later) turns earlier plain `foo` into a link, via a buffer-wide regexp. |
| `#+LINK:` abbreviation | `[[gh:x]]` resolution depends on a `#+LINK: gh …` keyword that may appear later. |

These break *any* fragment-by-fragment object parse — **(A) has the exact same
problem.** The fix is identical in both models: collect a registry *during* Pass 1
(just note every `<<<…>>>` and `#+LINK:`), then run object parsing *after* Pass 1 so
the registry is complete. That "after Pass 1" requirement is the *only* thing
(B-strict) gives up — and `design.md §7` already defers radio targets/abbreviations
to the long tail, so the core subset never hits it.

**Conclusion:** (B) for the core subset. If radio targets/`#+LINK:` are ever added,
move the `parse_inline` invocation from finalize-time to a post-Pass-1 walk fed by
the registry — a localized change, since the transient raw fragments are the only
thing that must survive until then.

---

## 2. Target module layout

```
lib/
  primitive.ml   (extend: line-level predicates)
  appendix.ml    (unchanged)
  model.ml       (unchanged; small tweaks only if a gap surfaces)
  parse.ml       (Pass 2: keep; add `parse_inline`, fill stubbed objects)
  line.ml        (NEW — line + cursor abstraction)
  scanner.ml     (NEW — Pass 1 stateful scanner → flat element list)
  nest.ml        (NEW — flat → tree by headline level; zeroth section)
  orgaf.ml       (NEW — `parse_document : string -> Model.document`, the public entry)
```

Keep Pass 1 (`line`/`scanner`/`nest`) and Pass 2 (`parse`) in separate modules so
the boundary in the design doc is visible in the file structure.

---

## 3. Phases

Each phase ends with a concrete verify step. Do them in order; every phase leaves
the tree building and testable.

### Phase 1 — Line abstraction (`line.ml`)

The scanner is line-oriented, so give it a proper line type instead of raw strings.

```ocaml
type t = {
  raw     : string;   (* original line, no newline *)
  indent  : int;      (* leading blank columns; tab = 8 per FEATURE.md *)
  content : string;   (* raw with indent stripped *)
  blank   : bool;     (* content is empty/whitespace only *)
}

val split   : string -> t list          (* handle \n, \r\n *)
type cursor
val of_lines : t list -> cursor
val peek    : cursor -> t option
val advance : cursor -> cursor
val prev    : cursor -> t option        (* one-line lookback for planning / prop drawer *)
```

- **Verify:** unit test `split` on mixed line endings and indentation; `indent` of
  `"\t x"` is 9.

### Phase 2 — First-line dispatch, single-line & paragraph only (`scanner.ml`)

Implement the scanner loop from `design.md §3.3`, but only the cases that need **no
paired state** yet:

- headline (`^\*+ `) → emit `Elt_Heading` skeleton (level + raw title; title via
  `parse_inline`), *flat*, nesting deferred to Phase 4.
- keyword (`^#\+KEY: VALUE`) → `Lelt_Keyword`.
- comment (`^# ` / bare `#`), fixed-width (`^: ` / bare `:`) → accumulate runs.
- horizontal rule (`^-----`).
- paragraph fallback: accumulate until blank line or next-element start, then
  `parse_inline` the joined text → `Lelt_Paragraph`.

Dispatch lives in `primitive.ml` as predicates (`is_headline_start`, etc.) so
`scanner.ml` reads as a table.

- **Verify:** a document of headlines + paragraphs + keywords round-trips to the
  expected *flat* `element list` (compare via `sexp_of`).

### Phase 3 — Paired elements (the actual context-sensitivity)

Add the `mode` state (`Normal | InBlock of end_marker | InDrawer of end_marker`)
and consume bodies raw. This is where `#+begin_src … * not a headline … #+end_src`
gets solved.

- blocks: `#+begin_NAME … #+end_NAME`. Route by NAME to
  `Src_block`/`Example_Block`/`Export_Block`/`Comment_Block`/`Verse_Block`
  (lesser) vs greater/dynamic block. **Body stays `string` — never `parse_inline`d**
  (except verse: verse body *is* inline).
- drawers: `:NAME: … :END:`. Property drawer (`:PROPERTIES:` right under a headline
  or its planning line) vs generic drawer — uses `Line.prev` lookback.

- **Verify:** the `design.md §6` worked example parses; assert the src body string
  literally contains `* not a headline` and that no headline element was emitted
  from inside the block.

### Phase 4 — Structure assembly (`nest.ml`)

Turn the flat sequence into the document tree (`design.md §3.4`):

- stack keyed on headline `level` → nest deeper headlines + their sections.
- gather each headline's following non-headline elements into its `section`.
- zeroth section: elements before the first headline → `Elt_Zeroth_Section`
  (may hold a property drawer; no planning — per `FEATURE.md`).
- planning line (`SCHEDULED:`/`DEADLINE:`/`CLOSED:`) directly after a headline →
  `heading.planning` (needs Phase 6 timestamp parser; until then keep the raw line
  and fill later).

- **Verify:** `(document (section) (heading (section) (heading) (heading (heading))))`
  shape from `FEATURE.md §Sections` reproduces.

### Phase 5 — Lists & tables (multi-line, same-kind accumulation)

Contiguous-line elements with their own internal structure:

- plain lists / items: bullet dispatch, indentation-based nesting, `[ ]/[X]/[-]`
  check-boxes, `TAG ::`. Item contents recurse back through the scanner.
- tables: `^|` runs → rows; `|---` → rule rows; cells via `parse_inline`; trailing
  `#+TBLFM:` captured as raw `formulas` (no evaluation — long tail per `design.md §7`).

- **Verify:** nested list from `FEATURE.md §Plain Lists` and the Org table example
  parse to the expected row/item counts.

### Phase 6 — Fill Pass-2 object gaps

Independent of Pass 1; can be parallelized. Priority by what Pass 1 needs and what
the core subset (`design.md §7`) targets:

1. **timestamp** — needed by planning (Phase 4) and clock. Do first.
2. line break, target, radio target, statistics cookie, sub/superscript.
3. latex fragment, export snippet, footnote reference, inline babel/src.
4. citation / citation-reference — long tail, defer.

Also fix the two known Pass-2 defects flagged in `parse.ml`:
- `markup_pre_condition` checks the char *after* the marker instead of *before* it
  (the PRE token). Requires threading the preceding char — most cleanly done by
  having `parse_inline` track the previous character, or post-filtering.
- `parse_plain_link` reuses markup PRE/POST conditions as a stopgap.

- **Verify:** per-object Alcotest cases (extend `tests/test.ml`, which currently has one).

### Phase 7 — Public entry + docs

- `orgaf.ml`: `parse_document : string -> Model.document` = split → scan → nest.
- Update `README.md` status tables (all currently blank) as each element/object lands.

- **Verify:** end-to-end test parsing a real `.org` note file; `dune build @doc` clean.

---

## 4. Scope guardrails (from `design.md §7`)

Implement the **core subset first**, stop each feature at structure depth:

> headline + property drawer, paragraph, emphasis, links (`id:`/`http`/`file`),
> plain list, src/example block, table (structure only), keywords
> (`#+title`/`#+filetags`).

Explicitly deferred to the long tail: `#+TBLFM` evaluation, footnotes, macros
expansion, `#+INCLUDE`, inlinetasks, affiliated keywords, full entity/LaTeX. The
AST in `model.ml` already *has slots* for these — leaving them unfilled is fine and
does not block the core.

---

## 5. Suggested ordering

Phases 1→2→3→4 are the critical path (they are Pass 1 and unblock the project).
Phase 6.1 (timestamp) is a prerequisite for planning in Phase 4. Phases 5 and the
rest of 6 can proceed in parallel once 1–4 land. Do **not** start Phase 5 before
Phase 3 — lists/tables reuse the paired-mode machinery.

```
1 ── 2 ── 3 ── 4 ─┬─ 5
                  └─ 7
6.1 ──────────────┘   (timestamp feeds Phase 4 planning)
6.2/6.3 … parallel, non-blocking
```
