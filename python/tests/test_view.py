import unittest

from helpers import HTML_DIR, ViewTestCase
from minhtmltk import Node, StaleNodeError


class ViewTest(ViewTestCase):

    def test_create_and_class(self):
        self.assertEqual(self.view.winfo_class(), "Minhtmltk")
        self.assertEqual(self.view.cget("allow-script"), "no")

    def test_load_html_and_search(self):
        self.load("<h1 id=t class='a b'>Hello <b>world</b></h1>")
        h1 = self.view.find("#t")
        self.assertIsInstance(h1, Node)
        self.assertEqual(h1.tag, "h1")
        self.assertEqual(h1.attr("class"), "a b")
        self.assertIsNone(h1.attr("missing"))
        self.assertEqual(h1.attr("missing", "dflt"), "dflt")
        self.assertEqual(h1.attrs(), {"id": "t", "class": "a b"})
        self.assertEqual(h1.text(), "Hello world")
        self.assertEqual([c.tag for c in h1.children()], ["", "b"])
        self.assertEqual(h1.parent().tag, "body")
        self.assertEqual(self.view.text(), "Hello world")
        self.assertEqual(self.view.search("b")[0].style("font-weight"),
                         "bold")

    def test_stale_node(self):
        self.load("<h1>one</h1>")
        h1 = self.view.find("h1")
        self.load("<h1>two</h1>")
        with self.assertRaises(StaleNodeError):
            h1.tag
        self.assertEqual(self.view.find("h1").text(), "two")

    def test_load_uri_and_history(self):
        self.view.load_uri(str(HTML_DIR / "001.html"))
        self.root.update()
        self.assertTrue(self.view.location.endswith("/001.html"))
        self.assertEqual(self.view.find("h2").text(), "Hello!")
        self.view.load_uri(str(HTML_DIR / "005.html"))
        self.root.update()
        self.assertEqual(len(self.view.history()), 2)
        self.view.back()
        self.root.update()
        self.assertTrue(self.view.location.endswith("/001.html"))
        self.view.forward()
        self.root.update()
        self.assertTrue(self.view.location.endswith("/005.html"))

    def test_parameter(self):
        self.view.load_uri(str(HTML_DIR / "005.html"),
                           parameter={"foo": "xxx"})
        self.root.update()
        self.assertEqual(self.view.parameter("foo"), "xxx")
        self.assertEqual(self.view.form().get("foo"), "xxx")
        self.assertEqual(self.view.form().get("bar"), "def")

    def test_widget_proxy(self):
        self.load("<form><input type=text name=q value=abc></form>")
        entry = self.view.find("input").widget
        self.assertEqual(entry.winfo_class(), "TEntry")
        self.assertEqual(entry.get(), "abc")
        entry.insert("end", "X")
        self.assertEqual(self.view.form().get("q"), "abcX")

    def test_scripts_off_by_default(self):
        self.load('<input type=button name=b onclick="set ::PY_RAN 1">')
        self.assertTrue(any("allow-script is off" in " ".join(e)
                            for e in self.view.log()))


if __name__ == "__main__":
    unittest.main()
