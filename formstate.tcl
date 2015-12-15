#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec tclsh -encoding utf-8 "$0" ${1+"$@"}

package require snit

namespace eval ::minhtmltk::formstate {
    namespace import ::minhtmltk::*
}

snit::type ::minhtmltk::formstate {
    option -name
    option -action

    option -node

    variable myNameList {}
    variable myNameDict -array {}
    
    typevariable ourItemSlots {
	name {}
	type {}
	valueList {}
	value2IxDict {}
	labelList {}
	nodeList {}
	optList {}
    }
    
    typemethod {slot names} {} {
	array names ourItemSlots
    }

    method names {} {
	set myNameList
    }

    # Each form variable has array with same name, prefixed by '#'.
    method {item of-name} {name {orError ""}} {
	set vn myNameDict($name)
	if {[info exists $vn]} {
	    set $vn
	} elseif {$orError ne ""} {
	    error [list $orError $name]
	} else {
	    lappend myNameList $name
	    set escaped [string map {: _} $name]
	    set item [set $vn ${selfns}::#$escaped]
	    array set $item $ourItemSlots
	    set ${item}(name) $name
	    set item
	}
    }

    # For multiple choice(checkbox & select multi), each flags are
    # held as array element, prefixed by '#'.
    # The flag can be empty.
    method {item var} {item {value ""}} {
	return ${item}(#$value)
    }
    
    method {item type} item { set ${item}(type) }
    method {item name} item { set ${item}(name) }
    method {item valuelist} item { set ${item}(valueList) }
    # method {item nodelist} item { set ${item}(nodeList) }
    # method {item optlist} item { set ${item}(optList) }

    #
    # Caller must explicitly give required slots of opts.
    # (Because I don't want to rely on [$node attr] API from this class).
    #
    method {item register node} {kind node opts} {
	set name [dict-cut opts name]
	set value [dict-cut opts value]
	set item [$self item of-name $name]
	set vn ${item}(type)
	if {[info exists $vn] && [set $vn] ne "" && [set $vn] ne $kind} {
	    error "item type mismatch! was:'[set $vn]' new:'$kind' for name=$name value=$value"
	} else {
	    set $vn $kind
	}
	dict set ${item}(value2IxDict) $value [llength ${item}(valueList)]
	lappend ${item}(valueList) $value
	lappend ${item}(labelList) [dict-cut opts label ""]
	lappend ${item}(nodeList) $node
	lappend ${item}(optList) $opts
	set item
    }
}
