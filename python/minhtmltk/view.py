"""HtmlView: the minhtmltk widget for tkinter."""

import re
import sys
import tkinter
import traceback

from ._loader import ensure_loaded
from ._tcl import TclWidget, kv_to_dict, tcl_bool, to_list, to_str
from .form import Form
from .node import Node

#: Event names understood by `HtmlView.on()`.
EVENTS = ("ready", "submit", "change",
          "mouseover", "mousemove", "mouseout",
          "click", "dblclick", "mousedown", "mouseup")

_TAG_KEY = re.compile(r"^[A-Za-z][\w-]*(\.[\w-]+)?$")


class Event:
    """What an `HtmlView.on()` callback receives."""

    def __init__(self, view, name, node, args):
        self.view = view
        self.name = name
        self.node = node
        #: extra arguments of the event, e.g. {'form': ..., 'name': ...}
        #: for submit, {'x': ..., 'y': ...} for mousemove (all str).
        self.args = args
        self._stopped = False

    def __repr__(self):
        return f"<Event {self.name} on {self.node!r} {self.args}>"

    @property
    def form(self):
        """The Form of a submit event (or the form of the node)."""
        if "form" in self.args:
            return Form(self.view, self.args["form"])
        try:
            return self.view.form_of(self.node)
        except tkinter.TclError:
            return None

    @property
    def button(self):
        """Name of the submit button, for submit events."""
        return self.args.get("name")

    @property
    def x(self):
        return int(self.args["x"]) if "x" in self.args else None

    @property
    def y(self):
        return int(self.args["y"]) if "y" in self.args else None

    def stop(self):
        """Skip the remaining handlers of this event, including the
        built-in ones (link navigation, label click).
        Returning True from the callback does the same."""
        self._stopped = True

    def perform_default(self):
        """Run the built-in handler for this node/event now (e.g. follow
        the link), useful from a node-level handler which otherwise
        shadows it."""
        self.view.tk.call(self.view._w, "node", "event", "tag",
                          self.node.tag, self.name, self.node.handle)


class Handler:
    """Returned by `HtmlView.on()`; pass to `HtmlView.off()`."""

    def __init__(self, event, callback, selector, key, body, cmd):
        self.event = event
        self.callback = callback
        self.selector = selector
        self.key = key          # '' / tag / tag.class, or None for selector
        self.body = body
        self.cmd = cmd
        self.nodes = []         # node handles registered for a selector

    def __repr__(self):
        where = self.selector if self.selector is not None else "global"
        return f"<Handler {self.event} on {where}>"


class HtmlView(tkinter.Widget):
    """A minhtmltk widget.

    >>> view = HtmlView(root, html='<h1>Hello</h1>')
    >>> view.on('submit', lambda ev: print(ev.form.get_all()))

    Keyword options are the widget's Tcl options with `_` for `-`
    (`allow_script`, `navigator`, `home`, `uri`, `file`, `html`,
    `scrollbar`, `debug`, `use_tk_button`, `scheme_command`, ...).
    `allow_script` defaults to False: document-supplied Tcl is not run
    unless asked for.
    """

    def __init__(self, master=None, *, allow_script=False, tcl_dir=None,
                 **options):
        if master is None:
            master = tkinter._get_default_root("create HtmlView")
        ensure_loaded(master.tk, tcl_dir, allow_script=allow_script)
        cnf = {"allow-script": "yes" if allow_script else "no"}
        for key, value in options.items():
            if isinstance(value, bool):
                value = "yes" if value else "no"
            cnf[key.replace("_", "-")] = value
        self._handlers = []
        self._selector_handlers = []
        self._scheme_handlers = {}
        self._scheme_cmd = None
        self._own_commands = []
        self.generation = 0
        tkinter.Widget.__init__(self, master, "minhtmltk", cnf)
        self._install_ready_hook()

    # -- lifecycle ----------------------------------------------------
    def _install_ready_hook(self):
        # A private bindtag right after the widget itself: it runs
        # before the class binding that triggers the `ready` handlers,
        # so selector-based handlers are in place by then. (Do not
        # touch the other tags; snit keeps its own instance tag there.)
        self._ready_tag = f"MinhtmltkPy{self._w}"
        tags = list(self.bindtags())
        tags.insert(1, self._ready_tag)
        self.bindtags(tuple(tags))
        self.tk.call("bind", self._ready_tag, "<<DocumentReady>>",
                     self._register(self._on_document_ready))

    def destroy(self):
        try:
            self.tk.call("bind", self._ready_tag, "<<DocumentReady>>", "")
        except tkinter.TclError:
            pass
        for name in self._own_commands:
            try:
                self.tk.deletecommand(name)
            except tkinter.TclError:
                pass
        self._own_commands = []
        super().destroy()

    def bind(self, sequence=None, func=None, add=True):
        """Like tkinter's bind, but `add` defaults to True: the widget's
        own mouse handling is a plain Tk binding that a replacing bind
        would remove."""
        return super().bind(sequence, func, add)

    def call(self, *args):
        """`$widget subcommand ...`"""
        return self.tk.call(self._w, *args)

    @property
    def html(self):
        """The inner Tkhtml widget."""
        return TclWidget(self, self.call("html"))

    # -- documents ----------------------------------------------------
    def load_html(self, html, uri="", **kw):
        """Render `html` as the document at `uri` (replaces the document,
        updates location and history)."""
        self.call("load", uri, html, *self._load_args(kw))

    def load_uri(self, uri, **kw):
        """Navigate to `uri` (fetch through the navigator, then load).
        Keyword `parameter=` gives values for form controls,
        `history='bypass'` keeps the history unchanged."""
        self.call("nav", "loadURI", uri, *self._load_args(kw))

    @staticmethod
    def _load_args(kw):
        args = []
        for key, value in kw.items():
            if key == "parameter" and isinstance(value, dict):
                value = tuple(x for kv in value.items() for x in kv)
            args += ["-" + key.replace("_", "-"), value]
        return args

    @property
    def location(self):
        return to_str(self.call("location", "get"))

    def history(self):
        return to_list(self.tk, self.call("nav", "history", "list"))

    def back(self):
        self.call("nav", "history", "go-offset", -1)

    def forward(self):
        self.call("nav", "history", "go-offset", 1)

    @property
    def ready(self):
        return tcl_bool(to_str(self.call("state", "is", "DocumentReady")))

    def source(self):
        """The HTML source of the current document."""
        return to_str(self.call("state", "source"))

    def text(self):
        """The visible text of the document."""
        return to_str(self.html.call("text", "text")).strip()

    def parameter(self, name, default=""):
        """Query parameter of the current URI (or `-parameter` value)."""
        return to_str(self.call("state", "parameter", "default", name,
                                default))

    def see(self, target):
        """Scroll a Node or CSS selector into view."""
        self.call("See", target.handle if isinstance(target, Node)
                  else target)

    def errors(self):
        """Parse/handler errors logged for the current document."""
        return [to_list(self.tk, e) for e in
                to_list(self.tk, self.call("error", "get"))]

    def log(self):
        return [to_list(self.tk, e) for e in
                to_list(self.tk, self.call("logger", "get"))]

    # -- nodes and forms ------------------------------------------------
    def search(self, selector, root=None):
        """Nodes matching a CSS selector."""
        args = ["search", selector]
        if root is not None:
            args += ["-root", root.handle]
        return [Node(self, h) for h in to_list(self.tk, self.call(*args))]

    def find(self, selector, root=None):
        """The first node matching `selector`, or None."""
        nodes = self.search(selector, root)
        return nodes[0] if nodes else None

    def root_node(self):
        return Node(self, self.html.call("node"))

    def forms(self):
        return [Form(self, f) for f in to_list(self.tk,
                                               self.call("form", "list"))]

    def form(self, which=0):
        """A Form by index (0 also stands for the implicit outer form
        of documents without <form>) or by '@name'."""
        return Form(self, self.call("form", "get", which))

    def form_of(self, node):
        return Form(self, self.call("form", "of-node", node.handle))

    def form_dump(self):
        return [kv_to_dict(self.tk, d) for d in
                to_list(self.tk, self.call("form", "dump"))]

    def form_restore(self, dump):
        flat = tuple(tuple(x for kv in d.items() for x in kv)
                     if isinstance(d, dict) else d for d in dump)
        self.call("form", "restore", flat)

    # -- events -------------------------------------------------------
    def on(self, event, callback, selector=None):
        """Call `callback(Event)` for `event`.

        selector=None      the event anywhere in the document (once per
                           event, with the innermost node);
        'tag' / 'tag.cls'  every element of that tag/class (bubbling);
        other CSS selector the matching elements, looked up whenever a
                           document is loaded. Such node-level handlers
                           replace the built-in behaviour for those
                           nodes (use Event.perform_default()).

        Handlers stay registered across documents. The callback may
        return True (or call Event.stop()) to skip the remaining
        handlers of that event. Returns a Handler for `off()`."""
        if event not in EVENTS:
            raise ValueError(f"unknown event {event!r}; one of {EVENTS}")
        cmd = self._register(self._make_dispatcher(callback))
        body = f"if {{[{cmd} $event $node {{*}}$args]}} {{return -code break}}"
        if selector is None:
            key = ""
        elif _TAG_KEY.match(selector):
            key = selector
        else:
            key = None
        handler = Handler(event, callback, selector, key, body, cmd)
        if key is not None:
            self.call("node", "event", "on", "-persistent", key, event, body)
        else:
            self._selector_handlers.append(handler)
            if self.ready:
                self._apply_selector_handler(handler)
        self._handlers.append(handler)
        return handler

    def off(self, handler):
        """Remove a handler returned by `on()`."""
        if handler.key is not None:
            self.call("node", "event", "remove", "-persistent",
                      handler.key, handler.event, handler.body)
        else:
            self._selector_handlers.remove(handler)
            for node in handler.nodes:
                try:
                    self.call("node", "event", "remove", node,
                              handler.event, handler.body)
                except tkinter.TclError:
                    pass
            handler.nodes = []
        self._handlers.remove(handler)
        self.deletecommand(handler.cmd)

    def _make_dispatcher(self, callback):
        def dispatch(event, node, *kv):
            ev = Event(self, to_str(event), Node(self, node),
                       kv_to_dict(self.tk, kv))
            try:
                result = callback(ev)
            except Exception:
                self.report_callback_exception(*sys.exc_info())
                return 0
            return 1 if (result is True or ev._stopped) else 0
        dispatch.__name__ = getattr(callback, "__name__", "handler")
        return dispatch

    def report_callback_exception(self, exc, val, tb):
        """Called for exceptions in event/scheme callbacks; prints the
        traceback. Override or reassign to change that."""
        sys.stderr.write("Exception in minhtmltk callback\n")
        traceback.print_exception(exc, val, tb)

    def _on_document_ready(self):
        self.generation += 1
        for handler in self._selector_handlers:
            self._apply_selector_handler(handler)

    def _apply_selector_handler(self, handler):
        handler.nodes = []
        for node in self.search(handler.selector):
            self.call("node", "event", "on", node.handle, handler.event,
                      handler.body)
            handler.nodes.append(node.handle)

    def trigger(self, event, node=None, **args):
        """Fire `event` programmatically (on `node`, or globally)."""
        flat = tuple(x for kv in args.items() for x in kv)
        self.call("node", "event", "trigger",
                  node.handle if node is not None else "", event, *flat)

    # -- URI schemes ----------------------------------------------------
    def register_scheme(self, scheme, handler):
        """Serve `scheme:` URIs from Python.

        `handler(uri, mode)` returns `(content_type, body)`; `body` is a
        str, or bytes when mode is 'binary' (images). `uri` is the full
        URI as str. Links, images and stylesheets of such pages, and
        `load_uri()`, all go through the handler. Raise to fail the
        fetch.
        """
        self._scheme_handlers[scheme] = handler
        if self._scheme_cmd is None:
            name = f"minhtmltk_py_scheme_{id(self)}"
            self.tk.createcommand(name, self._scheme_read)
            self._own_commands.append(name)
            self._scheme_cmd = name
            # A Python exception escaping a Tcl command would be raised
            # later, from mainloop(); so the Python side returns
            # {error MESSAGE} instead and this small Tcl wrapper turns
            # it into a Tcl error (the fetch fails as it should).
            wrapper = self.tk.call(
                "list", "apply",
                "{pycmd scheme uriObj args} {\n"
                "    set res [$pycmd $scheme $uriObj {*}$args]\n"
                "    if {[lindex $res 0] eq \"error\"} {\n"
                "        error [lindex $res 1]\n"
                "    }\n"
                "    return $res\n"
                "}", name)
            self.configure({"scheme-command": wrapper})

    def unregister_scheme(self, scheme):
        del self._scheme_handlers[scheme]

    def _scheme_read(self, scheme, uriobj, *args):
        scheme = to_str(scheme)
        uri = to_str(self.tk.call(uriobj, "get"))
        try:
            handler = self._scheme_handlers.get(scheme)
            if handler is None:
                raise LookupError(f"Unsupported URI scheme {scheme}: {uri}")
            opts = to_list(self.tk, args)
            mode = "text"
            if "-mode" in opts:
                mode = opts[opts.index("-mode") + 1]
            content_type, body = handler(uri, mode)
        except Exception as exc:
            return ("error", f"{uri}: {type(exc).__name__}: {exc}")
        if mode != "binary" and isinstance(body, (bytes, bytearray)):
            body = bytes(body).decode("utf-8")
        return ("uri", uri, "content-type", content_type or "", "body", body)

    # -- testing aids -----------------------------------------------------
    def click(self, node):
        """Simulate a mouse click on `node` (press + release at its
        centre), as a user would do it."""
        self.update_idletasks()
        x1, y1, x2, y2 = node.bbox()
        x, y = (x1 + x2) // 2, (y1 + y2) // 2
        html = self.html._w
        self.call("Press", html, x, y)
        self.call("Release", html, x, y)
