"""Small helpers for moving values between Tcl and Python."""

import tkinter


def to_str(value):
    """A value from tk.call as str.

    tk.call hands back str, Tcl_Obj instances, or tuples for values
    whose Tcl object happens to carry a list representation. A scalar
    (a node handle, say) can come back as a 1-tuple that way, so
    1-tuples are unwrapped; longer tuples are rendered as a Tcl list."""
    if isinstance(value, str):
        return value
    if isinstance(value, (tuple, list)):
        if len(value) == 1:
            return to_str(value[0])
        return tkinter._join(value)
    if isinstance(value, (bytes, bytearray)):
        return bytes(value).decode("utf-8", "surrogateescape")
    return str(value)


def to_list(tk, value):
    """A Tcl list as a Python list of str.

    Nested lists tkinter already split into tuples come back as nested
    lists, except 1-tuples, which are scalars as far as we can tell
    (see to_str)."""
    if not isinstance(value, (tuple, list)):
        value = tk.splitlist(value)
    return [to_list(tk, v) if isinstance(v, (tuple, list)) and len(v) != 1
            else to_str(v) for v in value]


def kv_to_dict(tk, value):
    """A flat Tcl `key value ...` list as a dict."""
    items = to_list(tk, value)
    if len(items) % 2:
        raise ValueError(f"odd-length key/value list: {items!r}")
    return dict(zip((to_str(k) for k in items[::2]), items[1::2]))


def tcl_bool(value):
    return value in ("1", "true", "yes", "on", 1, True)


class TclWidget(tkinter.Misc):
    """A tkinter view of a widget that was created on the Tcl side.

    `nametowidget()` only knows widgets created through tkinter, so the
    ttk entries etc. that minhtmltk creates for form controls need this
    thin proxy. Methods defined on `tkinter.Misc` (configure, cget,
    bind, focus_set, winfo_*...) work as usual; any other attribute is
    forwarded as a widget subcommand, with underscores turned into
    spaces: `w.insert(0, 'x')` -> `$w insert 0 x`,
    `w.selection_range(0, 'end')` -> `$w selection range 0 end`.
    """

    def __init__(self, master, path):
        self.master = master
        self.tk = master.tk
        self._w = to_str(path)
        self._name = self._w.rsplit(".", 1)[-1]
        self.children = {}

    def call(self, *args):
        """`$widget subcommand ...`"""
        return self.tk.call(self._w, *args)

    def __getattr__(self, name):
        if name.startswith("_"):
            raise AttributeError(name)
        words = name.split("_")

        def subcommand(*args):
            return self.tk.call(self._w, *words, *args)
        subcommand.__name__ = name
        return subcommand

    def __repr__(self):
        return f"<TclWidget {self._w}>"
