# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::errorlogger {} {
    #========================================
    # logging... hmm...
    variable stateParseErrors ""
    option -debug no
    method logged args {
        set rc [catch {
            $self {*}$args
        } error]
        if {$rc} {
            $self error add [list error $error $::errorInfo]
        }
    }
    method {error get} {} {
        set stateParseErrors
    }
    method {error add} error {
        lappend stateParseErrors $error
        if {$options(-debug)} {
            lassign $error kind summary trace
            puts stderr "$kind $summary"
            puts stderr $trace
        }
    }
    method {error raise} error {
        lappend stateParseErrors $error
        error $error
    }
}
