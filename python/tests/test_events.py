import unittest

from helpers import ViewTestCase


class EventTest(ViewTestCase):

    def test_global_click_once_innermost(self):
        self.view.on("click", self.record())
        self.load("<div><h2 id=t>Hi</h2></div>")
        self.view.click(self.view.find("#t"))
        self.assertEqual(self.out, [("click", "h2", {})])

    def test_handlers_survive_reload(self):
        self.view.on("click", self.record("g"))
        self.view.on("click", self.record("tag"), selector="h2")
        self.view.on("click", self.record("sel"), selector="#t")
        for n in range(2):
            self.load("<h2 id=t>Hi</h2><h2>other</h2>")
            self.out.clear()
            self.view.click(self.view.find("#t"))
            self.view.click(self.view.search("h2")[1])
            # #t: node-level shadows the tag handler; global always runs
            self.assertEqual([o[0] for o in self.out],
                             ["sel", "g", "tag", "g"], f"round {n}")

    def test_several_events(self):
        self.view.on("ready", self.record())
        self.view.on("submit", self.record())
        self.view.on("change", self.record())
        self.load("<form name=f action='app:/x'>"
                  "<input type=text name=q value=abc>"
                  "<input type=submit name=go value=Go></form>")
        self.assertEqual([o[0] for o in self.out], ["ready"])
        self.view.click(self.view.find("input[type=submit]"))
        self.assertEqual(self.out[-1][0], "submit")
        self.assertEqual(self.out[-1][2]["name"], "go")
        self.assertIn("form", self.out[-1][2])
        entry = self.view.find("input[name=q]").widget
        entry.insert("end", "X")
        self.assertEqual(self.out[-1][0], "change")

    def test_event_object(self):
        seen = []
        self.view.on("submit", lambda ev: seen.append(ev))
        self.load("<form name=f action='app:/save'>"
                  "<input type=text name=q value=abc>"
                  "<input type=submit name=go value=Go></form>")
        self.view.click(self.view.find("input[type=submit]"))
        ev = seen[0]
        self.assertEqual(ev.name, "submit")
        self.assertEqual(ev.button, "go")
        self.assertEqual(ev.node.attr("name"), "go")
        self.assertEqual(ev.form.name, "f")
        self.assertEqual(ev.form.action, "app:/save")
        self.assertEqual(ev.form.get_all(), {"q": "abc", "go": "Go"})

    def test_stop_prevents_link_navigation(self):
        def intercept(ev):
            self.out.append(ev.node.attr("href"))
            return True
        self.view.on("click", intercept, selector="a")
        self.load('<a id=l href="no-such-file.html">link</a>')
        self.view.click(self.view.find("#l"))
        self.assertEqual(self.out, ["no-such-file.html"])
        self.assertEqual(self.view.location, "")   # not navigated
        self.assertEqual(self.view.find("#l").text(), "link")

    def test_node_level_shadows_and_perform_default(self):
        self.view.on("click", lambda ev: self.out.append("shadow"),
                     selector="a[href$='one']")
        # ("a.follow" would be a tag.class handler, which a node-level
        # one shadows; "#y" is node-level.)
        self.view.on("click", lambda ev: ev.perform_default(),
                     selector="#y")

        self.view.register_scheme(
            "app", lambda uri, mode: ("text/html", f"<p>{uri}</p>"))
        self.load('<a id=x href="app:/one">x</a>'
                  '<a id=y class=follow href="app:/two">y</a>')
        self.view.click(self.view.find("#x"))
        self.assertEqual(self.out, ["shadow"])
        self.assertEqual(self.view.location, "")
        self.view.click(self.view.find("#y"))
        self.root.update()
        self.assertEqual(self.view.location, "app:/two")

    def test_off(self):
        h = self.view.on("click", self.record())
        self.load("<h2>Hi</h2>")
        self.view.click(self.view.find("h2"))
        self.view.off(h)
        self.view.click(self.view.find("h2"))
        self.assertEqual(len(self.out), 1)
        s = self.view.on("click", self.record("sel"), selector="h2:first-child")
        self.view.click(self.view.find("h2"))
        self.view.off(s)
        self.view.click(self.view.find("h2"))
        self.assertEqual(len(self.out), 2)

    def test_callback_exception_is_reported(self):
        reports = []
        self.view.report_callback_exception = \
            lambda *info: reports.append(info[1])
        self.view.on("click", lambda ev: 1 / 0)
        self.view.on("click", self.record("after"))
        self.load("<h2>Hi</h2>")
        self.view.click(self.view.find("h2"))
        self.assertEqual(len(reports), 1)
        self.assertIsInstance(reports[0], ZeroDivisionError)
        self.assertEqual([o[0] for o in self.out], ["after"])

    def test_unknown_event(self):
        with self.assertRaises(ValueError):
            self.view.on("keypress", self.record())

    def test_trigger(self):
        self.view.on("mousemove", self.record())
        self.load("<h2>Hi</h2>")
        self.view.trigger("mousemove", self.view.find("h2"), x=3, y=4)
        self.assertEqual(self.out, [("mousemove", "h2", {"x": "3", "y": "4"})])


if __name__ == "__main__":
    unittest.main()
