#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

namespace eval ::minhtmltk::navigator {
    #
    # Minimal extension -> content-type map for the file: scheme.
    # (http: gets its content-type from the server instead.)
    #
    variable ourContentTypeOf [dict create {*}{
        .html text/html
        .htm  text/html
        .css  text/css
        .txt  text/plain
        .png  image/png
        .gif  image/gif
        .jpg  image/jpeg
        .jpeg image/jpeg
        .svg  image/svg+xml
    }]

    proc guess-content-type path {
        variable ourContentTypeOf
        set ext [string tolower [file extension $path]]
        if {[dict exists $ourContentTypeOf $ext]} {
            dict get $ourContentTypeOf $ext
        }
    }
}

snit::macro ::minhtmltk::navigator::file_scheme {} {

    #
    # [scheme file read] fetches content only and returns a response
    # dict {uri content-type body}; it never touches the browser.
    # Content replacement is composed on top of this in [loadURI]
    # (see common_macro.tcl).
    #
    method {scheme file read} {uriObj args} {
        set mode [from args -mode text]
        set path [$uriObj path]
        set body [if {$mode eq "binary"} {
            ::minhtmltk::utils::read_file $path -translation binary
        } else {
            ::minhtmltk::utils::read_file $path
        }]
        dict create \
            uri [$uriObj get] \
            content-type [::minhtmltk::navigator::guess-content-type $path] \
            body $body
    }

    method {scheme {} read} {uriObj args} {
        $self scheme file read $uriObj {*}$args
    }

    method read_text uri {
        ::minhtmltk::utils::read_file $uri
    }
}
