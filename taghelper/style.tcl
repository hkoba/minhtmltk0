# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

::minhtmltk::helper::add script style

snit::macro ::minhtmltk::helper::style {} {

    # <link rel=stylesheet>
    method {link-rel stylesheet add} node {
        if {[set href [$node attr -default "" href]] eq ""} return

        $self style import-from author [$self location get] $href
    }

    #
    # <style> is handled via script interface
    #
    method {add script style} {atts data} {
        # media, type
        regsub {^\s*<!--} $data {} data
        regsub -- {-->\s*$} $data {} data

        if {[set src [from atts src ""]] ne ""} {
            $self style import-from author [$self location get] $src
        }
        $self style add-from [$self location get] $data
    }

    method {style add-from} {uri style {parentid author}} {
        set id $parentid.[format %.4d [llength $stateStyleList]]
        lappend stateStyleList $style
        $myHtml style -id $id \
            -importcmd [list $self style import-from $id $uri] \
            [string map [list \r ""] $style]
    }

    # @import
    method {style import-from} {parentid baseURI uri} {
        if {[catch {
            set actualURI [$self nav resolve $uri $baseURI]
        } error]} {
            puts stderr "Can't resolve import uri: $uri baseURI=$baseURI, $error"
        }

        $self style add-from $actualURI \
            [$self nav read_text $actualURI]
    }
}
