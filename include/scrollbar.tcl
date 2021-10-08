# -*- mode: tcl; coding: utf-8 -*-

snit::method minhtmltk {scrollbar Fit} {} {
    set xDelta [$self scrollbar hiddenWidth]
    set yDelta [$self scrollbar hiddenHeight]
    $self window.resizeBy $xDelta $yDelta
    list $xDelta $yDelta
}

snit::method minhtmltk {scrollbar hiddenWidth} {} {
    set ratio [$self scrollbar horizontalRatio]
    set curWidth [winfo width $myHtml]
    set size [expr {int(($curWidth / $ratio) - $curWidth)}]
    if {$size > 0} {
        return $size
    } else {
        return 0
    }
}

snit::method minhtmltk {scrollbar horizontalRatio} {} {
    lassign [$win.sw.hscroll get] left right
    set ratio [expr {$right - $left}]
}

snit::method minhtmltk document.body.scrollWidth {} {
    set ratio [$self scrollbar horizontalRatio]
    expr {[winfo width $myHtml] / $ratio}
}

snit::method minhtmltk {scrollbar hiddenHeight} {} {
    set ratio [$self scrollbar verticalRatio]
    set curWidth [winfo width $myHtml]
    set size [expr {int(($curWidth / $ratio) - $curWidth)}]
    if {$size > 0} {
        return $size
    } else {
        return 0
    }
}

snit::method minhtmltk {scrollbar verticalRatio} {} {
    lassign [$win.sw.vscroll get] begin end
    set ratio [expr {$end - $begin}]
}

