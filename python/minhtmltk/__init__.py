"""minhtmltk for Python: the Tkhtml3-based HTML widget from tkinter.

    import tkinter
    from minhtmltk import HtmlView

    root = tkinter.Tk()
    view = HtmlView(root, html='<form><input name=q><input type=submit></form>')
    view.pack(fill='both', expand=True)
    view.on('submit', lambda ev: print(ev.form.get_all()))
    root.mainloop()
"""

from ._loader import default_tcl_dir, ensure_loaded
from ._tcl import TclWidget
from .form import Form
from .node import Node, StaleNodeError
from .view import EVENTS, Event, Handler, HtmlView

__all__ = ["HtmlView", "Event", "Handler", "EVENTS", "Node", "Form",
           "StaleNodeError", "TclWidget", "ensure_loaded",
           "default_tcl_dir"]
