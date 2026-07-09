# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

::minhtmltk::taghelper::add node link

snit::macro ::minhtmltk::taghelper::link {} {

    # <link> is handled via node interface
    method {add node link} node {
        if {[set rel [$node attr -default "" rel]] eq ""} return

        # rel is a space separated list of words: "stylesheet",
        # "appendix stylesheet", "alternate stylesheet" etc. Alternate
        # stylesheets (with a title) are not applied by default.
        set words [string tolower $rel]
        if {"stylesheet" in $words} {
            if {"alternate" in $words
                && [$node attr -default "" title] ne ""} return
            $self link-rel stylesheet add $node
            return
        }

        # puts "link-rel $rel add $node"
        $self link-rel $rel add $node
    }
}
