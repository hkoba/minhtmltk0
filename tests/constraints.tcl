# -*- mode: tcl; coding: utf-8 -*-
package require Tk

namespace eval tcltest {
    proc deleteWindows {} {
	destroy {*}[winfo children .]
    }
    namespace export *
}
