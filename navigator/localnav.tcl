#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

source [file dirname [info script]]/scheme/file.tcl

snit::type ::minhtmltk::navigator::localnav {

    ::minhtmltk::taghelper::common_navigator

    ::minhtmltk::navigator::file_scheme

    constructor args {
        $self location-init
        $self configurelist $args
    }
    destructor {
        $self location-forget
    }

}
