# minhtmltk — a minimal HTML viewer widget for Tcl/Tk

minhtmltk is a minimal webview library built on [Tkhtml 3](http://tkhtml.tcl.tk/),
written as sample code that shows how to drive Tkhtml3 from modern Tcl
(snit megawidget). It renders static HTML/CSS, handles links, forms,
images and text selection, and provides simple location/history
management. Navigation supports local files out of the box, and
http/https as an opt-in.

It is intentionally small: no JavaScript, no incremental loading, no
caching. If you need a real browser, see [hv3](http://tkhtml.tcl.tk/hv3.html);
if you want readable example code for embedding Tkhtml3, this project
is for you.

## Requirements

- Tcl/Tk 8.6 or later (developed with 9.0)
- Tkhtml 3
- tcllib (`snit`)
- tklib (`widget::scrolledwindow`)
- tcltls — optional, only needed for `https:`

## Running from the command line

`minhtmltk0.tcl` is a *modulino*: you can `source` it as a library, or
run it directly with `wish`.

```sh
# view a local file
wish minhtmltk0.tcl --file=tests/html/001.html

# render literal HTML
wish minhtmltk0.tcl --html='<h1>Hello, world!</h1>'

# browse the web (http/https needs --navigator=webnav)
wish minhtmltk0.tcl --navigator=webnav --uri=https://example.com/
```

Command-line options use POSIX long option style: `--name=value`, or a
bare `--name` for flags (meaning `--name=1`). Each `--name` maps to
the widget option `-name`.

Any remaining arguments are invoked as a widget method call and the
result is printed. The `Open` convenience method (command-line mode
only) navigates to a URI:

```sh
wish minhtmltk0.tcl --navigator=webnav Open http://localhost:8000/index.html
```

### Key bindings

| Key | Action |
|---|---|
| Up / Down / Left / Right | scroll by unit |
| space / Next (PageDown) | scroll down one page |
| Prior (PageUp) | scroll up one page |
| Alt-Left / Alt-Right | history back / forward |
| `<<Copy>>` (usually Ctrl-C) | copy the selected text |

Text can be selected with the mouse (except on clickable elements).

## Using from a Tcl/Tk script

Source `minhtmltk0.tcl` and create the widget. There is no package
index; use whatever path you installed the sources under.

```tcl
package require Tk
source /path/to/minhtmltk/minhtmltk0.tcl

pack [minhtmltk .browser -file index.html] -fill both -expand yes
```

Relative `-file`/`-uri` values are resolved against `[pwd]`.

### Loading content

```tcl
.browser configure -html {<h1>Hello, world!</h1>}  ;# literal HTML
.browser nav loadURI other.html                    ;# navigate (fetch + replace + history)
.browser load $uri $html                           ;# low-level: replace content only
```

### Browsing http/https

The default navigator (`localnav`) handles local files only. Pass
`-navigator webnav` to enable http/https; stylesheets and images
referenced by the page are then fetched over http too.

```tcl
pack [minhtmltk .browser -navigator webnav \
          -uri https://example.com/] -fill both -expand yes
```

`-navigator` accepts a navigator type name (`localnav`, `webnav`) or a
navigator object you constructed yourself (e.g.
`[::minhtmltk::navigator::webnav %AUTO%]`). `https:` requires the
tcltls package, which is loaded on first use.

### Main options

| Option | Meaning |
|---|---|
| `-file`, `-uri` | URI to load (both are aliases of the navigator's `-uri`) |
| `-home` | URI to load when nothing else is loaded |
| `-html` | literal HTML to render |
| `-navigator` | navigator type name or object (creation-time only) |
| `-scrollbar` | passed to `widget::scrolledwindow` (`both`, `vertical`, ...; creation-time only) |
| `-script-type` | which `<script type=...>` values are executed as Tcl (see below) |
| `-allow-script` | whether documents may run Tcl; default depends on `-navigator` (see below) |
| `-debug` | when true, echo logged errors/messages to stderr (`-debug-fh`) |

### Reading the document

`search` returns Tkhtml node handles for a CSS selector; the usual
Tkhtml node API applies. Unknown widget subcommands are forwarded to
the underlying Tkhtml widget.

```tcl
set node [.browser search h2]           ;# CSS selector -> node
[$node children] text                   ;# text content
$node property background-color         ;# computed style
.browser location get                   ;# current URI
.browser nav history list               ;# visited URIs
.browser nav history go-offset -1       ;# back
.browser state parameter get q          ;# query parameter of current URI
```

### Events

Handlers can be attached globally or per node. The handler body is run
via `apply` with `self`, `win`, `node` (alias `this`) and `args`
available.

```tcl
.browser on ready  { puts "document ready" }
.browser on click  { puts "clicked $node" }
.browser node event on $node click { puts "clicked exactly $node" }
```

Supported event names include `ready`, `click`, `mousedown`,
`mouseup`, `mouseover`, `mouseout`, `mousemove`, `change` and
`submit`.

### Document scripts and `-allow-script`

A document can carry Tcl code: `<script type="tcl">...</script>` is
executed with `$self`/`$win` bound to the widget, and `on<event>`
attributes (`onclick`, `onchange`, ...) become event handlers. Since
such code runs with full interpreter access, it is gated by the
`-allow-script` option:

- If not given, it defaults to `yes` when the widget uses the default
  navigator (local files only, as before), and to `no` when
  `-navigator` is passed explicitly — a remote document fetched via
  `webnav` is not to be trusted.
- An explicit `-allow-script yes`/`no` always wins. For example, to
  browse a trusted scripted app over http:

```sh
wish minhtmltk0.tcl --navigator=webnav --allow-script \
    --uri=http://localhost:8000/trusted-app.html
```

Ignored scripts are recorded in the logger (visible on stderr with
`--debug=1`).

The `<script type="tcl">` handler itself lives in
`include/script-tag.tcl`. When run from the command line it is loaded
automatically; in library mode, source the include files yourself if
you want it:

```tcl
foreach inc [glob /path/to/minhtmltk/include/*.tcl] { source $inc }
```

`-script-type` selects which `type=` values count as Tcl, and
`-script-self` substitutes the object exposed to scripts.

## Navigator API — the read / load convention

The scheme machinery separates *fetching* from *replacing*:

- **`read`** = fetch only, no browser side effects. Each scheme
  handler implements `scheme <name> read $uriObj ?args?` and returns a
  response dict with keys `uri` (effective URI after redirects),
  `content-type` (`""` if unknown) and `body` (http adds `status`).
- **`load`** = content replacement on the widget
  (`.browser load $uri $html`), which also updates location/history.
- **`nav loadURI`** = the navigation entrance composing the two.

`read` is also available directly, e.g. to fetch bytes through
whatever schemes the navigator supports:

```tcl
set res [.browser nav read logo.png -mode binary]
dict get $res content-type   ;# => image/png
```

To support a new scheme, write a `snit::macro` defining
`scheme <name> read` (see `navigator/scheme/http.tcl`) and compose it
into a navigator type (see `navigator/webnav.tcl`).
`navigator/samplenav.tcl` is an annotated copy of `localnav`.

## Running the tests

```sh
cd tests
tclsh all.tcl                 # needs an X display
# or, headless:
xvfb-run -a tclsh all.tcl
```

## License

BSD-style; see [LICENSE](LICENSE).
