"""Tkhtml node handles as Python objects."""

import re

from ._tcl import TclWidget, kv_to_dict, to_list, to_str


class StaleNodeError(RuntimeError):
    """The node belongs to a document that has since been replaced."""


class Node:
    """A Tkhtml node (`::tkhtml::nodeN`) of an HtmlView document.

    Node handles are only valid for the document they were found in;
    after the view loads another document, using the node raises
    StaleNodeError.
    """

    __slots__ = ("view", "handle", "_generation")

    def __init__(self, view, handle, generation=None):
        self.view = view
        self.handle = to_str(handle)
        self._generation = (view.generation if generation is None
                            else generation)

    # -- plumbing ---------------------------------------------------
    def _check(self):
        if self._generation != self.view.generation:
            raise StaleNodeError(
                f"{self.handle} belongs to a previous document")

    def call(self, *args):
        """`$node subcommand ...`"""
        self._check()
        return self.view.tk.call(self.handle, *args)

    def _wrap(self, handle):
        handle = to_str(handle)
        return Node(self.view, handle, self._generation) if handle else None

    def __eq__(self, other):
        return isinstance(other, Node) and other.handle == self.handle \
            and other.view is self.view

    def __hash__(self):
        return hash((id(self.view), self.handle))

    def __repr__(self):
        try:
            tag = self.tag
        except StaleNodeError:
            tag = "stale"
        return f"<Node {self.handle} {tag or 'text'}>"

    # -- structure --------------------------------------------------
    @property
    def tag(self):
        """Tag name, or '' for a text node."""
        return to_str(self.call("tag"))

    @property
    def is_text(self):
        return self.tag == ""

    def parent(self):
        return self._wrap(self.call("parent"))

    def children(self):
        return [self._wrap(h) for h in to_list(self.view.tk,
                                               self.call("children"))]

    def text(self):
        """Text of this node and its descendants, with whitespace runs
        collapsed to single spaces and the ends stripped."""
        return re.sub(r"\s+", " ", self.raw_text()).strip()

    def raw_text(self):
        """Text as in the source (`$node text -pre`), not normalized."""
        if self.is_text:
            return to_str(self.call("text", "-pre"))
        return "".join(child.raw_text() for child in self.children())

    # -- attributes and style -----------------------------------------
    def attr(self, name, default=None):
        """Attribute value, or `default` when the attribute is absent."""
        return self.attrs().get(name.lower(), default)

    def has_attr(self, name):
        return name.lower() in self.attrs()

    def attrs(self):
        return kv_to_dict(self.view.tk, self.call("attr"))

    def style(self, name=None):
        """Computed CSS property (`$node property`), or all as a dict."""
        if name is None:
            return kv_to_dict(self.view.tk, self.call("property"))
        return to_str(self.call("property", name))

    def bbox(self):
        """(x1, y1, x2, y2) in the coordinates of the Tkhtml widget."""
        return tuple(int(v) for v in to_list(self.view.tk,
                                             self.view.html.call("bbox",
                                                                 self.handle)))

    # -- form controls ------------------------------------------------
    @property
    def widget(self):
        """The Tk widget that renders this node (form controls), or None."""
        path = to_str(self.call("replace"))
        return TclWidget(self.view, path) if path else None

    def form(self):
        """The Form this control belongs to."""
        return self.view.form_of(self)
