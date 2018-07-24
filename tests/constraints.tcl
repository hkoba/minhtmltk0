# -*- mode: tcl; coding: utf-8 -*-
package require Tk

namespace eval tcltest {
    proc deleteWindows {} {
	destroy {*}[winfo children .]
    }
    namespace export *
}

proc iota1 {n} {
    struct::list mapfor v [struct::list iota $n] {expr {$v+1}}
}
