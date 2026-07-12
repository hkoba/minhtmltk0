#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

source [file dirname [info script]]/common_macro.tcl

source [file dirname [info script]]/scheme/file.tcl

snit::type ::minhtmltk::navigator::localnav {

    #
    # Import common navigator behaviors like [read]/[loadURI].
    # Also location/history related methods are imported.
    #
    # Naming convention:
    # * [read]    = content fetch only. Resolves the URI, dispatches to
    #               [scheme $scheme read] and returns a response dict
    #               {uri content-type body} (http adds status).
    #               No browser side effects.
    # * [load]    = content replacement. This lives on the browser
    #               widget side ([$myBrowser load $uri $html]), which
    #               also updates location/history.
    # * [loadURI] = navigation entrance: [read] + [$myBrowser load].
    #
    ::minhtmltk::navigator::common_macro

    #
    # Import file: scheme handler definitions.
    #
    ::minhtmltk::navigator::file_scheme
    #
    # Above macro defines followings:
    #
    # method {scheme file read} {uriObj args} {
    #     set mode [from args -mode text]
    #     set path [$uriObj path]
    #     set body [... read_file, -translation binary if binary mode ...]
    #     dict create uri [$uriObj get] content-type [...guess...] body $body
    # }
    #
    # method {scheme {} read} {uriObj args} {
    #     $self scheme file read $uriObj {*}$args
    # }
    #
    # See also scheme/http.tcl (http_scheme) and webnav.tcl, which
    # compose file + http/https the same way.

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
