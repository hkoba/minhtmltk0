#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

namespace eval ::minhtmltk::navigator::localnav {
    namespace import ::minhtmltk::utils::*
}

snit::type ::minhtmltk::navigator::localnav {

    component myBrowser

    variable myHistoryList []

    method setwidget widget {
        install myBrowser using set widget
    }

    method loadURI {uri {nodeOrAtts {}}} {
        set next [$self resolve $uri]
        set html [$self read_text $next]
        $myBrowser replace_location_html $next $html
    }

    method resolve {uri {baseURI ""}} {
        if {$baseURI eq ""} {
            set baseURI [$myBrowser location]
        }
        if {$baseURI  eq ""} {
            set baseURI [pwd]/
        }
        # puts stderr "baseURI = $baseURI"
        set base [tkhtml::uri $baseURI]
        scope_guard base [list $base destroy]
        $base resolve $uri
    }

    method read_text uri {
        read_file $uri
    }
}
