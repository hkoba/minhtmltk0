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

    proc dict-default {dict key {default ""}} {
        if {[dict exists $dict $key]} {
            dict get $dict $key
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
    
    proc dict-cutvar {dictVar key {outVar ""}} {
        upvar 1 $dictVar dict
        if {$outVar eq ""} {set outVar $key}
        upvar 1 $outVar out
        if {![dict exists $dict $key]} {
            return 0
        }
        set out [dict get $dict $key]
        dict unset dict $key
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
    
    proc linsert-lsearch {list look4 args} {
        if {[set pos [lsearch -exact $list $look4]] < 0} {
            error "Can't find $look4 in $list"
        }
        linsert $list $pos {*}$args
    }

    proc adjust-coords-to {to W xVar yVar} {
        upvar 1 $xVar x
        upvar 1 $yVar y
        while {$W ne "" && $W ne $to} {
            # puts stderr W=$W,x=[winfo x $W],y=[winfo y $W]
            incr x [winfo x $W]
            incr y [winfo y $W]
            set W [winfo parent $W]
        }
    }

    # XXX: Is this ok?
    proc adjust-coords-from {from W xVar yVar} {
        upvar 1 $xVar x
        upvar 1 $yVar y
        while {$W ne "" && $W ne $from} {
            # puts stderr W=$W,x=[winfo x $W],y=[winfo y $W]
            incr x [expr {-1 * [winfo x $W]}]
            incr y [expr {-1 * [winfo y $W]}]
            # if {$W eq $from} break
            set W [winfo parent $W]
        }
    }

    proc luniq list {
        array set found {}
        set res []
        foreach i $list {
            set vn found($i)
            if {[info exists $vn]} continue
            lappend res $i
            set $vn $i
        }
        set res
    }

    # Derived from: http://wiki.tcl.tk/1043
    # (https://wiki.tcl-lang.org/page/info)
    proc getBacktrace {{uplevel 0}} {
        set bt []
        set level [expr {[info level] - 2 - $uplevel}]
        while {$level > 0} {
            set fr [info frame $level]
            lappend bt [list \
                            [dict get $fr cmd]\
                            [dict-default $fr line]\
                            [dict-default $fr proc]]
            incr level -1
        }
        set bt
    }

    proc read_file {fn args} {
        set fh [open $fn]
        scope_guard fh [list close $fh]
        if {$args ne ""} {
            fconfigure $fh {*}$args
        }
        read $fh
    }

    proc scope_guard {varName command} {
        upvar 1 $varName var
        uplevel 1 [list trace add variable $varName unset \
                       [list apply [list args $command]]]
    }

    # From: https://wiki.tcl-lang.org/page/info
    proc getBackTrace backTraceRef {
        upvar 1 $backTraceRef backTrace

        set startLevel [expr {[info level] - 2}]
        for {set level 1} {$level <= $startLevel} {incr level} {
            lappend backTrace [lindex [info level $level] 0]
        }
    }

    namespace export *
}
