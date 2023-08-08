namespace eval ::minhtmltk {}

proc ::minhtmltk::qs2dict {queryString args} {
    set query [dict create]
    foreach {name value} [qs2list $queryString {*}$args] {
        if {[dict exists $query $name]} {
            dict lappend query $name $value
        } else {
            dict set query $name $value
        }
    }
    set query
}

proc ::minhtmltk::qs2list {queryString args} {
    array set opts $args
    set query []
    # Stolen from ncgi::nvlist with some modification
    foreach x [split $queryString "&;"] {
        set pos [string first = $x]
        if {$pos <= 0} {
            if {[set cmd [default opts(error-command) ""]] ne ""} {
                {*}$cmd "parameter without '=': $x"
            }
            continue
        }
        set name [url-decode [string range $x 0 [expr {$pos-1}]]]
        set value [url-decode [string range $x [expr {$pos+1}] end]]
        lappend query $name $value
    }
    set query
}

proc ::minhtmltk::url-decode str {
    # Stolen from https://wiki.tcl-lang.org/page/url-encoding

    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str

    # process \u unicode mapped chars
    return [subst -novar -nocommand $str]
}
