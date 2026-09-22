# minhtmltk0 architecture

How the pieces fit, and where to change what. For the Tkhtml side of
the contract see [tkhtml3-usage.md](tkhtml3-usage.md).

## The widget

`minhtmltk0.tcl` defines `snit::widget minhtmltk`. The hull is a frame
(class `Minhtmltk`) containing a `widget::scrolledwindow` and the
Tkhtml widget (`$win.sw.html`, reachable as `[$w html]`; unknown
subcommands are delegated to it via `component myHtml -inherit yes`).

The widget body is assembled from **snit::macros** in `taghelper/`:
each `::minhtmltk::taghelper NAME` line in the widget body expands
`taghelper/NAME.tcl` into methods and variables of the widget. This is
only a way to split one big class into files; the macros are not
independently testable and share the widget's instance variables.

Instance variables named `state*` are **wiped by `Reset`** (called by
`load`, i.e. by every navigation, and by the constructor). Anything
that must survive a document change goes in a `my*` variable
(`myPersistentTriggerDict`, `myLogHistory`, ...).

## Document lifecycle

```
nav loadURI URI            navigator: resolve URI, [scheme X read] -> {uri content-type body}
  -> $w load $uri $html    Reset; location/query params; parse -final; history push
       -> Reset            $myHtml reset, destroy form objects, unset state*, [interactive]
       -> interactive      re-install Tkhtml handlers, persistent event handlers,
                           built-in tag handlers, key/mouse/wheel bindings
       -> parse -final     Tkhtml parses; handlers fire per element (below);
                           then <<DocumentReady>> (after idle) -> `ready` event
```

`-html HTML` and `parse -final HTML` are shortcuts: the first goes
through `load ""`, the second only parses (no Reset, handlers kept).

## Tag handlers (parse time)

`taghelper.tcl` keeps a registry filled by
`::minhtmltk::taghelper::add KIND TAG ?METHOD?` at source time:

| kind | Tkhtml callback | method invoked | used for |
|---|---|---|---|
| `node` | `handler node TAG` (after the subtree is parsed) | `add node TAG $node` | input (via `by-input-type`), textarea, select, a, link, object |
| `script` | `handler script TAG` (element is *replaced* by the result) | `add script TAG $atts $body` | style, and script (include/script-tag.tcl) |
| `parse` | `handler parse TAG` (opening *and* closing tag) | `add parse TAG $node` | form (tracks "inside a form") |

`install-html-handlers` registers every entry on the Tkhtml widget,
wrapped in `logged` so exceptions go to the logger (`$w error get`,
`$w logger get`, `-debug 1` echoes to stderr) instead of aborting the
parse. **A tag handler error is therefore silent unless you look.**

To add a tag: create `taghelper/foo.tcl` with
`::minhtmltk::taghelper::add node foo` and a
`snit::macro ::minhtmltk::taghelper::foo {} { method {add node foo} node {...} }`,
then add `::minhtmltk::taghelper foo` to the widget body. Node
handlers may `$node replace` a Tk widget (form controls),
`$node override` CSS, or `$node dynamic set` flags.

## Forms

`formstate1.tcl` (`::minhtmltk::formstate`) is a value model per
`<form>` (plus an implicit "outer" form for controls outside any
form). Each control registers with `$form node add KIND $node ATTRS`:

- `text` — one Tcl variable per control (`-textvariable` of the entry;
  textarea/select use getter/setter traces instead).
- `single` — radio / single select: one variable per *name*, holding
  the chosen value.
- `multi` — checkbox / multiple select: one array per name, indexed by
  value, holding booleans.

`$form get_all` returns a flat `name value ...` list (multi values as
lists; unchecked groups omitted; named submit buttons included);
`$form set name value`; `$w form get 0|@name`, `$w form dump/restore`.
Variable **write traces** fire the `change` event
(`do-trace ... write`), guarded by the widget's
`node event change is-handling/allow/suppressing` state: after a change
handler ran, further writes are treated as programmatic (no event)
until the next user input (Press/KeyPress/checkbutton `-command` call
`change allow`). Wrap programmatic sets in
`$w node event change suppressing {...}` to be sure.

The Tk widgets for controls live at `$myHtml._<id>` and are attached
with `$node replace PATH -deletecmd ... -configurecmd ...`
(`with path-of`). `<input type=button>` gets **no** Tk widget by
default (`-use-tk-button no`): Tkhtml draws it from CSS and the click
comes through the widget's own mouse handling; `<button>` is not
supported. `submit` inputs get a node-level `click` handler that
triggers `submit` with `form $form name $name`. Nothing navigates to
the form's `action`; that is left to the application.

## Events (`taghelper/mouseevent0.tcl`)

Registry: `stateTriggerDict` = `key -> event -> list of handler bodies`
where key is a node handle, a tag, `tag.class`, or `""` (global).
`myPersistentTriggerDict` holds `-persistent` registrations and is
copied into `stateTriggerDict` by `install-mouse-handlers` on every
Reset, **before** the built-in `node event tag * *` methods (`a click`
navigation, `label click`), so persistent handlers precede built-ins.

Dispatch (`list-handlers`, `generatelist`, `handlelist`, `apply`):

1. `Press`/`Release`/`Motion` on the hull map `%x %y` to the Tkhtml
   widget, get the nodes under the pointer (`$myHtml node x y`), and
   build an `event node` list from the innermost node up through its
   ancestors (`mousedown`/`mouseup`/`click`; `mouseover`/`mouseout`
   from hover-set differences; `mousemove` on the innermost).
2. For each (event, node): node-level handlers if the node has any,
   **else** `tag.class` then `tag` handlers (so node-level shadows
   tag-level); global handlers are added only for the innermost node
   of each event (browser model: once per event, `$node` = target).
   `node event trigger $node event ?k v ...?` is the programmatic
   entry (used for `submit`, `change`).
3. Each handler body runs via
   `apply {self win selfns node this event args} $body`.
   `return -code break` (re-raised at the method boundary in
   `node event apply`) stops the remaining handlers of that event;
   `handlelist` then returns 0, which `Press` uses to decide whether to
   start text selection.
4. Text selection (`selection *` methods, Tkhtml `tag add selection`)
   only starts when the innermost node has no click handler.

`on<event>` HTML attributes and `<script type=tcl>` are compiled into
handlers only when `-allow-script` is on (default: on with the default
navigator, off when `-navigator` is given explicitly).

## Navigation (`navigator/`)

A navigator is a `snit::type` composed from `common_macro.tcl` plus
scheme macros. Conventions:

- `read URI ?-mode binary?` = fetch only, returns a dict
  `{uri content-type body}`; dispatches on scheme to
  `scheme NAME read $uriObj`, then to the `-scheme-command` option
  (application-defined schemes), else errors.
- `loadURI` = `read` + `$browser load`. `history push|bypass`,
  `history go-offset ±1` (back/forward re-fetch the URI).
- URIs resolve against the current location (`tkhtml::uri`), so a bare
  path inside an `app:/x` document becomes `app:/...`; use `file://`
  when you mean a file.

Images (`taghelper/imagecmd.tcl`) and stylesheets
(`taghelper/style.tcl`, including `@import` and `url()` resolution
relative to the sheet) fetch through the same `nav read`, so any scheme
serves all three. `data:` image URIs are decoded inline.

## Python binding (`python/minhtmltk/`)

A thin layer over the Tcl API through `tkinter`: `HtmlView` is a
`tkinter.Widget` created with the `minhtmltk` command; Python callbacks
become Tcl commands (`_register`) embedded in handler bodies
(`if {[pycmd $event $node {*}$args]} {return -code break}`); selector
based handlers are re-applied from a `<<DocumentReady>>` binding on a
private bindtag; `register_scheme` uses `-scheme-command`. Design
decisions and the traps that shaped them (tkinter's `nametowidget`,
`None` becoming `"None"`, exceptions escaping `createcommand`, Tcl list
shimmering into tuples) are recorded in
[python-integration.ja.md](python-integration.ja.md).

## Tests

`tests/all.tcl` runs every `*.test` in one interpreter (`-singleproc 1`);
files reuse `.ht` and rely on `.ht Reset` clearing handlers. Simulated
clicks: `invokeClick $node` in `tests/mouse-test-util.tcl` (bbox centre
-> `Press`/`Release`). `-emit-ready-immediately yes` makes `ready`
synchronous. The Python suite (`python/tests`, unittest) mirrors this
with `HtmlView.click()`. CI builds Tkhtml from the pinned commit of
hkoba/tkhtml3 on Ubuntu (Tcl 8.6) and runs both suites under Xvfb.
