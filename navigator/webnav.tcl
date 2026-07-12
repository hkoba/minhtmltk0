#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

source [file dirname [info script]]/common_macro.tcl

source [file dirname [info script]]/scheme/file.tcl
source [file dirname [info script]]/scheme/http.tcl

#
# webnav = localnav + http/https schemes.
# Opt-in from the widget: [minhtmltk .win -navigator webnav ...]
#
snit::type ::minhtmltk::navigator::webnav {

    ::minhtmltk::navigator::common_macro

    ::minhtmltk::navigator::file_scheme

    ::minhtmltk::navigator::http_scheme

    constructor args {
        $self location-init
        $self configurelist $args
    }
    destructor {
        $self location-forget
    }

}
