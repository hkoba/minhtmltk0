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

    method loadURI {uri {nodeOrAtts {}}} {
        set next [$self resolve $uri]
        set html [$self read_text $next]
        $myBrowser replace_location_html $next $html
    }

    method read_text uri {
        ::minhtmltk::utils::read_file $uri
    }
}
