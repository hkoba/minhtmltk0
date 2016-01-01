# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::nodeutil {} {

    #========================================
    # node utils
    #========================================

    method innerTextPre node {
	set contents {}
	foreach kid [$node children] {
	    append contents [$kid text -pre]
	}
	set contents
    }

    # extract attr (like [lassign]) returns [dict]
    proc node-atts-assign {node args} {
        set _atts {}
        foreach _spec $args {
            lassign $_spec _key _default
            upvar 1 $_key _upvar
            set value [$node attr -default $_default $_key]
            lappend _atts $_key $value
            set _upvar $value
        }
        set _atts
    }

}
