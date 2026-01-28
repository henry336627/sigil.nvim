# Features: sigil

## Symbol Prettification

### Global and filetype-specific symbols
**Description:** Replace configured text patterns with Unicode symbols while editing, without changing buffer text.

**Example:**
```
Input:  lambda -> x
Output: λ → x   (displayed)
```

### Context-aware filtering (strings/comments)
**Description:** Skip prettification inside strings/comments by default. Can be overridden with custom predicates.

**Example:**
```
Input:  "lambda"  -- string
Output: lambda    (no prettify inside strings)
```

### Math/text context (Typst/LaTeX)
**Description:** Optional per-filetype context predicates allow symbols to render only in math or only in text.

**Example:**
```
Input (math):    x -> y
Output (math):   x → y
Input (text):    x -> y
Output (text):   x -> y   (if symbol is math-only)
```

## Editing and Motions

### Atomic motions and edits
**Description:** Prettified symbols behave as a single character for h/l, w/b/e, x/X, s/c, and related visual motions.

**Example:**
```
Input:  x -> y
Action: press l
Result: cursor jumps over the whole "->"
```

### Visual selection overlay
**Description:** Visual selection highlights prettified symbols correctly by overlaying the rendered glyph.

**Example:**
```
Action: select across a prettified symbol
Result: symbol stays visible with Visual highlight
```

## Performance

### Incremental updates
**Description:** Buffer changes re-prettify only the changed lines (no full-buffer refresh on every edit). Updates are debounced to avoid excessive work while typing.

**Example:**
```
Action: edit one line
Result: only that line is re-processed (after a short debounce)
```

## Not Yet Implemented
- Unprettify-at-point (show original text when cursor is on symbol)
- Performance profiling/benchmarks
