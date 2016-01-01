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

    proc for-upward-node {nvar startNode command args} {
    	upvar 1 $nvar n

	set nodeList ""
    	for {set n $startNode} {$n ne ""} {set n [$n parent]} {
	    lappend nodeList $n
    	}
	foreach n [list {*}$nodeList {*}$args] {
    	    rethrow-control {uplevel 1 $command}
	}
    }

    proc tag-class-list-of-node node {
	set list ""
	set node [parent-of-textnode $node]
	if {$node ne "" && [set tag [$node tag]] ne ""} {
	    foreach cls [$node attr -default "" class] {
		lappend list [list $tag.$cls $node]
	    }
	    lappend list [list $tag $node]
	}
	set list
    }

    proc parent-of-textnode node {
	if {[$node tag] eq ""} {
	    $node parent
	} else {
	    set node
	}
    }

}
