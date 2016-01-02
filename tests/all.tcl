#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec tclsh -encoding utf-8 "$0" ${1+"$@"}

# mostly borrowed from tk's tests/all.tcl

package require Tcl 8.5
package require tcltest 2.2
package require Tk ;# This is the Tk test suite; fail early if no Tk!
tcltest::configure {*}$argv
tcltest::configure -testdir [file normalize [file dirname [info script]]]
tcltest::configure -loadfile \
    [file join [tcltest::testsDirectory] constraints.tcl]
tcltest::configure -singleproc 1
tcltest::runAllTests
