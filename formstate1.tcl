#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec tclsh -encoding utf-8 "$0" ${1+"$@"}

package require snit

source [file dirname [info script]]/utils.tcl

namespace eval ::minhtmltk::formstate {
    namespace import ::minhtmltk::utils::*
}

snit::type ::minhtmltk::formstate {
    option -name ""
    option -action ""

    option -data ""; # Other "satellite" data from Dynamic HTML.
    option -outer-data ""; # Other "satellite" data from User.

    option -node ""
    option -logger ""

    # $html search {input | textarea | select} -root $options(-node)

    variable myNodeDict [dict create]

    variable myNameList {}
    variable myNameDict [dict create]
    
    typevariable ourSlots -array [set ls {}; foreach i {
	kind
	var
	is_array
	array_name
	type
	name
	value
	attr
    } {lappend ls $i $i}; set ls]

    
    #
    # Returns `name` `value` (flattened) list in $NODE_LIST order.
    # Same `name` can occur multiple times as in usual HTTP query string
    #
    method serialize {{node_list ""}} {
	if {$node_list eq ""} {
	    set node_list [dict keys $myNodeDict]
	}
	set result ""
	foreach node $node_list {
	    set name [dict get $myNodeDict $node name]
	    set vn [dict get $myNodeDict $node var]
	    if {![info exists $vn]} continue
	    if {[dict get $myNodeDict $node is_array]} {
		lappend $name [dict get $myNodeDict $node value]
	    } else {
		lappend $name [set $vn]
	    }
	}
	set result
    }
    
    method get_all {} {
	$self serialize
    }

    method get {name {outVar ""}} {
	if {$outVar ne ""} {
	    upvar 1 $outVar result
	}
	set dict [dict get $myNameDict $name]
	set fst_node [lindex [dict get $dict nodeList] 0]
	if {[$self node dict get $fst_node is_array]} {
	    set arrayName [$self node dict get $fst_node array_name]
	    set result {}
	    foreach value [$self choicelist $name] {
		if {[default arrayName($value) 0]} {
		    lappend result $value
		}
	    }
	    set result
	} elseif {[info exists [set vn [$self node var $fst_node]]]} {
	    set result [set $vn]
	    if {$outVar ne ""} {
		return 1
	    } else {
		return $result
	    }
	} else {
	    if {$outVar ne ""} {
		return 0
	    } else {
		error "Form variable 'name=$name' is not set"
	    }
	}
    }

    method names args {
	dict keys $myNameDict {*}$args
    }

    method choicelist name {
	dict get $myNameDict $name choiceList
    }

    option -debug yes
    method dvars {msg varName args} {
	if {$options(-debug)} {
	    puts -nonewline stderr "$msg "
	    foreach vn [list $varName {*}$args] {
		puts -nonewline stderr "$vn=[set $vn] "
	    }
	    puts stderr ""
	}
    }

    method {node add} {kind node attr args} {
	$self node intern $kind $node \
	    [set name [dict-cut attr name ""]]\
	    [set value [dict-cut attr value ""]] \
	    $attr
	$self dvars "node add" myNodeDict
	dict with myNodeDict $node {
	    switch $kind {
		single {
		    set var ${selfns}::_S[$self add-name-of $node $name]
		    $self dvars "after add-name-of" myNameDict
		    $self add-choice-of $node $name $value
		}
		multi {
		    set is_array 1
		    set array_name ${selfns}::_M[$self add-name-of $node $name]
		    set var [set array_name]($value)
		    $self add-choice-of $node $name $value
		}
		default {
		    $self add-name-of $node $name
		    set var ${selfns}::_T[$self node count]
		}
	    }
	    foreach {meth trace} {
		getter write
		setter read
	    } {
		if {[set cmd [from args $meth ""]] ne ""} {
		    if {[llength $cmd] != 2} {
			error "Node $meth must be an LAMBDA (of apply)!"
		    }
		    trace add variable $var $trace \
			[list $self trace handle $trace $cmd]
		}
	    }
	    if {[llength $args]} {
		error "Unknown node arguments: $args"
	    }
	}

    }
    method {trace handle read} {command varName args} {
	set $varName [apply $command]
    }
    method {trace handle write} {command varName args} {
	apply $command [set $varName]
    }

    method add-name-of {node name} {
	if {![dict exists $myNameDict $name]} {
	    dict set myNameDict $name [dict create \
					   nodeList [list $node] \
					   choiceList [list] \
					   choiceDict [dict create]]
	} else {
	    dict with myNameDict $name {
		lappend nodeList $node
	    }
	}
	dict size $myNameDict
    }
    method add-choice-of {node name value} {
	dict with myNameDict $name {
	    if {![dict exists $choiceDict $value]} {
		lappend choiceList $value
	    }
	    dict lappend choiceDict $value $node
	}
    }

    method {node count} {} {dict size $myNodeDict}
    method {node intern} {kind node name value attr} {
	if {[dict exists $myNodeDict $node]} {
	    error "Duplicate node name! $node"
	}
	dict set myNodeDict $node \
	    [dict create kind $kind name $name value $value attr $attr\
		type "" var "" is_array 0]
	set node
    }
    method {node var} {node} {
	$self node dict get $node $ourSlots(var)
    }
    method {node dict set} {node key value} {
	dict set myNodeDict $node $ourSlots($key) $value
    }
    method {node dict get} {node key} {
	if {![info exists ourSlots($key)]} {
	    error "Unknown slot $key"
	}
	dict get $myNodeDict $node $key
    }
    method {node path} node {
        if {[set id [$node attr -default "" id]] eq ""} {
            set id [string map {: _} $node]
        }
        return $myHtml._$id
    }

    proc list-intern {listVar value} {
	upvar 1 $listVar list
	if {![info exists list]
	    || $value ni $list} {
	    lappend list $value
	}
    }
}
