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

source [file dirname [info script]]/helper.tcl

snit::widget minhtmltk {
    ::minhtmltk::helper::start

    typevariable ourClass Minhtmltk

    component myHtml -inherit yes
    variable stateStyleList
    
    option -encoding ""

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
        set sw [widget::scrolledwindow $win.sw \
                   -scrollbar [from args -scrollbar both]]
        install myHtml using html $sw.html
        $sw setwidget $myHtml

        $self interactive {*}$args

        pack $sw -fill both -expand yes
    }
    
    method interactive args {
        set html [from args -html ""]
        set file [from args -file ""]
        
        $self configurelist $args
        
        $self install-html-handlers
        
        $self install-mouse-handlers

        if {$html ne ""} {
            $self replace_location_html $file $html
        } elseif {$file ne ""} {
            $self replace_location_html $file [$self read_file $file]
        }
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
    method parse args {
        append stateHtmlSource [lindex $args end]
        $myHtml parse {*}$args
        if {[lindex $args 0] eq "-final"} {
            set cmd [list event generate $win <<DocumentReady>>]
            # This cmd will call [$self node event trigger "" ready]
            if {$options(-emit-ready-immediately)} {
                {*}$cmd
            } else {
                after idle $cmd
            }
        }
    }

    method {state source} {} {
        set stateHtmlSource
    }

    variable stateLocation ""
    method replace_location_html {uri html} {
        $self Reset
        set stateLocation $uri
        $self parse -final $html
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

    ::minhtmltk::helper errorlogger

    set handledTags [dict create parse {} script {} node {}]
    
    ::minhtmltk::helper form   handledTags
    ::minhtmltk::helper style  handledTags
    ::minhtmltk::helper anchor handledTags

    foreach kind [dict keys $handledTags] {
        option -handle-$kind [dict get $handledTags $kind]
    }

    # To be handled
    list {
        link
        button
        iframe menu
        base meta title object embed
    }

    method install-html-handlers {} {
        
        foreach kind {parse script node} {
            foreach spec $options(-handle-$kind) {
                lassign $spec tag handler
                if {$handler ne ""} {
                    set meth [list add $handler]
                } else {
                    set meth [list add $kind $tag]
                }
                if {![llength [$self info methods $meth]]} {
                    error "Can't find tag handler for $tag"
                }
                $myHtml handler $kind $tag [list $self logged {*}$meth]
            }
        }
    }

    #========================================
    # mouse event handling
    #========================================

    ::minhtmltk::helper mouseevent0
    
    #========================================
    # Misc.
    #========================================

    method See node_or_selector {
        set node [if {[regexp ^::tkhtml::node $node_or_selector]} {
            set node_or_selector
        } else {
            lindex [$self search $node_or_selector] 0
        }]
        # puts Seeing-$node_or_selector->$node
        if {$node eq ""} return
        
        $self yview $node
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
        -fill both -expand yes
}

list ::minhtmltk

