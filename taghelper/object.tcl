# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

::minhtmltk::taghelper::add node object

#
# Minimal <object> support: if the data attribute points to a loadable
# image, render the object as a replaced element showing that image.
# Otherwise leave the fallback content (which may be a nested <object>)
# in place. This is the behavior the Acid2 eyes rely on.
#
snit::macro ::minhtmltk::taghelper::object {} {

    method {add node object} node {
        set data [$node attr -default "" data]
        if {$data eq ""} return

        if {[$self image load $data] ne ""} {
            $node override [list -tkhtml-replacement-image url($data)]
        }
    }
}
