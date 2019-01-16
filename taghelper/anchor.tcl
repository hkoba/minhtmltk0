# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

snit::macro ::minhtmltk::taghelper::anchor {handledTagDictVar} {

    upvar 1 $handledTagDictVar handledTagDict
    dict lappend handledTagDict node a
    
    # <a>
    method {add node a} node {
        if {[$node attr -default "" href] eq ""} return
        $node dynamic set link
    }
}
