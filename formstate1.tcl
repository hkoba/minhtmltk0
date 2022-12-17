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

    option -window ""; # Owner minhtmltk of this formstate.
    option -data ""; # Other "satellite" data from Dynamic HTML.
    option -outer-data ""; # Other "satellite" data from User.

    option -node ""
    option -logger ""

    # $html search {input | textarea | select} -root $options(-node)

    variable myNodeDict [dict create]
    variable myNodeList {}

    variable myNameList {}
    variable myNameDict [dict create]
    
    method myvar name {
        myvar $name
    }

    # 
    option -debug 0
    method dvars {msg varName args} {
	if {$options(-debug) >= 2} {
	    puts -nonewline stderr "$msg "
	    foreach vn [list $varName {*}$args] {
		if {[uplevel 1 [list info exists $vn]]} {
		    puts -nonewline stderr "$vn=[uplevel 1 [list set $vn]] "
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
	    set is_array [dict get $myNameDict $name is_array]
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
	set is_array [dict get $myNameDict $name is_array]
	if {$is_array} {
	    $self multi set $name $value
	} else {
	    set fst_node [lindex [dict get $myNameDict $name nodeList] 0]
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
	    set node_list $myNodeList
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
	if {[dict get $myNameDict $name is_array]} {
            if {![dict exists $myNodeDict $node value]} return
	    # multi
	    $self dvars "Var of $name" $vn
	    if {[set $vn] ne "" && [set $vn]} {
		set value [dict get $myNodeDict $node value]
		uplevel 1 $command
	    }
	} elseif {[dict get $myNameDict $name choiceList] ne ""} {
            if {![dict exists $myNodeDict $node value]} return
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
	if {[dict get $dict is_array]} {
	    set result [$self multi get $name]
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

    method {multi forEach} {varNameList name valueList command} {
        lassign $varNameList varNameVar choiceVar
        upvar 1 $varNameVar varName
        if {$choiceVar ne ""} {
            upvar 1 $choiceVar choice
        }
	set arrayName [dict get $myNameDict $name array_name]
        foreach choice $valueList {
            set varName [set arrayName]($choice)
            uplevel 1 $command
        }
    }

    method {multi forAll} {varNameList name command} {
        lassign $varNameList varNameVar choiceVar
        upvar 1 $varNameVar varName
        if {$choiceVar ne ""} {
            upvar 1 $choiceVar choice
        }
	set arrayName [dict get $myNameDict $name array_name]
	foreach choice [$self choicelist $name] {
            set varName [set arrayName]($choice)
            uplevel 1 $command
	}
    }

    method {multi get} name {
	set result {}
        $self multi forAll {var value} $name {
	    if {[default $var 0]} {
		lappend result $value
	    }
	}
	set result
    }

    method {multi set} {name valueList} {
        $self multi forAll {var choice} $name {
            set $var [expr {$choice in $valueList}]
        }
    }

    method {multi unset} {name valueList} {
        $self multi forEach {var choice} $name $valueList {
            if {$choice in $valueList} {
                set $var 0
            }
        }
    }

    method {multi change} {name valueList boolean} {
        $self multi forEach var $name $valueList {
            set $var $boolean
        }
    }

    method {multi test_all} {name value args} {
        $self multi forEach {var choice} $name [list $value {*}$args] {
            if {![default $var 0]} {
                return -code return 0
            }
        }
        return 1
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

    method {node of-name} name {
        dict get $myNameDict $name nodeList
    }

    method {node at} i {
	lindex $myNodeList $i
    }
    method {node widget at} i {
	[lindex $myNodeList $i] replace
    }

    method {node add} {kind node attr args} {
        # If name is missing, set default name "".
        # If value is missing, omit value entry in $myNodeDict
        set has_value [dict-cutvar attr value]
	$self node intern $kind $node \
	    [set name [dict-cut attr name ""]]\
	    value \
	    $attr

	dict with myNodeDict $node {
	    switch $kind {
		single {
		    set var ${selfns}::_S[$self add-name-of $node $name]
                    if {$has_value} {
                        $self add-choice-of $node $name $value
                    }
		}
		multi {
		    set array_name ${selfns}::_M[$self add-name-of $node $name 1]
		    dict set myNameDict $name array_name $array_name
                    if {$has_value} {
                        set var [set array_name]($value)
                        $self add-choice-of $node $name $value
                    } else {
                        set var [set array_name]
                    }
		}
		default {
		    $self add-name-of $node $name
		    set var ${selfns}::_T[$self node count]
		    set $var $value
		}
	    }
	}

        if {$args ne ""} {
            $self node trace configure $node {*}$args
        }

	$self node var $node
    }

    method {node trace configure} {node args} {
        set var [$self node var $node]
        set name [$self node name $node]
        set curTraceList [trace info variable $var]

        foreach {meth cmd} $args {
            set trace [dict get {getter read setter write} $meth]
            # This [from args] removes getter/setter spec from $args.
            if {[llength [lindex $cmd 0]] != 2} {
                error "Node $meth must be an list of LAMBDA+ARGS... (of apply)!"
            }
            # Below is a workaround to avoid duplicate trace
            if {[lsearch -index 0 $curTraceList $trace] >= 0} continue
            dict set myNodeDict $node $meth $cmd

            if {[dict get $myNameDict $name is_array]} {
                set array_name [dict get $myNameDict $name array_name]
                trace add variable $array_name $trace \
                    [list $self do-trace array $trace $node]
            } else {
                trace add variable $var $trace \
                    [list $self do-trace scalar $trace $node $var]
            }
        }
    }

    method {sync-trace scalar} {node varName} {
        set $varName [set $varName]
    }
    method {do-trace scalar read} {node varName args} {
        set apply [dict get $myNodeDict $node getter]
	set $varName [apply {*}$apply]
    }
    method {do-trace scalar write} {node varName args} {
        if {[set apply [dict-default [dict get $myNodeDict $node] setter]] ne ""} {
            apply {*}$apply [set $varName]
        }
        if {$options(-window) ne ""
            && [$options(-window) state is DocumentReady]} {
            if {$options(-debug) >= 2} {
                puts [list trace scalar write var $varName \
                          value [set $varName] \
                          node $node [$node tag] [$node attr]]
            }
            $options(-window) node event trigger $node change
        }
    }
    method {do-trace array read} {node arrayName ix args} {
        set apply [dict get $myNodeDict $node getter]
	set [set arrayName]($ix) [apply {*}$apply $ix]
	$self dvars "trace array read " arrayName ix
    }
    method {do-trace array write} {node arrayName ix args} {
        if {[set apply [dict-default [dict get $myNodeDict $node] setter]] ne ""} {
            apply {*}$apply $ix [set [set arrayName]($ix)]
            $self dvars "trace array write " arrayName ix
        }
        if {$options(-window) ne ""
            && [$options(-window) state is DocumentReady]} {
            if {$options(-debug) >= 2} {
                puts [list trace array write $node [$node tag] [$node attr]]
            }
            $options(-window) node event trigger $node change
        }
    }

    method add-name-of {node name {_is_array 0}} {
	if {![dict exists $myNameDict $name]} {
	    dict set myNameDict $name [dict create \
					   nodeList [list $node] \
					   choiceList [list] \
					   choiceDict [dict create] \
					   is_array $_is_array \
                                           id [dict size $myNameDict]\
					  ]
	} else {
	    dict with myNameDict $name {
		if {$is_array != $_is_array} {
		    error "Var $name is_array is changed(was $is_array, new $_is_array)"
		}
		lappend nodeList $node
	    }
	}
	dict get $myNameDict $name id
    }
    method add-choice-of {node name value} {
	dict with myNameDict $name {
	    if {![dict exists $choiceDict $value]} {
		lappend choiceList $value
	    }
	    dict lappend choiceDict $value $node
	}
    }

    method {name dict get} {name key} {
	dict get $myNameDict $name $key
    }

    method {name dict dump} {name} {
	dict get $myNameDict $name
    }

    method {node count} {} {dict size $myNodeDict}
    method {node name} {node} {
        dict get $myNodeDict $node name
    }
    method {node intern} {kind node name valueVar attr} {
        upvar 1 $valueVar value
	if {[dict exists $myNodeDict $node]} {
	    error "Duplicate node name! $node"
	}
	lappend myNodeList $node
	dict set myNodeDict $node \
	    [dict create kind $kind name $name attr $attr\
                 type "" var ""]
        if {[info exists value]} {
            dict set myNodeDict $node value $value
        }
	set node
    }
    method {node var} {node} {
	$self node dict get $node $ourSlots(var)
    }
    method {node value} {node} {
	set [$self node var $node]
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
