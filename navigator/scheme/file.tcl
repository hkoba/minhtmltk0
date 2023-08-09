#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

snit::macro ::minhtmltk::navigator::file_scheme {} {

    method {scheme file read_from} {uriObj args} {
        set html [$self read_text [$uriObj path]]
        $myBrowser replace_location_html [$uriObj get] $html {*}$args
    }

    method {scheme {} read_from} {uriObj args} {
        $self scheme file read_from $uriObj {*}$args
    }

    method read_text uri {
        ::minhtmltk::utils::read_file $uri
    }
}
