#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

snit::type ::minhtmltk::navigator::localnav {

    ::minhtmltk::helper::common_navigator

    constructor args {
        $self location-init
        $self configurelist $args
    }
    destructor {
        $self location-forget
    }

    method {scheme {} read_from} uriObj {
        $self scheme file read_from $uriObj
    }

    method {scheme file read_from} uriObj {
        set html [$self read_text [$uriObj get]]
        $myBrowser replace_location_html [$uriObj get] $html
    }

    method read_text uri {
        ::minhtmltk::utils::read_file $uri
    }
}
