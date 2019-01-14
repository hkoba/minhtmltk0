# -*- mode: tcl; coding: utf-8 -*-
namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::common_navigator {} {
    component myBrowser

    variable myHistoryList []

    method setwidget widget {
        install myBrowser using set widget
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
        ::minhtmltk::utils::scope_guard base [list $base destroy]
        $base resolve $uri
    }
}


