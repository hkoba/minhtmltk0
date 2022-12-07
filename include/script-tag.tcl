# -*- mode: tcl; coding: utf-8 -*-

::minhtmltk::taghelper::add script script

snit::method ::minhtmltk {add script script} {atts body} {

    if {$options(-script-type) eq ""
        ||
        [dict exists $atts type]
        && [dict get $atts type] in $options(-script-type)} {
        set rc [catch {
            set me [$self script-self]
            apply [list {self win atts} $body $selfns] $me $win $atts
        } error]

        if {$rc} {
            $self logger error $error $::errorInfo
        }
    } else {
        $self logger log "Ignored: <script $atts>$body"
    }
}

