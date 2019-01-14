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
        if {[set curURI [$myBrowser location]] eq ""} {
            set curURI [pwd]
        }
        set base [tkhtml::uri $curURI]
        scope_guard base [list $base destroy]
        set next [$base resolve $uri]
        set html [read_file $next]
        $myBrowser replace_location_html $next $html
    }

}
