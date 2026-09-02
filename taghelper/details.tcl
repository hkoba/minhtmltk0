# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

snit::macro ::minhtmltk::taghelper::details {} {

    # <details>/<summary>: clicking the summary toggles the "open"
    # attribute of its <details>. All state and styling live in the
    # Tkhtml engine (html.css rules keyed on details[open]); this
    # handler only wires the click, the same division of labor as
    # :hover. Requires Tkhtml with ::tkhtml::details_toggle.
    method {node event tag summary click} node {
        ::tkhtml::details_toggle $node
    }
}
