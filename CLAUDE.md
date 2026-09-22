# minhtmltk0 — guide for coding agents

minhtmltk is a minimal HTML viewer widget for Tcl/Tk built on the
[Tkhtml 3](https://github.com/hkoba/tkhtml3) rendering engine, plus a
Python (tkinter) binding. Tkhtml only renders; everything a browser
does on top (forms, links, stylesheets, images, events) is done here,
in Tcl. This file is the entry point; the details live in `doc/`.

## Read first

| Need | Document |
|---|---|
| How this codebase is put together, how to add a tag handler / event / URI scheme | [doc/architecture.md](doc/architecture.md) |
| What Tkhtml 3 gives us and how it is used here (widget/node commands, traps) | [doc/tkhtml3-usage.md](doc/tkhtml3-usage.md) |
| Tkhtml's own agent docs (rendering internals, host contract, testing traps) | `agent_docs/` in [hkoba/tkhtml3](https://github.com/hkoba/tkhtml3/tree/master/agent_docs); pin: the commit in `.github/workflows/tcltk-xwindow-xvfb.yml` |
| User-facing API (Tcl) | [README.md](README.md) / [README.ja.md](README.ja.md) (keep both in sync) |
| Python binding API | [python/README.md](python/README.md) |
| Why the Python binding is shaped the way it is (design notes, ja) | [doc/python-integration.ja.md](doc/python-integration.ja.md) |

## Layout

```
minhtmltk0.tcl        the snit::widget `minhtmltk` (modulino: source it, or run with wish)
taghelper.tcl         registry of tag handlers + the macro loader (sources taghelper/*.tcl)
taghelper/*.tcl       snit::macros mixed into the widget: form, style, anchor, link,
                      imagecmd, object, mouseevent0 (event dispatch), errorlogger, nodeutil
formstate1.tcl        ::minhtmltk::formstate — per-<form> value model (Tcl variables + traces)
navigator/            localnav / webnav (snit::types), common_macro.tcl (read/loadURI/history),
                      scheme/{file,http}.tcl
include/*.tcl         optional extras, not sourced in library mode: script-tag.tcl
                      (<script type=tcl>), window.tcl, scrollbar.tcl
utils.tcl, query-string.tcl   helpers
tests/*.test          tcltest suites; tests/html/ fixtures
python/minhtmltk/     tkinter binding; python/tests (unittest); python/examples
doc/                  the documents listed above
.github/              CI: builds Tkhtml from hkoba/tkhtml3 (scripts/build-tkhtml3.sh), runs both suites
```

## Running things

```sh
wish minhtmltk0.tcl --file=tests/html/001.html          # try it
cd tests && xvfb-run -a tclsh all.tcl                    # Tcl suite (or DISPLAY=:0 tclsh all.tcl)
cd tests && tclsh all.tcl -file mouseevent0.test -verbose p
cd python/tests && xvfb-run -a python3 -m unittest -v    # Python suite (no pytest needed)
```

Requirements: Tcl/Tk 8.6 or 9.0, Tkhtml 3 **built for the same Tcl
major version** (this is the usual failure), tcllib (`snit`,
`dicttool`), tklib (`widget::scrolledwindow`, `tooltip`). Python's
`_tkinter` must match too: `python3 -c 'import tkinter; print(tkinter.TclVersion)'`.

Trap: a non-interactive `tclsh` that does `package require Tkhtml` never
exits at EOF (Tk enters its event loop); end probe scripts with `exit`.

## Conventions

- Commit messages: `GH-<issue> - Summary` (see `git log`). Work on a
  branch; issue #10 tracks the Python binding.
- Tcl code must stay Tcl 8.6-compatible (CI runs 8.6; developer uses 9.0).
  No Python-specific code in the Tcl side: extensions there must make
  sense for Tcl users on their own.
- README.md and README.ja.md are kept in sync; commit messages, issue
  text and code comments are English.
- Every behaviour change gets a tcltest case (Tcl) or a unittest case
  (Python). Tests that simulate clicks use `Press`/`Release` with
  coordinates from `bbox` (see `tests/mouse-test-util.tcl`,
  `HtmlView.click()`), not `event generate`.
- Event dispatch semantics are documented in README "Events" and
  doc/architecture.md; keep them browser-like (global handler once per
  event with the innermost node, tag handlers bubble, node-level
  handlers shadow tag-level, `return -code break` stops the rest).
