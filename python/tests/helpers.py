import os
import sys
import tkinter
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from minhtmltk import HtmlView  # noqa: E402

HTML_DIR = Path(__file__).resolve().parents[2] / "tests" / "html"


@unittest.skipUnless(os.environ.get("DISPLAY"), "needs an X display")
class ViewTestCase(unittest.TestCase):
    """One Tk root and one HtmlView per test."""

    def setUp(self):
        self.root = tkinter.Tk()
        self.view = HtmlView(self.root, emit_ready_immediately=True)
        self.view.pack(fill="both", expand=True)
        self.root.update()
        self.out = []

    def tearDown(self):
        self.root.destroy()

    def load(self, html, uri=""):
        self.view.load_html(html, uri)
        self.root.update()

    def record(self, label=None):
        def cb(ev):
            self.out.append((label or ev.name, ev.node.tag, dict(ev.args)))
        return cb
