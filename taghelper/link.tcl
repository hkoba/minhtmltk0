# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

::minhtmltk::helper::add node link

snit::macro ::minhtmltk::helper::link {} {

    # <link> is handled via node interface
    method {add node link} node {
        if {[set rel [$node attr -default "" rel]] eq ""} return

        # puts "link-rel $rel add $node"
        $self link-rel $rel add $node
    }
}
