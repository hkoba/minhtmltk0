"""Pages served from Python through an `app:` URI scheme.

Links and form submissions are turned into Python calls; the handler
returns the next page.

    python3 examples/app_scheme.py
"""

import html
import sys
import tkinter
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from minhtmltk import HtmlView  # noqa: E402

GUESTBOOK = []


def page(body):
    return "text/html", f"<html><body>{body}</body></html>"


def route(uri, mode):
    parts = urlsplit(uri)          # app:/path?query
    query = parse_qs(parts.query)
    if parts.path in ("/", "/index"):
        entries = "".join(f"<li>{html.escape(e)}</li>" for e in GUESTBOOK)
        return page(f"""
            <h2>Guestbook</h2>
            <ul>{entries or '<li><i>empty</i></li>'}</ul>
            <form action="app:/add">
              <input type="text" name="message" size="30">
              <input type="submit" name="add" value="Add">
            </form>
            <p><a href="app:/about">about</a></p>""")
    if parts.path == "/add":
        msg = query.get("message", [""])[0].strip()
        if msg:
            GUESTBOOK.append(msg)
        return page('<p>Added.</p><p><a href="app:/index">back</a></p>')
    if parts.path == "/about":
        return page('<p>Served by Python.</p><p><a href="/index">home</a></p>')
    raise LookupError(f"no such page: {uri}")


def main():
    root = tkinter.Tk()
    root.title("minhtmltk app: scheme demo")
    view = HtmlView(root)
    view.pack(fill="both", expand=True)
    view.register_scheme("app", route)

    def on_submit(ev):
        # <form action="app:/add"> + values -> app:/add?message=...
        from urllib.parse import urlencode
        values = ev.form.get_all()
        view.load_uri(f"{ev.form.action}?{urlencode(values, doseq=True)}")

    view.on("submit", on_submit)
    view.load_uri("app:/index")
    root.mainloop()


if __name__ == "__main__":
    main()
