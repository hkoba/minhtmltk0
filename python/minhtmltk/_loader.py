"""Locate and source the Tcl sources of minhtmltk into a Tcl interpreter."""

import os
from pathlib import Path

ENV_VAR = "MINHTMLTK_TCL_DIR"


def default_tcl_dir():
    """Directory holding minhtmltk0.tcl.

    $MINHTMLTK_TCL_DIR wins; otherwise the repository root, i.e. two
    levels above this package (python/minhtmltk/_loader.py).
    """
    env = os.environ.get(ENV_VAR)
    if env:
        return Path(env)
    return Path(__file__).resolve().parents[2]


def ensure_loaded(tk, tcl_dir=None, allow_script=False):
    """Source minhtmltk0.tcl (once per interpreter) and, on request,
    the <script type="tcl"> handler from include/script-tag.tcl.

    `tk` is a tkinter `TkappType` (widget.tk)."""
    tcl_dir = Path(tcl_dir) if tcl_dir else default_tcl_dir()
    main = tcl_dir / "minhtmltk0.tcl"
    if not tk.eval("info commands ::minhtmltk"):
        if not main.is_file():
            raise FileNotFoundError(
                f"{main} not found; set ${ENV_VAR} or pass tcl_dir=")
        tk.call("source", str(main))
        tk.eval("namespace eval ::minhtmltk::py {}")
    if allow_script and not tk.eval(
            "info exists ::minhtmltk::py::script_tag_loaded"):
        tk.call("source", str(tcl_dir / "include" / "script-tag.tcl"))
        tk.eval("set ::minhtmltk::py::script_tag_loaded 1")
    return tcl_dir
