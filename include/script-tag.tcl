# -*- mode: tcl; coding: utf-8 -*-

::minhtmltk::helper::add script script

snit::method ::minhtmltk {add script script} {atts body} {

    if {[dict exists $atts type]
        && [dict get $atts type] in {"text/x-tcl" "text/tcl" "tcl"}} {
        set rc [catch {
            set me [if {$options(-script-self) ne ""} {
                set options(-script-self)
            } else {
                set self
            }]
            apply [list {self win atts} $body $selfns] $me $win $atts
        } error]

        if {$rc} {
            $self logger error $error $::errorInfo
        }
    } else {
        $self logger log "Ignored: <script $atts>$body"
    }
}

