#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec tclsh -encoding utf-8 "$0" ${1+"$@"}

namespace eval ::minhtmltk::utils {
    proc default {varName {default ""}} {
	if {[info exists $varName]} {
	    set $varName
	} else {
	    set default
	}
    }

    proc dict-cut {dictVar key args} {
	upvar 1 $dictVar dict
	if {[dict exists $dict $key]} {
	    set res [dict get $dict $key]
	    dict unset dict $key
	    set res
	} elseif {[llength $args]} {
	    lindex $args 0
	} else {
	    error "No such key: $key"
	}
    }

    proc dict-getvar {dict args} {
	upvar 1 [lindex $args end] outvar
	if {![dict exists $dict {*}[lrange $args 0 end-1]]} {
	    return 0
	}
	set outvar [dict get $dict {*}[lrange $args 0 end-1]]
	return 1
    }
    
    proc rethrow-control {command {no_loop no}} {
	set rc [catch {uplevel 1 $command} result]
	if {$no_loop && $rc in {3 4}} {
	    return $result
	} else {
	    return -code $rc $result
    	}
    }

    proc parsePosixOpts {varName {dict {}}} {
	upvar 1 $varName opts

	for {} {[llength $opts]
		&& [regexp {^--?([\w\-]+)(?:(=)(.*))?} [lindex $opts 0] \
			-> name eq value]} {set opts [lrange $opts 1 end]} {
	    if {$eq eq ""} {
		set value 1
	    }
	    dict set dict -$name $value
	}
	set dict
    }
    
    namespace export *
}
