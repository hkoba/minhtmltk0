# -*- mode: tcl; coding: utf-8 -*-

snit::method minhtmltk window.resizeBy {xDelta yDelta} {
    lassign [split [wm geometry [winfo toplevel $win]] x+] \
        width height globalX globalY

    wm geometry [winfo toplevel $win] \
        [expr {$width + $xDelta}]x[expr {$height + $yDelta}]+$globalX+$globalY
}
