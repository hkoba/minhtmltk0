# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

::minhtmltk::helper::add script style

snit::macro ::minhtmltk::helper::style {} {

    #
    # <script>
    #
    method {add script style} {atts data} {
        # media, type
        regsub {^\s*<!--} $data {} data
        regsub -- {-->\s*$} $data {} data
        lappend stateStyleList $data
        set id author.[format %.4d [llength $stateStyleList]]
        $myHtml style -id $id \
            [string map [list \r ""] $data]
    }
}
