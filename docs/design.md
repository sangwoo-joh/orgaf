# OCaml Org-mode Parser — Architecture

A design for parsing Org-mode in OCaml, mimicking `org-element.el`'s **two-pass**
model. Written so a fresh session can pick up implementation from this file alone.

---

## 1. Why not pure Angstrom

Org is **context-sensitive** and **line-oriented**. A single parser-combinator
pass fails because the meaning of a line depends on state:

```org
#+begin_src ocaml
let x = "* not a headline" in x   (* the '*' here is NOT a headline *)
#+end_src
```

Inside a source block, `*foo*` is not bold and `* bar` is not a headline — the
text is raw. Whether a line is structure or raw depends on "which block are we
currently inside." Pure combinators handle this only via backtracking or
double-parsing, which explodes.

`org-element.el` solves this with two passes, and so do we.

---

## 2. The two-pass model

Org distinguishes two layers:

- **Elements** — line-oriented structural units (headline, paragraph, list,
  table, src block, drawer, keyword…). Boundaries are decided by how lines
  *begin*.
- **Objects** — inline units inside an element's text (bold, italic, code, link,
  timestamp…).

Key fact (from the Org syntax spec): *only headlines and sections can be
recognized just by looking at the start of a line* — but nearly every element is
still identified by a fixed leading marker on its first line. Objects can only be
parsed **after** the containing element is known, because element type decides
whether inline parsing even applies.

Therefore:

- **Pass 1 (elements):** a hand-written, stateful **line scanner**. Not Angstrom.
  Produces the element skeleton. For each element, tags its text either as
  *inline-bearing* or *raw*.
- **Pass 2 (objects):** **Angstrom**, run independently on each inline-bearing
  text fragment. Signature is just `string -> inline list`.

Angstrom is demoted to the inline layer, where it fits well (local patterns, no
global state). It never touches document structure.

```
raw text
  │
  ├─ Pass 1: line scanner (stateful) ──▶ element tree + tagged text fragments
  │
  └─ Pass 2: Angstrom (string -> inline list) on inline-bearing fragments only
                                          ──▶ full AST
```

---

## 3. Pass 1 — the line scanner

### 3.1 First-line dispatch

Almost every element is identified by the leading pattern of its first line.
Dispatch on the first significant character, in priority order:

| Leading pattern            | Element                          |
|----------------------------|----------------------------------|
| `^\*+ ` (stars + space)    | headline                         |
| `^[ \t]*#\+begin_NAME`     | block (src/example/greater)      |
| `^[ \t]*#\+KEY: `          | keyword (`#+title:`, …)          |
| `^[ \t]*# ` or `#` alone   | comment                          |
| `^[ \t]*:NAME:`            | drawer / property drawer start   |
| `^[ \t]*: ` or `:` alone   | fixed-width                      |
| `^[ \t]*\|`                | table                            |
| `^[ \t]*(BULLET)(space)`   | list item (`-`, `+`, `1.`, `1)`) |
| `^[ \t]*-----`             | horizontal rule                  |
| `^[ \t]*\\begin{`          | LaTeX environment                |
| *anything else / no match* | **paragraph** (the default)      |

Paragraph is the fallback: accumulate lines until a blank line or the start of
another element.

### 3.2 State — the two things that make it context-sensitive

First-line dispatch alone is not enough. Two cases need state:

**(a) Paired elements (blocks, drawers).** After an opening line, consume every
following line *without dispatching* until the matching closer, storing the body
raw:

```
#+begin_src   →  collect raw lines until  #+end_src
:PROPERTIES:  →  collect key:value lines until  :END:
```

This is exactly where the "`* not a headline`" problem is solved: while in block
mode, lines are body, not structure.

**(b) Position-dependent elements.** A `SCHEDULED:`/`DEADLINE:` line is *planning*
only when it directly follows a headline; a property drawer is a property drawer
only when it sits right under a headline (or its planning line). One line of
lookback resolves this.

So the scanner carries:

```
mode : Normal | InBlock of end_marker | InDrawer of end_marker
prev : previous element kind        (* for planning / property drawer *)
```

### 3.3 Scanner loop (pseudocode)

```
for each line:
  match mode with
  | InBlock end | InDrawer end ->
      if line matches end -> close element, mode := Normal
      else                -> append line to current element's RAW body   (no dispatch)
  | Normal ->
      dispatch on first-line pattern:
        opens a block/drawer  -> emit element, mode := InBlock/InDrawer end
        single-line element   -> emit element (headline, keyword, hr, …)
        table / list line     -> accumulate contiguous lines of same kind
        no match              -> accumulate into paragraph
                                 (flush on blank line or next element start)
```

Output: a **flat** element sequence. Headlines are markers carrying a `level`.

### 3.4 Nesting by headline level

Headline nesting is a separate, trivial structuring step after the flat scan: a
stack keyed on `level` turns the flat sequence into a tree (deeper headlines and
their sections become children). Keeping this out of the scanner keeps the
scanner simple.

---

## 4. Which text is inline-bearing vs raw

Pass 2 runs Angstrom **only** on inline-bearing fragments. Element type decides:

| Element                         | Text handling                    |
|---------------------------------|----------------------------------|
| paragraph body                  | inline-bearing → Angstrom        |
| headline title                  | inline-bearing → Angstrom        |
| table cell                      | inline-bearing → Angstrom        |
| list item text                  | inline-bearing → Angstrom        |
| **src block / example block**   | **raw** — never parsed as inline |
| keyword value                   | raw string                       |
| property drawer entries         | raw key/value                    |

This split *is* the reason the two passes exist.

---

## 5. AST sketch

```ocaml
type document = {
  keywords : (string * string) list;   (* #+title:, #+filetags:, … *)
  children : element list;
}

and element =
  | Headline of headline
  | Paragraph of inline list
  | Src_block of { lang : string; body : string }   (* body RAW *)
  | Example_block of string                          (* RAW *)
  | Plain_list of item list
  | Table of table_row list
  | Keyword of string * string
  | Property_drawer of (string * string) list
  | Horizontal_rule

and headline = {
  level      : int;
  title      : inline list;
  tags       : string list;
  properties : (string * string) list;   (* includes :ID: *)
  children   : element list;
}

and item = { bullet : string; contents : element list }

and table_row =
  | Row of inline list list   (* cells *)
  | Rule                      (* |---+---| separator *)

and inline =
  | Text of string
  | Bold of inline list
  | Italic of inline list
  | Code of string                              (* verbatim, RAW *)
  | Link of { target : string; desc : inline list option }
  | Timestamp of string
```

- Pass 1 fills the `element` skeleton; inline-bearing fields are held as raw
  strings first.
- Pass 2 replaces those raw strings with `inline list` via Angstrom.
- `Src_block.body` and `Code` stay `string` — never inline-parsed.

---

## 6. Worked example

Input:

```org
#+title: Notes

* Traps to Developers
:PROPERTIES:
:ID: a2295e7f-ddc4-43dc-b1f8-0c8967b50c3e
:END:

Avoid *premature* optimization. See [[id:b13...][Rules]].

#+begin_src ocaml
let x = "* not a headline" in x
#+end_src
```

**Pass 1 (skeleton, inline text still raw):**

```
Keyword ("title", "Notes")
Headline {
  level = 1; title = RAW "Traps to Developers";
  properties = [("ID", "a2295e7f-…")];
  children = [
    Paragraph (RAW "Avoid *premature* optimization. See [[id:b13...][Rules]].");
    Src_block { lang = "ocaml"; body = "let x = \"* not a headline\" in x" };
  ]
}
```

Note the src body — including its `* not a headline` — was captured raw by block
mode, never dispatched.

**Pass 2 (Angstrom on inline-bearing fragments):**

```
title    → [ Text "Traps to Developers" ]
Paragraph→ [ Text "Avoid "; Bold [Text "premature"]; Text " optimization. See ";
             Link { target = "id:b13..."; desc = Some [Text "Rules"] };
             Text "." ]
Src_block.body → untouched
```

`id:` links fall out of Pass 2 as `Link` nodes, which makes the graph step below
trivial.

---

## 7. Scope discipline

Two independent scopes; keep them separate:

- **Parser scope** ⊇ **builder scope**. The parser may cover more Org than any one
  consumer needs, but it is still **finite** — do not target 100% `org-element`
  parity. The cost is not the core grammar; it's the long tail (footnotes,
  macros, `#+INCLUDE`, inline tasks, entities, affiliated keywords, `#+TBLFM`).
- Scope per element by **(element × depth)**, not just element. Example: recognize
  tables (`^|` runs) in the core, but leave `#+TBLFM` formula evaluation in the
  long tail. This stops a single feature from dragging the parser into the tail.

Suggested core subset: headline + property drawer, paragraph, emphasis
(bold/italic/code), links (`id:`, `http`, `file`), plain list, src/example block,
table (structure only), keywords (`#+title`, `#+filetags`). LaTeX can be deferred
to client-side MathJax, as other static-site pipelines do.

---

## 8. Downstream (why this parser is the right base)

Once the AST exists, the rest is thin:

- **AST → HTML:** recursive traversal + `tyxml` or string templates. ADT +
  exhaustive match fits OCaml.
- **Static site:** file→URL routing, index/tag/backlink pages.
- **graph.json:** because `id:` links are already `Link` AST nodes, walking the
  AST to collect `(source_id, dest_id)` edges is a fold. No DB, no `org-roam.db`
  dependency — the parser owns the graph at compile time.

The project's real substance is the parser (Section 3). Everything downstream is
a thin shell over the AST.
