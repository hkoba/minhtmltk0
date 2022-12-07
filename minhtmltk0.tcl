#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec wish -encoding utf-8 "$0" ${1+"$@"}

package require Tkhtml 3
package require snit
package require widget::scrolledwindow
#package require BWidget

source [file dirname [info script]]/utils.tcl

namespace eval ::minhtmltk {
    namespace import ::minhtmltk::utils::*
}

source [file dirname [info script]]/formstate1.tcl

source [file dirname [info script]]/taghelper.tcl

source [file dirname [info script]]/navigator/localnav.tcl

snit::widget minhtmltk {
    ::minhtmltk::taghelper::start

    typevariable ourClass Minhtmltk

    component myHtml -inherit yes
    variable stateStyleList

    option -encoding ""

    # Used from include/script-tag.tcl, to expose custom $self to tcl <script>
    option -script-self ""
    option -script-type [list text/x-tcl text/tcl tcl]

    # $self for script/event handlers
    method script-self {} {
        if {$options(-script-self) ne ""} {
            set options(-script-self)
        } else {
            set self
        }
    }

    component myURINavigator -public nav
    delegate option -uri to myURINavigator as -uri
    delegate option -file to myURINavigator as -uri
    delegate option -home to myURINavigator
    delegate method location to myURINavigator

    option -html ""

    option -encoding ""

    variable myLogHistory [list]
    variable stateCurrentLog [list]

    typeconstructor {
        if {[ttk::style theme use] eq "default"} {
            ttk::style theme use clam
        }
        foreach t {TCheckbutton TRadiobutton TButton} {
            ::ttk::style configure $t \
                -background white -activebackground white
        }

        bind $ourClass <<DocumentReady>> {%W trigger ready}
    }

    #========================================
    constructor args {

        if {[set nav [from args -navigator ""]] ne ""} {
            install myURINavigator using set nav
        } else {
            install myURINavigator \
                using ::minhtmltk::navigator::localnav ${selfns}::navigator
            # puts "navigator is created!>>>"
            # trace add command $myURINavigator delete \
            #     [list apply {args {
            #         getBackTrace bt
            #         puts "navigator is deleted!<<<\nbacktrace=$bt"
            #     }}]
        }
        $myURINavigator setwidget $win

        set sw [widget::scrolledwindow $win.sw \
                   -scrollbar [from args -scrollbar both]]
        install myHtml using html $sw.html
        $sw setwidget $myHtml

        $self configurelist $args
        # $self interactive; # ← called from Reset (from replace_location_html)

        if {[$self location get] eq ""} {
            $self nav gotoHome
        }

        pack $sw -fill both -expand yes
    }

    destructor {
        safe_destroy $myURINavigator
    }
    proc safe_destroy obj {
        if {$obj ne "" && [info commands $obj] ne ""} {
            rename $obj ""
        }
    }

    onconfigure -html html {
        $self replace_location_html "" $html
    }

    method interactive {} {

        $self install-html-handlers
        
        bindtags $myHtml [luniq [linsert-lsearch [bindtags $myHtml] . \
                                     $win $ourClass]]

        $self install-mouse-handlers

        $self install-keyboard-handlers
    }
    
    method html args {
        if {$args eq ""} {
            set myHtml
        } else {
            $myHtml {*}$args
        }
    }

    #----------------------------------------
    
    option -emit-ready-immediately no

    variable stateHtmlSource ""
    variable stateDocumentReady ""
    method parse args {
        append stateHtmlSource [lindex $args end]
        $myHtml parse {*}$args
        if {[lindex $args 0] eq "-final"} {
            set stateDocumentReady yes
            set cmd [list event generate $win <<DocumentReady>>]
            # This cmd will call [$self node event trigger "" ready]
            if {$options(-emit-ready-immediately)} {
                {*}$cmd
            } else {
                after idle $cmd
            }
        }
    }

    method {state is DocumentReady} {} {
        expr {$stateDocumentReady ne ""}
    }

    method {state source} {} {
        set stateHtmlSource
    }

    method replace_location_html {uri html {opts {}}} {
        $self Reset
        $myURINavigator location load $uri
        $self parse -final $html
        $myURINavigator history [dict-default $opts history push]\
            $uri
    }

    method Reset {} {
        $myHtml reset
        foreach form [list {*}$stateFormList $stateOuterForm] {
            if {$form eq ""} continue
            $form destroy
        }
	# XXX: commands <= for tQuery
        foreach stVar [info vars ${selfns}::state*] {
            if {[array exists $stVar]} {
                array unset $stVar
            } else {
                set $stVar ""
            }
        }

        # Reinstall default tag/event handlers
        $self interactive
    }
    
    method read_file {fn args} {
        set fh [open $fn]
        if {$args ne ""} {
            fconfigure $fh {*}$args
        }
        set data [read $fh]
        close $fh
        set data
    }
    
    #========================================
    # HTML Tag handling
    #========================================

    ::minhtmltk::taghelper errorlogger

    ::minhtmltk::taghelper form
    ::minhtmltk::taghelper style
    ::minhtmltk::taghelper anchor
    ::minhtmltk::taghelper link

    # To be handled
    list {
        button
        iframe menu
        base meta title object embed
    }

    method install-html-handlers {} {
        foreach {kind tag handler} [::minhtmltk::taghelper::handledTags] {
            if {$handler ne ""} {
                set meth [list add $handler]
            } else {
                set meth [list add $kind $tag]
            }
            if {![llength [$self info methods $meth]]} {
                error "Can't find tag handler for $tag"
            }
            set cmd [list handler $kind $tag [list $self logged {*}$meth]]
            # puts $cmd
            $myHtml {*}$cmd
        }
    }

    #========================================
    # mouse event handling
    #========================================

    ::minhtmltk::taghelper mouseevent0
    
    #========================================
    # keyboard event handling
    #========================================

    method install-keyboard-handlers {} {
	focus $win

        bind $win <KeyPress-Up>     [list $myHtml yview scroll -1 units]
        bind $win <KeyPress-Down>   [list $myHtml yview scroll  1 units]
        bind $win <KeyPress-Return> [list $myHtml yview scroll  1 units]
        bind $win <KeyPress-Right>  [list $myHtml xview scroll  1 units]
        bind $win <KeyPress-Left>   [list $myHtml xview scroll -1 units]
        bind $win <KeyPress-Next>   [list $myHtml yview scroll  1 pages]
        bind $win <KeyPress-space>  [list $myHtml yview scroll  1 pages]
        bind $win <KeyPress-Prior>  [list $myHtml yview scroll -1 pages]

        bind $win <Alt-Right> [list $myURINavigator history go-offset +1]
        bind $win <Alt-Left> [list $myURINavigator history go-offset -1]
    }

    #========================================
    # Misc.
    #========================================

    method See {node_or_selector {now no}} {
        set node [if {[regexp ^::tkhtml::node $node_or_selector]} {
            set node_or_selector
        } else {
            lindex [$self search $node_or_selector] 0
        }]
        # puts Seeing-$node_or_selector->$node
        if {$node eq ""} return
        
	$self yview $node
	# XXX: 
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
        -fill both -expand yes

    foreach inc [glob [file dirname [info script]]/include/*.tcl] {
        source $inc
    }

    snit::method minhtmltk Open {file args} {
        $self configure {*}$args
        $self replace_location_html $file \
            [$self read_file $file]
    }

    if {$::argv ne ""} {
        puts [.win {*}$::argv]
    }
}

list ::minhtmltk

