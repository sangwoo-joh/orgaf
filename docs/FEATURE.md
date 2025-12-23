# Basics
## Elements
 * At the same or grater scope than a paragraph (cannot be in a paragraph)

## Objects
 * A smaller scope than a paragraph (within a paragraph)

## Blank Lines
 * Containing only spaces, tabs, newlines, line feeds (`\t\n\r`)
 * Separate paragraphs and other elements
 * Considered a part of preceding element.
   * exception: list items, footnote definitions. they're using it as a part of syntax definition.

## Indentation
```org
    This paragraph will not contain
    a long sequence of spaces before "a".

    This paragraph does not have leading spaces according to the parser.

    #+begin_src emacs-lisp
      (+ 1 2)
    #+end_src
    The above source block preserves two leading spaces inside the code
    after removing the common indentation.
```

 * Series of space and tab at the beginning of a line.
 * Cannot be indented: headings, inlinetasks, footnote definitions, diary sexps.
 * Syntactically meaningful: plain list
   * space=single, tab=8


## Minimal set of objects
 * Plain text
 * Text markup
 * Entities
 * LaTeX fragments
 * Superscripts
 * Subscripts

## Standard set of objects
 * Entire set of objects, except for citation references and table cells

# Syntax
## General form
 * A series of (named) tokens separated by a space
   * A space = one or more horizontal whitespace characters
 * Tokens are either a string or a series of elements or objects

## Special tokens
```org
PRE TOKEN POST
```

 * Stateful patterns.
 * They are only matched against the *contents* of the containing object.
 * PRE and POST tokens, e.g.


## General Structure
 * org document = a sequence of elements
 * elements = recursively have other elements and/or objects

# Elements
```org
BEGIN
CONTENTS | VALUE
END
BLANK
```

 * a sequence of markup + and the blank lines after.
 * BEGIN: Opening markup
 * CONTENTS: a sequence of child elements/objects
 * VALUE: element value when no child elements/objects are allowed
 * END: closing markup
 * BLANK

## Headings

```org
STARS KEYWORD PRIORITY COMMENT TITLE TAGS
*
** DONE
*** Some e-mail
**** TODO [#A] COMMENT Title :tag:a2%:
```

 * **Unindented**
 * STARS: one or more asterisks. the number of asterisks = the level of headings. space after asterisk is mandatory.
 * KEYWORD (optional): case sensitive. "todo keyword" (`org-todo-keywords-1`)
 * PRIORITY (optional): square-bracketed # + a capital English alphabet [A-Z] or an integer [0-64]. e.g., `[#A]`, `[#27]`. "priority cookie"
 * COMMENT (optional): case sensitive. string. "commented"
 * TITLE (optional): a series of standard set objects except for line break. Matched after KEYWORD and PRIORITY.
   * if it is the same of `org-footnote-section` then "footnote section" (case sensitive)
 * TAGS (optional): a series of colon-separated regexp string [a-zA-Z0-9_@#%]
   * in case of `ARCHIVE`, then "archived". case sensitive
 * All content after a heading (up to next heading or eof) forms a "section" of the heading.

### Sections
```org
An introduction.
* A Heading
Some text.
** Sub-Topic 1
** Sub-Topic 2
*** Additional entry
```

```lisp
(document
 (section)
 (heading
  (section)
  (heading)
  (heading
   (heading))))
```

  * one or more non-heading elements.
  * do not include blank lines right after the parent heading.
  * headings with only blank lines (no section) is possible.

### Zeroth section
 * All elements before the first heading.
 * able to contain property drawer.
 * not able to contain planning.

## Greater Elements
 * Can directly contain any greater or lesser element, **except**:
   * Elements of their own type
   * Planning (may only in a heading)
   * Property drawers (may only in a heading or zeroth section)
   * Node properties (only in property drawers)
   * Items (may only in plain lists)
   * Table rows (may only in tables)

### Greater Blocks
```org
#+begin_NAME PARAMETERS
CONTENTS
#+end_NAME
```

 * NAME: A string of non-whitespace characters and not the NAME of a lesser block. Treated differently based on their subtype
   * center: Center Block
   * quote: Quote Block
   * any other value: Special Block
 * PARAMETERS (optional): A string without a newline
 * CONTENTS: A collection of 0+ elements. No line start with `#+end_NAME`

### Dynamic Blocks
```org
#+begin: NAME PARAMETERS
CONTENTS
#+end:
```

 * NAME: A string of non-whitespace characters
 * PARAMETERS (optional): A string without a newline
 * CONTENTS: A collection of 0+ elements. Except another dynamic block.

### Drawers
```org
:NAME:
CONTENTS
:end:
```

  * NAME: A string with word-constituent characters [a-zA-Z0-9], hyphens, and underscores
  * CONTENTS: A collection of 0+ elements, except another drawer

### Property Drawers
```org
HEADLINE
PROPERTYDRAWER

HEADLINE
PLANNING
PROPERTYDRAWER
```

 * Special type of Drawer containing properties attached to a heading or inlinetask (right after a heading and its planning information)


Or, in zeroth section:
```org
BEGINNING-OF-FILE
BLANK-LINES
COMMENT
PROPERTYDRAWER
```
 where BLANK-LINES and COMMENT are optional

```org
:properties:
CONTENTS
:end:
```
 * CONTENTS: A collection of 0+ node properties, not separated by blank lines

Example

```org
* Heading
:PROPERTIES:
:CUSTOM_ID: someid
:END:
```

### Footnote Definitions
```org
[fn:LABEL] CONTENTS
```

 * *MUST* occur at the start of an **unindented line**
 * LABEL: A number | WORD ([a-zA-Z0-9_-])
 * CONTENTS (optional): A collection of 0+ elements. Ends at the next footnote definition, the next heading, two consecutive blank lines, or the end of buffer.

Example:
```org
[fn:1] A short footnote.

[fn:2] This is a longer footnote.

It even contains a single blank line.
```

### Inlinetasks :question:
```org
*************** TODO some tiny task
This is a paragraph, it lies outside the inlinetask above.
*************** TODO some small task
                 DEADLINE: <2009-03-30 Mon>
                 :PROPERTIES:
                   :SOMETHING: or other
                 :END:
                 And here is some extra text
*************** END
```

 * Syntactically a heading with a level of at least `org-inlinetask-min-level` (which is default 15) (Dynamic level... cannot afford this)
 * (Optional) Can end with a second heading with a level of at least `org-inlinetask-min-level` with no optional components (i.e., only STARS and TITLE provided) and the string `END` as the TITLE. This allows the inlinetask to contain elements.
 * Only recognised after the `org-inlinetask` library is loaded.
 * Should this be supported?

### Items
```org
BULLET COUNTER-SET CHECK-BOX TAG CONTENTS
```

 * BULLET: One of the following, ends with a whitespace character or line ending
   * ` *` | `-` | `+` (NOTE: `*` at the beginning will match a heading)
   * `COUNTER.` or `COUNTER)` where COUNTER is [0-9a-z]{1}
 * COUNTER-SET (optional): An instance of pattern `[@COUNTER]`
 * CHECK-BOX (optional): `[ ]` | `[X]` | `[-]`
 * TAG (optional): An instance of pattern `TAG-TEXT ::`
   * TAG-TEXT: text up until the list occurrence of the substring ` :: ` (two colons surrounded by whitespace) on that line. Parsed with the standard set of objects.
 * CONTENT (optional): A collection of 0+ elements ending at the first instance of one of the following
   * The next item
   * The first line less or equally indented than the start line, not counting lines within other non-paragraph elements or inlinetask boundaries
   * Two consecutive blank lines
 * Can contain other lists -> Nested lists are allowed

Example
```org
- item
3. [@3] set to three
+ [-] tag :: item contents
 * item, note whitespace in front
* not an item, but heading - heading takes precedence
```

### Plain Lists
 * A set of consecutive items of the same indentation.
 * In case first item has COUNTER in its BULLET -> "ordered plain-list"
 * If it contains a TAG -> "descriptive list"
 * Otherwise -> "unordered list"

```org
1. item 1
2. [X] item 2
   - some tag :: item 2.1
```

```lisp
(ordered-plain-list
 (item
   (paragraph))
 (item
  (paragraph)
  (descriptive-plain-list
   (item
     (paragraph)))))
```

### Tables
```org
Org table:
| Name  | Phone | Age | Age - 24 |
|-------+-------+-----+----------|
| Peter |  1234 |  24 |       -1 |
| Anna  |  4321 |  25 |        7 |
| Susan |  9876 |  18 |          |
#+TBLFM: @<$4..@>>$4 = $3 - @+1$3

Table.el table:
+------+-----+-----+
|Name  |Phone|Age  |
+------+-----+-----+
|Peter |1234 |24   |
+------+-----+-----+
|Anna  |4321 |25   |
|Turner|     |     |
+------+-----+-----+
```

 * Started by a line beginning with one of the following:
   * `|` (Org table): End at the first line not starting with a vertical bar
   * `+-` followed by a sequence of `+` and `-` (Table.el table): End at the first line not starting with a vertical bar or a plus sign
   * Cannot be immediately preceded by such lines (will be part of the earlier table)
 * Contains table rows
 * Can be followed by a number of `#+TBLFM: FORMULAS` where FORMULAS represents a string consisting of any characters but a newline

## Lesser Elements
 * Cannot contain any other element
 * Only keywords of `org-element-parsed-keywords` (contains CAPTION), verse blocks, paragraphs, or table rows can contain objects

### (Lesser) Blocks
```org
#+begin_NAME DATA
CONTENTS
#+end_NAME
```

 * NAME: A string of non-whitespace characters
   * comment: comment block
   * example: example block
   * export: export block
   * src: source block
   * verse: verse block (NAME must be one of these values, otherwise it will match a greater block)
 * DATA (optional): A string without newline
   * export block: mandatory. single word.
   * source block: mandatory. `LANGUAGE SWITCHES ARGUMENTS`
     * LANGUAGE: A string of non-whitespace characters
     * SWITCHES: Any number of `SWITCH` separated by a single space character
       * SWITCH: `-l "FORMAT"` or `-S` or `+S`
         * FORMAT: string without a double quote or newline
         * S: single alphabetic character
   * ARGUMENTS: A string without newline
 * CONTENTS (optional): A string with any characters (including newlines) subject to the same conditions of greater blocks CONTENTS.
   * No line may start with `#+end_NAME`
   * Line beginning with `*` must be quoted by a comma (`,*`)
   * Line beginning with `#+` must be quoted by a comma when necessary (`#+`)
   * In case of a verse block -> org objects (without comma-quoting support)

### Clock
```org
clock: INACTIVE-TIMESTAMP
clock: INACTIVE-TIMESTAMP-RANGE DURATION
clock: DURATION
```
 * INACTIVE-TIMESTAMP: An inactive timestamp object
 * INACTIVE-TIMESTAMP-RANGE: An inactive range timestamp object
 * DURATION: An instance of `=> HH:MM`
   * HH: [0-9]{1,2}
   * MM: [0-9]{2}

Example
```org
clock: [2024-10-12]
CLOCK: [2019-03-25 Mon 10:49]--[2019-03-25 Mon 11:31] =>  0:42
clock: => 12:30
```

### Diary Sexp
```org
%%SEXP
```
 * **unindented** line structure with the pattern above
 * SEXP: A string starting with `(` with balanced parentheses.

### Planning
```org
HEADING
PLANNING
```
 * HEADING: A heading element
 * PLANNING: A line with 1+ `KEYWORD: TIMESTAMP` pattern ("info" pattern)
   * KEYWORD: One of the strings `DEADLINE`, `SCHEDULED`, or `CLOSED`
   * TIMESTAMP
 * MUST directly follow HEADING without any blank lines in between
 * In case of several KEYWORDs, the last one wins.

### Comments
 * "Comment Line"
 * Starts with `#`, followed by a whitespace or the immediate EOL
 * 1+ consecutive comment lines make comments

### Fixed Width Areas
 * "Fixed-width Line"
 * Starts with `:`, followed by a whitespace or the immediate EOL
 * 1+ consecutive fixed-width lines make fixed-width area

### Horizontal Rules
 * 5+ consecutive hyphens `-----`

### Keywords
```org
#+KEY: VALUE
```
 * KEY: A string of non-whitespace characters other than `call`
 * VALUE: A string without a newline
 * If KEY is `org-element-parsed-keywords` then VALUE can contain standard objects except for footnote references

#### Affiliated Keywords
```org
#+KEY: VALUE
#+KEY[OPTVAL]: VALUE
#+attr_BACKEND: VALUE
```
 * Every element type can be assigned attributes except for comments, clocks, headings, inlinetasks, items, node properties, planning, property drawers, sections, table rows
 * Affiliated keywords are not considered an element in their own right but a property of the element they apply to.
 * KEY: `org-element-affiliated-keywords` (CAPTION, DATA, HEADER, HEADERS, LABEL, NAME, PLOT, RESNAME, RESULT, RESULTS, SOURCE, SRCNAME, TBLNAME)
 * BACKEND: A string [a-zA-Z0-9_-]+
 * OPTVAL (optional): A string without a newline. Square brackets must be balanced. Only valid when KEY is member of `org-element-dual-keywords` (CAPTION, RESULTS)
 * VALUE: A string without a newline, except where KEY is member of `org-element-parsed-keywords` (Org objects) in which case VALUE is a series of objects from standard set except for footnote references.
 * 단독으로는 존재할 수 없고 반드시 어떤 element와 연관되어야 함.
 * 여러 개의 affiliated keywords가 있으면 마지막 인스턴스가 이김.
   * 예외: `#+header: `이고 여러 개의 `:opt val` 선언이 있을 때는 첫 번째 줄의 마지막 선언이 이김.
 * 다음 두 가지 경우에서는 VALUE가 하나가 아니라 여러 개로 쌓일 수 있음.
   1. KEY is member of `org-element-dual-keywords` (CAPTION, RESULTS)
   2. Instance of pattern `#+attr_BACKEND: VALUE`
 * Affiliated keyword 패턴 다음에 아무런 element가 없으면 -> non-affiliated keyword

#### Babel Call
```org
#+call: NAME(ARGUMENTS)
#+call: NAME[HEADER1](ARGUMENTS)
#+call: NAME(ARGUMENTS)[HEADER2]
#+call: NAME[HEADER1](ARGUMENTS)[HEADER2]
```
 * NAME: A string of non-whitespace characters except for `[]()`
 * ARGUMENTS (optional): A string of non-newline characters. Parenthesis must be balanced.
 * HEADER1 (optional), HEADER2 (optional): A string of non-newline characters. Square brackets must be balanced.

### LaTeX Environments
```org
\begin{NAME}EXTRA
CONTENTS
\end{NAME}
```

 * NAME: A non-empty string [a-zA-Z*]
 * EXTRA (optional): A string which does not contain substring `\end{NAME}`
 * CONTENTS (optional): same as EXTRA

### Node Properties
```org
:NAME: VALUE
:NAME:
:NAME+: VALUE
:NAME+:
```

 * ONLY in property drawers
 * NAME: A non-empty string of non-white characters, not end with a `+`
 * VALUE (optional): A string without a newline

### Paragraphs
 * The default element
 * Any unrecognised context is paragraph
 * Empty lines, other elements end paragraphs.
 * Can contain standard set of objects.

### Table Rows
 * `|` followed by
   * Any number of table cells -> standard type row
   * `-` -> rule type row (any non-newline characters can follow `-` and still be a rule type row)

# Objects
Can be found in the following elements:
 * (affiliated) keyword's VALUE when KEY is `org-element-parsed-keywords`
 * heading TITLE
 * inlinetask TITLE
 * item TAG
 * clock INACTIVE-TIMESTAMP, INACTIVE_TIMESTAMP-RANGE
 * planning TIMESTAMP
 * paragraphs
 * table cells
 * table rows
 * verse blocks

```org
BEGIN CONTENTS END BLANK
BEGIN VALUE END BLANK
```

 * Most objects CANNOT contain objects and newlines.
 * A blank line often terminates the element that the object is a part of, such as paragraphs
 * Trailing spaces at the end of objects are considered a part of them

```org
This *bold markup*      also includes the subsequent trailing spaces into
the bold object.

*This is not a bold markup

because the previous blank line separates the containing paragraph*.
```

## Entities
```org
\NAME POST
\NAME{}
\_SPACES
```
 * NAME: A string with a valid association in either `org-entities` or `org-entities-user`
 * POST: EOL or a non-alphabetic character
 * SPACES: 1+ spaces constituting a whitespace entity with name `_SPACES` from `org-entities` or `org-entities-user`

Example
```org
1\cent.
1.5em space:\_   here, all three spaces in =\_   = constitute the entity name.
```

## LaTeX Fragment
## Export Snippets
## Footnote References
## Citations
## Citation References
## Inline Babel Calls
## Inline Source Blocks
## Line Breaks
## Links
### Radio Links
### Plain Links
### Angle Links
### Regular Links
## Macros
## Targets
## Radio Targets
## Statistics Cookies
## Subscript
## Superscript
## Table Cells
## Timestamps
## Text Markup
## Plain Text
