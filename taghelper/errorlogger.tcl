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
            $self logger error $error $::errorInfo
        }
    }
    method {error get} {} {$self logger get}
    method {logger get} {} {
        set stateParseErrors
    }
    method {logger error} {message {detail ""}} {
        $self logger add error $message $detail
    }
    method {logger log} {message {detail ""}} {
        $self logger add log $message $detail
    }
    method {logger add} {kind message {detail ""}} {
        lappend stateParseErrors [list $kind $message $detail]
        if {! $options(-debug)} return
        if {[dict exists $options(-logger-exclude) $kind]} return
        if {$options(-debug-fh) ne ""} {
            puts $options(-debug-fh) "$kind $message"
            puts $options(-debug-fh) $detail
        }
    }
}
