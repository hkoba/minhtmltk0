#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

source [file dirname [info script]]/common_macro.tcl

source [file dirname [info script]]/scheme/file.tcl

snit::type ::minhtmltk::navigator::localnav {

    #
    # Import common navigator behaviors like (loadUI -> scheme) dispatching.
    # Also location/history related methods are imported.
    #
    ::minhtmltk::navigator::common_macro

    #
    # Import file: scheme handler definitions.
    #
    ::minhtmltk::navigator::file_scheme
    #
    # Above macro defines followings:
    #
    # method {scheme file read_from} {uriObj opts} {
    #     set html [$self read_text [$uriObj path]]
    #     $myBrowser replace_location_html [$uriObj get] $html $opts
    # }
    #
    # method {scheme {} read_from} {uriObj opts} {
    #     $self scheme file read_from $uriObj $opts
    # }
    #
    # method read_text uri {
    #     ::minhtmltk::utils::read_file $uri
    # }

    constructor args {
        #
        # This will initialize myLocation component with [tkhtml::uri ""]
        #
        $self location-init

        $self configurelist $args
    }
    destructor {
        #
        # This will free $myLocation object
        #
        $self location-forget
    }
}
