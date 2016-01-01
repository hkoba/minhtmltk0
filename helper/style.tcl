# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::style {handledTagDictVar} {

    upvar 1 $handledTagDictVar handledTagDict
    dict lappend handledTagDict script style

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
