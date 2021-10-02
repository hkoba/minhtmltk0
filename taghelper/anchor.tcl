# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

::minhtmltk::taghelper::add node a

snit::macro ::minhtmltk::taghelper::anchor {} {

    # <a>
    method {add node a} node {
        if {[$node attr -default "" href] eq ""} return
        $node dynamic set link
    }
}
