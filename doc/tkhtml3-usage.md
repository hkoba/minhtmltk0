# Using Tkhtml 3 (as minhtmltk0 does)

Tkhtml 3 is a Tk widget that parses HTML, applies CSS and paints the
result. It does **nothing else**: no stylesheet loading, no images, no
form controls, no link following, no hover. The host application
supplies all of that through a small set of callbacks and node
commands. minhtmltk0 is one such host; this page lists the parts of
the Tkhtml API it relies on, with the traps found along the way.

Authoritative references (in the engine's repository,
https://github.com/hkoba/tkhtml3 — CI pins a commit in
`.github/workflows/tcltk-xwindow-xvfb.yml`):

- `doc/html.man` — the widget and node command reference (`man tkhtml`
  once installed).
- `agent_docs/host-application-contract.md` — what an embedding
  application must do, with the mistakes that were made before.
- `agent_docs/architecture.md`, `modern-css-internals.md` — the
  rendering pipeline, for changes on the engine side.
- `agent_docs/testing.md` — X server / CI traps, pixel tests.
- `README.md` — which CSS the fork supports beyond CSS 2.1 (flexbox,
  grid, `var()`, `@media`, `calc()`, `:is()`, `[attr^=]`, ...).

## Loading

```tcl
package require Tkhtml 3        ;# needs a display: loads Tk
html .h                          ;# the widget command is `html`
```

The shared library must be built for the same Tcl major version as the
interpreter (`libtcl9Tkhtml3.0.so` for 9.0, `libTkhtml3.0.so` for
8.6). `package require Tkhtml` in a non-interactive `tclsh` keeps the
process alive at EOF (Tk event loop) — end scripts with `exit`.

## Widget commands used by minhtmltk0

| Command | Used for | Notes |
|---|---|---|
| `parse ?-final? HTML` | feeding the document (`$w parse`) | Appends. Handlers fire as elements close; without `-final`, elements closed by end-of-input get no handler call. |
| `reset` | start of `Reset` | Empties the tree and forgets stylesheets; **all node handles die**. |
| `handler node/script/parse TAG SCRIPT` | tag handlers (see architecture.md) | `script` handlers get `(attrs body)` and their result replaces the element; `parse` handlers see both opening and `/TAG`. |
| `configure -imagecmd SCRIPT` | images (`taghelper/imagecmd.tcl`) | Called with the raw URI for `<img>`, CSS backgrounds, `-tkhtml-replacement-image`; return a Tk photo name or `""`. |
| `style -id ID -importcmd S -urlcmd S CSS` | stylesheets (`taghelper/style.tcl`) | `-id author.NNNN` ordering drives the cascade; `-urlcmd` resolves `url()` relative to the sheet. |
| `search SELECTOR` | `$w search`, Python `search()` | Returns node handles. Selector support depends on the build (CSS3 attribute selectors need the fork). `#1` is a bad selector: use `[id="1"]`. |
| `node`, `node X Y`, `node -index X Y` | root node; hit testing in `Press/Motion/Release`; selection | `node X Y` returns a *list* (usually one node, text node included). |
| `bbox NODE` | click simulation, `See` | Document coordinates of the node's box; empty for nodes without content. |
| `text text`, `text offset`, `tag add/remove/configure/delete` | text extraction and the `selection` highlight | Indexes are byte offsets. |
| `xview`/`yview`, `yview NODE` | scrolling, `See` | Scroll requests are applied at idle time; back-to-back calls overwrite each other (see `wheel scroll`). |
| `fragment HTML` | `node set innerHtml` | Parses HTML into orphan nodes for `$node insert`. |

## Node commands used

| Command | Notes |
|---|---|
| `$node tag` | `""` for text nodes. Mouse hit-testing usually returns a text node; use `parent-of-textnode`. |
| `$node attr ?-default D? NAME`, `$node attr` | Attribute; without `-default` a missing attribute is an error. Names are lower-case. The fork adds `attr -remove NAME`. |
| `$node children`, `$node parent` | |
| `$node text ?-pre?` | Text nodes only. Plain `text` collapses/trims whitespace (`"Hello "` -> `"Hello"`); `-pre` keeps it. |
| `$node replace ?PATH -deletecmd S -configurecmd S?` | Put a Tk widget in the node's place (form controls). `-configurecmd` receives `{background-color .. font .. selected ..}`; minhtmltk uses it for baseline alignment. |
| `$node dynamic set/clear active|hover|focus|link|visited` | The host drives `:hover`/`:active`; `:link` is set once on `<a href>` at parse time. |
| `$node property ?NAME?` | Computed CSS values (`cursor`, `display`, ...). Not reliable from inside a node handler during parse (layout not done yet). |
| `$node override {-tkhtml-replacement-image url(...)}` | `<object>` fallback chain. |
| `$node insert/remove` | DOM edits (`node set innerHtml`). |
| `$node stacking` | Used to keep the selection within one stacking context. |

Node handles are Tcl commands named `::tkhtml::nodeN` with a global
counter: after `reset` old handles are simply undefined commands
(`invalid command name`), never reused for another node.

## Traps that have already cost time

- **Handler errors during parse are swallowed** by minhtmltk's `logged`
  wrapper and by Tkhtml itself; check `$w error get` / `-debug 1`.
- `<style>` needs a *two-argument* script handler; `<link rel>` is a
  word list (`"appendix stylesheet"`), alternates with a `title` are
  opt-in. Already handled in `taghelper/style.tcl` and `link.tcl`.
- `data:` URIs are percent-encoded; decode `%XX` only, never `+`.
- Ubuntu's `tk-html3` package is the 2008-era engine: no CSS3
  selectors, none of the fork's features. CI therefore builds the
  fork (`.github/scripts/build-tkhtml3.sh`). Locally the developer
  uses a Tcl 9 RPM of the same commit.
- Layout happens at idle time: call `update idletasks` (Python:
  `root.update()`) before `bbox`, `node X Y`, or the `ready` event
  when `-emit-ready-immediately` is off.
- `[$w node X Y]` needs a mapped window; unmapped widgets return `""`.
- Debug builds of the engine assert on some node queries from inside
  handlers (`property` before restyle); the `XXX` note in
  `form collect options` records one such case.
