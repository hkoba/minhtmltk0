# -*- mode: tcl; coding: utf-8 -*-

snit::method minhtmltk {scrollbar Fit} {} {
    set xDelta [$self scrollbar hiddenWidth]
    set yDelta [$self scrollbar hiddenHeight]
    $self window.resizeBy $xDelta $yDelta
    # $self scrollbar update
    list $xDelta $yDelta
}

snit::method minhtmltk {scrollbar update} {} {
    foreach axis {x y} {
        if {[set w [$self scroll bar $axis]] eq ""} continue
        $self scroll set $axis {*}[{*}[$w cget -command]]
    }
}

snit::method minhtmltk {scrollbar hiddenWidth} {} {
    set ratio [$self scrollbar horizontalRatio]
    set curWidth [winfo width $myHtml]
    expr {max(0, int(($curWidth / $ratio) - $curWidth))}
}

snit::method minhtmltk {scrollbar horizontalRatio} {} {
    lassign [$myHtml xview] left right
    set ratio [expr {$right - $left}]
}

snit::method minhtmltk document.body.scrollWidth {} {
    set ratio [$self scrollbar horizontalRatio]
    expr {[winfo width $myHtml] / $ratio}
}

snit::method minhtmltk {scrollbar verticalPadding} {} {
    expr {[winfo height $win] - [winfo height $myHtml]}
}

snit::method minhtmltk {scrollbar hiddenHeight} {} {
    set ratio [$self scrollbar verticalRatio]
    set curHeight [winfo height $myHtml]
    expr {max(0, int($curHeight * (1 -  $ratio)))}
}

snit::method minhtmltk {scrollbar verticalRatio} {} {
    lassign [$myHtml yview] begin end
    set ratio [expr {$end - $begin}]
}

