# minhtmltk for Python (tkinter)

A tkinter binding for [minhtmltk](../README.md), the minimal HTML widget
built on Tkhtml 3. Form controls, buttons and links of an HTML page can
be handled by Python functions; pages can be served from Python through
a custom URI scheme.

## Requirements

- Python 3.9+ with tkinter
- Tkhtml 3 built for **the same Tcl major version as Python's
  `_tkinter`** (`python3 -c "import tkinter; print(tkinter.TclVersion)"`)
- tcllib (`snit`, `dicttool`) and tklib (`widget::scrolledwindow`,
  `tooltip`) visible to that Tcl
- the Tcl sources of minhtmltk (this repository). They are found
  relative to this package; set `MINHTMLTK_TCL_DIR` or pass
  `tcl_dir=` to `HtmlView` if you installed the package elsewhere.

No Tcl binaries are bundled.

## Quick start

```python
import tkinter
from minhtmltk import HtmlView

root = tkinter.Tk()
view = HtmlView(root, html="""
    <form name="f">
      Name: <input type="text" name="name">
      <input type="submit" name="ok" value="OK">
    </form>""")
view.pack(fill="both", expand=True)

def on_submit(ev):
    print("submitted", ev.button, ev.form.get_all())   # {'name': ..., 'ok': 'OK'}

view.on("submit", on_submit)
root.mainloop()
```

Run the examples (from this directory, no installation needed):

```sh
python3 examples/form_demo.py     # form + buttons handled in Python
python3 examples/app_scheme.py    # pages served from Python via app: URIs
```

## API

### `HtmlView(master, *, allow_script=False, tcl_dir=None, **options)`

A `tkinter.Widget`; options are the widget's Tcl options with `_` for
`-` (`html=`, `uri=`, `file=`, `home=`, `navigator=`, `scrollbar=`,
`debug=`, `use_tk_button=`, ...). Document-supplied Tcl (`<script
type="tcl">`, `onclick="..."`) is only run with `allow_script=True`.

Documents:

| | |
|---|---|
| `load_html(html, uri='')` | render literal HTML |
| `load_uri(uri, parameter={...})` | navigate (file, http with `navigator='webnav'`, or a registered scheme) |
| `location`, `history()`, `back()`, `forward()` | |
| `text()`, `source()`, `parameter(name)` | visible text, HTML source, query parameter |
| `search(selector)`, `find(selector)` | CSS selector -> `Node` list / first `Node` |
| `see(node_or_selector)` | scroll into view |
| `errors()`, `log()` | logged parse/handler errors |

### Events: `view.on(event, callback, selector=None) -> Handler`

`event` is one of `ready`, `click`, `dblclick`, `mousedown`, `mouseup`,
`mouseover`, `mouseout`, `mousemove`, `change`, `submit`.

- `selector=None`: fires once per event anywhere in the document; the
  callback's `ev.node` is the innermost target (like a listener on
  `document`).
- `'h2'` / `'input.big'`: a tag or `tag.class`; bubbles, so every
  matching ancestor of the target is called once.
- any other CSS selector (`'#save'`, `'a[href^="app:"]'`): the matching
  nodes of each document. Such node-level handlers replace the built-in
  behaviour for those nodes (link navigation, label click); call
  `ev.perform_default()` to run it.

Handlers stay registered when another document is loaded. Return
`True` (or call `ev.stop()`) to skip the remaining handlers of that
event, including the built-in ones. `view.off(handler)` removes one.

`Event` has `name`, `node`, `args` (dict of str), `form` (the `Form`,
for submit/change), `button` (submit button name), `x`, `y`
(mousemove). Exceptions in callbacks are printed via
`view.report_callback_exception` and otherwise ignored.

### Forms: `view.form(index_or_'@name')`, `view.forms()`, `view.form_of(node)`

`Form.get_all()` returns a dict; checkbox groups and multiple selects
map to lists. `Form.get(name)`, `Form.set(name, value, notify=False)`,
`Form.update({...})`, `names()`, `choices(name)`, `nodes_of(name)`,
`action`, `name`, `node`. `set()` does not fire `change` unless
`notify=True`.

`Node`: `tag`, `text()`, `attr(name, default)`, `attrs()`,
`children()`, `parent()`, `style(name)` (computed CSS), `bbox()`, `widget` (the Tk
control rendering an input, as a `TclWidget` proxy: `.get()`,
`.insert()`, `.configure()` ...). A `Node` raises `StaleNodeError`
once its document has been replaced.

### Custom URI schemes: `view.register_scheme('app', handler)`

`handler(uri, mode)` returns `(content_type, body)`; `body` is `str`,
or `bytes` when `mode == 'binary'` (images). Links, `<img>`, `<link
rel=stylesheet>` and `load_uri()` for that scheme all go through it.
A form is submitted to Python by combining `on('submit', ...)` with
`load_uri(f"{ev.form.action}?{urlencode(ev.form.get_all(), doseq=True)}")`
(see `examples/app_scheme.py`). Use hierarchical URIs (`app:/path`) so
relative links resolve.

## Notes

- Everything must run on the thread that runs Tk (`mainloop`); hand
  work from other threads back with `root.after()`.
- `<button>` is not supported by minhtmltk; use `<input type=button>`.
- `HtmlView.bind()` defaults to `add=True`, because the widget's own
  mouse handling is a plain Tk binding.

## Tests

```sh
cd python/tests && xvfb-run -a python3 -m unittest -v
```
