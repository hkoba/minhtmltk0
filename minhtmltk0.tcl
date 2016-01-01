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

foreach fn [glob [file dirname [info script]]/helper/*.tcl] {
    source $fn
}

snit::widget minhtmltk {

    component myHtml -public document -inherit yes
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

        if {$html ne ""} {
            $self replace_location_html $file $html
        } elseif {$file ne ""} {
            $self replace_location_html $file [$self read_file $file]
        }
    }
    
    #----------------------------------------
    
    variable stateHtmlSource ""
    method parse args {
        append stateHtmlSource [lindex $args end]
        $myHtml parse {*}$args
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
        foreach stVar [info vars ${selfns}::state*] {
            if {[array exists $stVar]} {
                array unset $stVar
            } else {
                set $stVar ""
            }
        }
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

    variable stateTriggerDict -array {}
    method on {event command} {
        set vn stateTriggerDict($event)
        set $vn $command
    }
    method trigger {event args} {
        set vn stateTriggerDict($event)
        if {![info exists $vn]} return
        {*}[set $vn] {*}$args
    }

    #========================================
    # HTML Tag handling
    #========================================

    set handledTags [dict create parse {} script {} node {}]
    
    ::minhtmltk::helper::form   handledTags
    ::minhtmltk::helper::style  handledTags
    ::minhtmltk::helper::anchor handledTags

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

}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
        -fill both -expand yes
}
