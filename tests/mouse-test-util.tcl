
proc + {a b} {expr {$a + $b}}
proc avg {a b} {expr {($a + $b)/2}}
proc center bbox {
    lassign $bbox x1 y1 x2 y2
    list [avg $x1 $x2] [avg $y1 $y2]
}

proc nodeCenter {node {adjust yes}} {
    # puts stderr invoking=$node,tag=[$node tag]
    lassign [center [.ht bbox $node]] cx cy
    if {$adjust} {
        minhtmltk::utils::adjust-coords-from [.ht html] .ht cx cy
    }
    list $cx $cy
}

proc invokeHandlerFor {meth pos} {
    .ht $meth .ht {*}$pos
}

proc invokeClick node {
    set pos [nodeCenter $node]
    invokeHandlerFor Press   $pos
    invokeHandlerFor Release $pos
}
