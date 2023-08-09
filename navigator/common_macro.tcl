# -*- mode: tcl; coding: utf-8 -*-
namespace eval ::minhtmltk::navigator {}

snit::macro ::minhtmltk::navigator::common_macro {} {
    component myBrowser

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

    method loadURI {uri args} {
        # nextObj lives until end of this method scope.
        $self parse-uri-as nextObj [$self resolve $uri]

        set scheme [$nextObj scheme]
        set method [list scheme $scheme read_from]
        if {[$self info methods $method] eq ""} {
            error "Unsupported URI scheme $scheme: $uri"
        }
        $self {*}$method $nextObj {*}$args
    }

    method parse-uri-as {objVar uri} {
        upvar 1 $objVar uriObj
        set uriObj [tkhtml::uri $uri]
        uplevel 1 \
            [list ::minhtmltk::utils::scope_guard $objVar \
                 [list $uriObj destroy]]
    }

    #----------------------------------------
    variable myHistoryList []
    variable myHistoryPos -1

    method {history push} uri {
        # puts [list old-hist pos $myHistoryPos list $myHistoryList]
        set lastPos [expr {[llength $myHistoryList] - 1}]
        set nextPos [expr {$myHistoryPos + 1}]
        if {$nextPos <= $lastPos} {
            set myHistoryList [lreplace $myHistoryList $nextPos $lastPos\
                                   $uri]
        } else {
            lappend myHistoryList $uri
        }
        set myHistoryPos [expr {[llength $myHistoryList] - 1}]
        # puts [list new-hist pos $myHistoryPos list $myHistoryList]
    }

    method {history bypass} uri {}

    method {history replace} uri {
        error "Not yet impl"
    }

    # XXX: resume explicit external parameters and form state!
    method {history go-offset} {offset} {
        # puts [list old-hist pos $myHistoryPos list $myHistoryList]
        set lastPos [expr {[llength $myHistoryList] - 1}]
        set nextPos [expr {$myHistoryPos + $offset}]
        if {$nextPos >= 0 && $nextPos <= $lastPos} {
            set myHistoryPos $nextPos
            $self loadURI [lindex $myHistoryList $myHistoryPos] \
                -history bypass
            # puts [list new-hist pos $myHistoryPos list $myHistoryList]
        }
    }
}
