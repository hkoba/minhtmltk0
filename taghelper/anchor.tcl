# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

::minhtmltk::helper::add node a

snit::macro ::minhtmltk::helper::anchor {} {

    # <a>
    method {add node a} node {
        if {[$node attr -default "" href] eq ""} return
        $node dynamic set link
    }
}
