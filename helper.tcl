# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

#
# ::minhtmltk::helper is a collection of snit::macros to build up minhtmltk.
# Although these APIs are still evolving, some of these macros might be
# reused to another tkhtml3 project.
#
# My biggest reason to split codes into macros is to group related
# codes into files and keep each of them short.  But in general, I
# don't want to recommend this coding style because each of these
# snit::macros dont have individual tcltests!
#

snit::macro ::minhtmltk::helper::start {} {
    upvar 1 __helpers_installed installed
    if {[info exists installed]} {
	unset installed
    }
    array set installed {}
}

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

