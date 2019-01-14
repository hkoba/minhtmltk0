# -*- mode: tcl; coding: utf-8 -*-
namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::common_navigator {} {
    component myBrowser

    variable myHistoryList []

    component myLocation -public location

    option -uri ""
    option -home ""

    method location-init {} {
        install myLocation using tkhtml::uri ""
    }
    method location-forget {} {
        if {$myLocation ne ""} {
            $myLocation destroy
            set myLocation ""
        }
    }

    onconfigure -uri file {
        $self loadURI $file
    }

    method gotoHome {} {
        if {$options(-home) ne ""} {
            $self loadURI $options(-home)
        }
    }

    method setwidget widget {
        install myBrowser using set widget
    }

    method resolve {uri {baseURI ""}} {
        if {$baseURI eq ""} {
            set baseURI [$myLocation get]
        }
        if {$baseURI eq ""} {
            set baseURI [pwd]/
        }
        # puts stderr "baseURI = $baseURI"
        set base [tkhtml::uri $baseURI]
        ::minhtmltk::utils::scope_guard base [list $base destroy]
        $base resolve $uri
    }
}


