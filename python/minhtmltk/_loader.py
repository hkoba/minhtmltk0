"""Locate and source the Tcl sources of minhtmltk into a Tcl interpreter."""

import os
from pathlib import Path

ENV_VAR = "MINHTMLTK_TCL_DIR"

# Oldest version of the Tcl library (::minhtmltk::version) this binding
# works with.
MIN_TCL_VERSION = "0.2"


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
    check_tcl_version(tk, main)
    if allow_script and not tk.eval(
            "info exists ::minhtmltk::py::script_tag_loaded"):
        tk.call("source", str(tcl_dir / "include" / "script-tag.tcl"))
        tk.eval("set ::minhtmltk::py::script_tag_loaded 1")
    return tcl_dir


def tcl_version(tk):
    """Version of the loaded Tcl library, or None if it predates
    versioning (or is not loaded)."""
    if not int(tk.eval("info exists ::minhtmltk::version")):
        return None
    return tk.eval("set ::minhtmltk::version")


def check_tcl_version(tk, where="the loaded minhtmltk"):
    """Raise RuntimeError unless the loaded Tcl library is recent enough
    for this binding."""
    ver = tcl_version(tk)
    if ver is None or int(tk.call("package", "vcompare", ver,
                                  MIN_TCL_VERSION)) < 0:
        raise RuntimeError(
            f"minhtmltk Tcl library is too old for this Python binding: "
            f"{where} is version {ver or 'unknown (< 0.2)'}, "
            f"need >= {MIN_TCL_VERSION}; update it or set ${ENV_VAR}")
    return ver
