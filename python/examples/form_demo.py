"""A form handled by Python callbacks.

    python3 examples/form_demo.py
"""

import sys
import tkinter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from minhtmltk import HtmlView  # noqa: E402

PAGE = """
<html><body>
<h2>Sign up</h2>
<form name="signup">
  <p>Name: <input type="text" name="name" size="20"></p>
  <p>Plan:
     <label><input type="radio" name="plan" value="free" checked> free</label>
     <label><input type="radio" name="plan" value="pro"> pro</label></p>
  <p>Options:
     <label><input type="checkbox" name="opt" value="news"> newsletter</label>
     <label><input type="checkbox" name="opt" value="beta"> beta features</label></p>
  <p>Country: <select name="country">
       <option value="jp">Japan</option>
       <option value="us">USA</option>
       <option value="de">Germany</option></select></p>
  <p><input type="submit" name="ok" value="Sign up">
     <input type="button" name="reset" value="Reset"></p>
</form>
<p id="status" style="color: gray">(nothing submitted yet)</p>
</body></html>
"""


def main():
    root = tkinter.Tk()
    root.title("minhtmltk form demo")
    view = HtmlView(root, html=PAGE)
    view.pack(fill="both", expand=True)

    def on_submit(ev):
        values = ev.form.get_all()
        print("submitted:", values)
        status = view.find("#status")
        view.call("node", "set", "innerHtml", status.handle,
                  f"Thanks, {values.get('name') or 'anonymous'}! "
                  f"plan={values.get('plan')} opt={values.get('opt')} "
                  f"country={values.get('country')}")

    def on_reset(ev):
        ev.form.update({"name": "", "plan": "free", "opt": [],
                        "country": "jp"})

    def on_change(ev):
        print("changed:", ev.node.attr("name"), "->",
              ev.form.get(ev.node.attr("name")))

    view.on("submit", on_submit)
    view.on("click", on_reset, selector="input[name=reset]")
    view.on("change", on_change)
    root.mainloop()


if __name__ == "__main__":
    main()
