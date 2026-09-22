"""Form state (::minhtmltk::formstate) as a Python object."""

from ._tcl import kv_to_dict, tcl_bool, to_list, to_str


class Form:
    """One <form> of the current document (or the implicit outer form).

    Values are read from and written to the live form controls."""

    __slots__ = ("view", "obj", "_generation")

    def __init__(self, view, obj):
        self.view = view
        self.obj = to_str(obj)
        self._generation = view.generation

    def call(self, *args):
        if self._generation != self.view.generation:
            from .node import StaleNodeError
            raise StaleNodeError(
                f"{self.obj} belongs to a previous document")
        return self.view.tk.call(self.obj, *args)

    def __repr__(self):
        return f"<Form {self.name!r} action={self.action!r}>"

    # -- identity -----------------------------------------------------
    @property
    def name(self):
        return to_str(self.call("cget", "-name"))

    @property
    def action(self):
        return to_str(self.call("cget", "-action"))

    @property
    def node(self):
        from .node import Node
        handle = to_str(self.call("cget", "-node"))
        return Node(self.view, handle, self._generation) if handle else None

    # -- values -------------------------------------------------------
    def names(self):
        return to_list(self.view.tk, self.call("names"))

    def is_multi(self, name):
        """True for names whose value is a list (checkbox, select multiple)."""
        return tcl_bool(to_str(self.call("name", "dict", "get", name,
                                         "is_array")))

    def get(self, name):
        """Value of one control; a list of str for multi-valued names."""
        value = self.call("get", name)
        if self.is_multi(name) or isinstance(value, (tuple, list)):
            return to_list(self.view.tk, value)
        return to_str(value)

    def get_all(self):
        """All values as a dict; multi-valued names map to lists."""
        flat = to_list(self.view.tk, self.call("get_all"))
        result = {}
        for name, value in zip(flat[::2], flat[1::2]):
            if isinstance(value, list):
                result[name] = value
            elif self.is_multi(name):
                result[name] = to_list(self.view.tk, value)
            else:
                result[name] = value
        return result

    def set(self, name, value, notify=False):
        """Set one control.

        Multi-valued names take a list of the values to check.
        By default the `change` event is suppressed, as for any other
        programmatic change; pass notify=True to fire it."""
        if isinstance(value, (list, tuple, set)):
            value = tuple(str(v) for v in value)
        script = self.view.tk.call("list", self.obj, "set", name, value)
        if notify:
            self.view.tk.call(self.view._w, "node", "event", "change",
                              "allow")
            self.view.tk.call(self.obj, "set", name, value)
        else:
            self.view.tk.call(self.view._w, "node", "event", "change",
                              "suppressing", script)

    def update(self, values, notify=False):
        for name, value in dict(values).items():
            self.set(name, value, notify=notify)

    def nodes_of(self, name):
        """The control node(s) registered under `name`."""
        from .node import Node
        return [Node(self.view, h, self._generation)
                for h in to_list(self.view.tk,
                                 self.call("node", "of-name", name))]

    def choices(self, name):
        """Possible values of a radio/checkbox/select group."""
        return to_list(self.view.tk, self.call("choicelist", name))
