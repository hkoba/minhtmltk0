# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

snit::macro ::minhtmltk::taghelper::errorlogger {} {
    #========================================
    # logging... hmm...
    variable stateParseErrors ""
    option -debug 0
    option -debug-fh stderr
    option -logger-exclude {}
    method logged args {
        set rc [catch {
            $self {*}$args
        } error]
        if {$rc} {
            $self logger error $error args $args errorInfo $::errorInfo]
        }
    }
    method {error count} {} {
        llength [$self error get]
    }
    method {error get} {} {
        lmap i $stateParseErrors {
            lassign $i kind message detailDict
            if {$kind ne "error"} continue
            list $message $detailDict
        }
    }
    method {error add} message {
        $self logger add error $message
    }
    method {logger get} {} {
        set stateParseErrors
    }
    method {logger error} {message args} {
        $self logger add error $message {*}$args
    }
    method {logger log} {message args} {
        $self logger add log $message {*}$args
    }
    method {logger add} {kind message args} {
        lappend stateParseErrors [list $kind $message $args]
        if {! $options(-debug)} return
        if {[dict exists $options(-logger-exclude) $kind]} return
        if {$options(-debug-fh) ne ""} {
            puts $options(-debug-fh) "$kind $message"
            puts $options(-debug-fh) $args
        }
    }
}
