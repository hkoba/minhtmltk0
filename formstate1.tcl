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
    variable myNodeList {}

    variable myNameList {}
    variable myNameDict [dict create]
    
    # 
    option -debug no
    method dvars {msg varName args} {
	if {$options(-debug)} {
	    puts -nonewline stderr "$msg "
	    foreach vn [list $varName {*}$args] {
		if {[info exists $vn]} {
		    puts -nonewline stderr "$vn=[set $vn] "
		} else {
		    puts -nonewline stderr "${vn}:unset "
		}
	    }
	    puts stderr ""
	}
    }

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

    method get_all {{names ""}} {
        if {$names eq ""} {
            set names [$self names]
        }
	set result {}
	foreach name $names {
	    set nodelist [dict get $myNameDict $name nodeList]
	    set is_array [dict get $myNodeDict [lindex $nodelist 0] is_array]
	    # set values {}
	    foreach node $nodelist {
		$self current node with name value $node {
		    lappend values $value
		}
	    }
	    if {[info exists values]} {
		if {$is_array} {
		    lappend result $name $values
		} else {
		    lappend result $name [lindex $values 0]
		}
		unset values
	    }
	}
	set result
    }

    method set {name value} {
	if {![dict exists $myNameDict $name]} {
	    error "Unknown name! $name"
	}
	set fst_node [lindex [dict get $myNameDict $name nodeList] 0]
	set is_array [dict get $myNodeDict $fst_node is_array]
	if {$is_array} {
	    $self array set $name $value
	} else {
	    set [$self node var $fst_node] $value
	}
    }
    
    #
    # [$form node serialize ?$NODE_LIST?]
    #
    # Returns `name` `value` (flattened) list in $NODE_LIST order.
    # Same `name` can occur multiple times as in usual HTTP query string.
    # Caller must supply correct $NODE_LIST (of `Successful controls`).
    #
    method {node serialize} {{node_list ""}} {
	if {$node_list eq ""} {
	    set node_list [dict keys $myNodeDict]
	}
	set result ""
	foreach node $node_list {
	    $self current node with name value $node {
		lappend result $name $value
	    }
	}
	set result
    }
    
    method {current node with name value} {node command} {
	if {![dict exists $myNodeDict $node]} {
	    error "Unknown node $node"
	}
	set vn [dict get $myNodeDict $node var]
	if {![info exists $vn]} return
	upvar 1 name name
	set name [dict get $myNodeDict $node name]
	upvar 1 value value
	if {[dict get $myNodeDict $node is_array]} {
	    # multi
	    if {[set $vn]} {
		set value [dict get $myNodeDict $node value]
		uplevel 1 $command
	    }
	} elseif {[dict get $myNameDict $name choiceList] ne ""} {
	    # single
	    if {[set $vn] eq [dict get $myNodeDict $node value]} {
		set value [set $vn]
		uplevel 1 $command
	    }
	} else {
	    # otherwise
	    set value [set $vn]
	    uplevel 1 $command
	}
    }

    method get {name {outVar ""}} {
	if {$outVar ne ""} {
	    upvar 1 $outVar result
	}
	set dict [dict get $myNameDict $name]
	set fst_node [lindex [dict get $dict nodeList] 0]
	if {[$self node dict get $fst_node is_array]} {
	    set result [$self array get $name]
	    if {$outVar ne ""} {
		return [llength $result]
	    } else {
		return $result
	    }
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

    method {array get} name {
	set fst_node [lindex [dict get $myNameDict $name nodeList] 0]
	set arrayName [$self node dict get $fst_node array_name]
	set result {}
	foreach value [$self choicelist $name] {
	    if {[default [set arrayName]($value) 0]} {
		lappend result $value
	    }
	}
	set result
    }

    method {array set} {name values} {
	set fst_node [lindex [dict get $myNameDict $name nodeList] 0]
	set arrayName [$self node dict get $fst_node array_name]
	foreach choice [$self choicelist $name] {
	    set [set arrayName]($choice) [expr {$choice in $values}]
	}
    }

    method names args {
	dict keys $myNameDict {*}$args
    }

    method choicelist name {
	dict get $myNameDict $name choiceList
    }

    method namedvars {name {ix ""}} {
	dict with myNameDict $name {
	    if {$ix ne ""} {
		return [$self node var [lindex $nodeList $ix]]
	    } else {
		return [struct::list map $nodeList [list $self node var]]
	    }
	}
    }

    method {node at} i {
	lindex $myNodeList $i
    }
    method {node widget at} i {
	[lindex $myNodeList $i] replace
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
		    dict set myNodeDict $node array_name $array_name
		    set var [set array_name]($value)
		    $self add-choice-of $node $name $value
		}
		default {
		    $self add-name-of $node $name
		    set var ${selfns}::_T[$self node count]
		    set $var $value
		}
	    }
	    foreach {meth trace} {
		getter read
		setter write
	    } {
		if {[set cmd [from args $meth ""]] ne ""} {
		    if {[llength [lindex $cmd 0]] != 2} {
			error "Node $meth must be an list of LAMBDA+ARGS... (of apply)!"
		    }
		    trace add variable $var $trace \
			[list $self trace handle $trace $var $cmd]
		}
	    }
	    if {[llength $args]} {
		error "Unknown node arguments: $args"
	    }
	}
	
	$self node var $node
    }
    method {trace handle read} {varName apply args} {
	set $varName [apply {*}$apply]
    }
    method {trace handle write} {varName apply args} {
	apply {*}$apply [set $varName]
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
	lappend myNodeList $node
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
