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

 * NAME: A string with any non-whitespace characters and not the NAME of a lesser block. Treated differently based on their subtype
   * center: Center Block
   * quote: Quote Block
   * any other value: Special Block
 * PARAMETERS (optional): A string with any characters other than a newline
 * CONTENTS: A collection of zero or more elements. No line start with `#+end_NAME`


### Dynamic Blocks
### Drawers
### Property Drawers
### Footnote Definitions
### Inlinetasks
### Items
### Plain Lists
### Tables

## Lesser Elements
### Blocks
### Clock
### Diary Sexp
### Planning
### Comments
### Fixed Width Areas
### Horizontal Rules
### Keywords
### LaTeX Environments
### Node Properties
### Paragraphs
### Table Rows

# Objects
## Entities
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
