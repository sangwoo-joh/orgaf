# orgaf

Org-mode parser written leveraging Angstrom and Faraday.

Based on [org-mode syntax v2](https://orgmode.org/worg/org-syntax.html)

# Status
 * :green_circle: : fully supported.
 * :heavy_exclamation_mark: : partially supported or implemented in a different way due to certain limitations.
 * :x: : not supported.
 * :construction: : work in progress.

The parser targets the **core subset** of the Org syntax; the long tail
(footnotes, macros expansion, citations, inline tasks, LaTeX, affiliated
keywords, `#+TBLFM` evaluation, …) is intentionally left as unfilled slots in the
AST.

## Elements

| Component             | Status                    |
|-----------------------|---------------------------|
| Headings and Sections | :green_circle:            |
| Greater Elements      | :heavy_exclamation_mark:  |
| Lesser Elements       | :heavy_exclamation_mark:  |


### Headings and Sections

| Component          | Status                   | Notes                                                                       |
|--------------------|--------------------------|-----------------------------------------------------------------------------|
| Headings           | :heavy_exclamation_mark: | stars, TODO/DONE keyword, `[#A]` priority, COMMENT, title, tags; single-character priority only, no `todo-type`/archive semantics |
| Sections           | :green_circle:           |                                                                             |
| The Zeroth Section | :green_circle:           | property drawer and leading comment extracted                               |

### Greater Elements

| Component            | Status                   | Notes                                                            |
|----------------------|--------------------------|------------------------------------------------------------------|
| Greater Blocks       | :green_circle:           | center / quote / special; contents parsed recursively            |
| Drawers              | :green_circle:           |                                                                  |
| Property Drawers     | :green_circle:           |                                                                  |
| Dynamic Blocks       | :x:                      | `#+begin:` not recognized (currently seen as a keyword)          |
| Footnote Definitions | :green_circle:           | contents parsed; ends at next footnote / heading / two blank lines |
| Inlinetasks          | :x:                      |                                                                  |
| Items                | :green_circle:           | bullet, counter-set, check-box, tag; indentation-based nesting   |
| Plain Lists          | :green_circle:           | ordered / descriptive / unordered                                |
| Tables               | :heavy_exclamation_mark: | Org tables (structure); `#+TBLFM` captured raw, not evaluated; `table.el` tables unsupported |

### Lesser Elements

| Component          | Status                   | Notes                                                              |
|--------------------|--------------------------|--------------------------------------------------------------------|
| Blocks             | :green_circle:           | src / example / export / comment / verse                           |
| Clock              | :x:                      |                                                                    |
| Diary Sexp         | :x:                      |                                                                    |
| Planning           | :green_circle:           | SCHEDULED / DEADLINE / CLOSED; ranges and repeater/delay captured  |
| Comments           | :green_circle:           |                                                                    |
| Fixed Width Areas  | :green_circle:           |                                                                    |
| Horizontal Rules   | :green_circle:           |                                                                    |
| Keywords           | :heavy_exclamation_mark: | generic `#+KEY: VALUE`; affiliated keywords attached (CAPTION parsed); `#+call:` not special-cased |
| LaTeX Environments | :green_circle:           | contents kept raw (for MathJax/KaTeX)                              |
| Node Properties    | :green_circle:           | within property drawers                                            |
| Paragraphs         | :green_circle:           |                                                                    |
| Table Rows         | :green_circle:           | standard and rule rows                                             |


## Objects

| Component            | Status                   | Notes                                                                  |
|----------------------|--------------------------|------------------------------------------------------------------------|
| Entities             | :green_circle:           | `\name`, `\name{}`, `\_` whitespace                                    |
| LaTeX Fragments      | :green_circle:           | `$…$`, `$$…$$`, `\(…\)`, `\[…\]`, `\cmd{}`; kept raw                    |
| Export Snippets      | :green_circle:           | `@@backend:value@@`                                                    |
| Footnote References  | :green_circle:           | `[fn:LABEL]` and inline `[fn:LABEL:definition]`                        |
| Citations            | :x:                      |                                                                        |
| Citation References  | :x:                      |                                                                        |
| Inline Babel Calls   | :x:                      |                                                                        |
| Inline Source Blocks | :green_circle:           | `src_LANG[headers]{body}`                                              |
| Line Breaks          | :green_circle:           | `\\` at end of line                                                    |
| Links                | :heavy_exclamation_mark: | regular (id / custom-id / code-ref / hyperlink / fuzzy-file), angle, plain; radio links unsupported |
| Macros               | :green_circle:           |                                                                        |
| Targets              | :x:                      |                                                                        |
| Radio Targets        | :x:                      |                                                                        |
| Statistics Cookies   | :x:                      |                                                                        |
| Subscript            | :x:                      |                                                                        |
| Superscript          | :x:                      |                                                                        |
| Table Cells          | :green_circle:           |                                                                        |
| Timestamps           | :green_circle:           | active / inactive, ranges, repeater/delay raw; inline and in planning  |
| Text Markup          | :green_circle:           | bold / italic / underline / strike-through / code / verbatim           |
