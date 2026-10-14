import unittest

from helpers import ViewTestCase

PAGE = """
<form name=f1 action="app:/save">
  <input type=text name=q value=abc>
  <input type=checkbox name=c value=1 checked>
  <input type=checkbox name=c value=2>
  <input type=radio name=r value=x checked>
  <input type=radio name=r value=y>
  <select name=s><option value=a>A<option value=b selected>B</select>
  <textarea name=t>hello</textarea>
  <input type=hidden name=h value=hid>
  <input type=submit name=go value=Go>
</form>
<form name=f2><input type=text name=other value=o></form>
"""


class FormTest(ViewTestCase):

    def setUp(self):
        super().setUp()
        self.load(PAGE)

    def test_forms(self):
        forms = self.view.forms()
        self.assertEqual([f.name for f in forms], ["f1", "f2"])
        self.assertEqual(self.view.form("@f2").get_all(), {"other": "o"})
        self.assertEqual(self.view.form(1).name, "f2")
        self.assertEqual(forms[0].node.tag, "form")
        self.assertEqual(forms[0].action, "app:/save")

    def test_get_all(self):
        self.assertEqual(self.view.form().get_all(), {
            "q": "abc", "c": ["1"], "r": "x", "s": "b", "t": "hello",
            "h": "hid", "go": "Go"})

    def test_get_and_choices(self):
        f = self.view.form()
        self.assertEqual(f.get("c"), ["1"])
        self.assertEqual(f.get("s"), "b")
        self.assertTrue(f.is_multi("c"))
        self.assertFalse(f.is_multi("q"))
        self.assertEqual(f.choices("c"), ["1", "2"])
        self.assertEqual(f.choices("s"), ["a", "b"])
        self.assertEqual([n.attr("value") for n in f.nodes_of("r")],
                         ["x", "y"])

    def test_set_silent_and_notify(self):
        self.view.on("change", self.record())
        f = self.view.form()
        f.set("q", "new")
        f.set("c", ["1", "2"])
        f.set("r", "y")
        f.set("s", "a")
        f.set("t", "bye")
        self.assertEqual(self.out, [])
        self.assertEqual(f.get_all(), {
            "q": "new", "c": ["1", "2"], "r": "y", "s": "a", "t": "bye",
            "h": "hid", "go": "Go"})
        self.assertEqual(self.view.find("input[name=q]").widget.get(),
                         "new")
        f.set("q", "loud", notify=True)
        self.assertEqual([o[0] for o in self.out], ["change"])

    def test_form_of_node(self):
        node = self.view.find("input[name=other]")
        self.assertEqual(self.view.form_of(node).name, "f2")
        self.assertEqual(node.form().name, "f2")

    def test_dump_restore(self):
        dump = self.view.form_dump()
        self.assertEqual(dump[1], {"other": "o"})
        self.view.form().set("q", "changed")
        self.view.form_restore(dump)
        self.assertEqual(self.view.form().get("q"), "abc")


if __name__ == "__main__":
    unittest.main()
