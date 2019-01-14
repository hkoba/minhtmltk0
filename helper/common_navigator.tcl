# -*- mode: tcl; coding: utf-8 -*-
namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::common_navigator {} {
    component myBrowser

    variable myHistoryList []

    option -uri ""
    option -home ""

    component myLocation -public location
    # *         $uri resolve URI
    # *         $uri load URI
    # *
    # *         $uri scheme
    # *         $uri authority
    # *         $uri path
    # *         $uri query
    # *         $uri fragment
    # *
    # *         $uri destroy

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

    method loadURI {uri {nodeOrAtts {}}} {
        # nextObj lives until end of this method scope.
        $self parse-uri-as nextObj [$self resolve $uri]

        $self scheme [$nextObj scheme] read_from $nextObj
    }

    method parse-uri-as {objVar uri} {
        upvar 1 $objVar uriObj
        set uriObj [tkhtml::uri $uri]
        uplevel 1 \
            [list ::minhtmltk::utils::scope_guard $objVar \
                 [list $uriObj destroy]]
    }
}


