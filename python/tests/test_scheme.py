import base64
import unittest

from helpers import ViewTestCase

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf"
    "DwAChwGA60e6kgAAAABJRU5ErkJggg==")


class SchemeTest(ViewTestCase):

    def setUp(self):
        super().setUp()
        self.calls = []

        def app(uri, mode):
            self.calls.append((uri, mode))
            if uri.endswith(".png"):
                return "image/png", PNG
            if uri.endswith("boom"):
                raise LookupError("no such page")
            path = uri.split(":", 1)[1]
            return "text/html", (f"<h2>{path}</h2><a id=n href='next'>n</a>"
                                 "<img src='app:/dot.png'>")
        self.view.register_scheme("app", app)

    def test_load_uri_link_and_image(self):
        self.view.load_uri("app:/first")
        self.root.update()
        self.assertEqual(self.view.location, "app:/first")
        self.assertEqual(self.view.find("h2").text(), "/first")
        self.assertIn(("app:/dot.png", "binary"), self.calls)
        self.view.click(self.view.find("#n"))
        self.root.update()
        self.assertEqual(self.view.location, "app:/next")
        self.assertEqual(self.view.history(), ["app:/first", "app:/next"])

    def test_handler_error(self):
        with self.assertRaises(Exception) as cm:
            self.view.load_uri("app:/boom")
        self.assertIn("no such page", str(cm.exception))

    def test_unknown_scheme(self):
        with self.assertRaises(Exception):
            self.view.load_uri("zzz:/x")

    def test_form_to_next_page(self):
        pages = []
        self.view.register_scheme(
            "form", lambda uri, mode: (pages.append(uri) or
                                       ("text/html", "<p>ok</p>")))
        self.view.on("submit", lambda ev: self.view.load_uri(
            f"{ev.form.action}?q={ev.form.get('q')}"))
        self.load("<form action='form:/save'><input name=q value=v>"
                  "<input type=submit></form>")
        self.view.click(self.view.find("input[type=submit]"))
        self.root.update()
        self.assertEqual(pages, ["form:/save?q=v"])
        self.assertEqual(self.view.parameter("q"), "v")


if __name__ == "__main__":
    unittest.main()
