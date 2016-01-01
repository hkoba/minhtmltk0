# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper {helper args} {
    upvar 1 __helpers_installed installed
    if {![info exists installed]} {
	array set installed {}
    }
    set vn installed($helper)
    if {[info exists $vn]} continue
    uplevel 1 [list ::minhtmltk::helper::${helper} {*}$args]
    set $vn 1
}

foreach fn [glob [file rootname [info script]]/*.tcl] {
    source $fn
}

