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
    # mouse handling, salvaged and extended from ::hv3::hv3::mousemanager
    #========================================

    set evlist [list \
		    ready \
		    submit \
		    mouseover mousemove mouseout click \
		    dblclick mousedown mouseup]
    typevariable ourMouseEventList $evlist
    typevariable ourEvDict -array [set ls {}; foreach i $evlist {
	lappend ls $i $i
    }; set ls]

    variable stateTriggerDict [dict create]
    # Global event
    method on {event command} {
	$self node event on "" $event $command
    }
    method trigger {event args} {
	$self node event trigger "" $event {*}$args
    }

    # Node event. 
    method {node event on} {node event command} {
	if {[dict exists $stateTriggerDict $node $ourEvDict($event)]} {
	    $self error add "Replacing handler for $event with $command"
	}
	dict set stateTriggerDict $node $ourEvDict($event) $command
	# puts stateTriggerDict=$stateTriggerDict
    }

    method {node event trigger} {startNode event args} {

	set handlers [$self node event list-handlers $startNode $event]

	foreach {node cmd} $handlers {

	    # XXX: What kind of API should we have?
	    apply [list {self win selfns node args} $cmd] \
		$self $win $selfns $node {*}$args
	}
    }
    
    method {node event dump-handlers} {} {
	set stateTriggerDict
    }

    #
    # This defines event triggering order.
    #
    option -generate-tag-class-event yes
    method {node event list-handlers} {startNode event} {
	set result {}
	set altList [if {$startNode ne ""
			 && $options(-generate-tag-class-event)} {
	    tag-class-list-of-node $startNode
	}]
	
	# 1. Bubble up order
	# 2. (tag.class / tag) handlers
	# 3. global handler (node = "")

	for-upward-node nspec $startNode {
	    # In simple case, nspec = key = node
	    # In tag-class-list, nspec = [list tag_class node]
	    set key  [lindex $nspec 0]
	    set node [lindex $nspec end]

	    if {![dict-getvar $stateTriggerDict $key $event cmd]} continue

	    lappend result $node $cmd

	} {*}$altList [list "" [$myHtml node]]

	set result
    }

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

    method install-mouse-handlers {} {
	bindtags $myHtml [linsert-lsearch [bindtags $myHtml] . \
			      $win $ourClass]

	bind $win <ButtonPress-1>   +[mymethod Press   %W %x %y]
	bind $win <Motion>          +[mymethod Motion  %W %x %y]
	bind $win <ButtonRelease-1> +[mymethod Release %W %x %y]
	
	$self node event on a click {
	    
	    if {[set href [$node attr -default "" href]] eq ""} return
	    
	    if {[regexp ^\# $href]} {
		$self See $href
	    } else {
		puts stderr "Not yet implemented: href=$href"
	    }
	}

	$self node event on label click {

	    set inputs [if {[set id [$node attr -default "" for]] ne ""} {
		# <label for="id">

		$self search #$id

	    } else {
		# <label> <input type=checkbox>

		$self search {
		    input[type=checkbox], input[type=radio]
		} -root $node
	    }]

	    foreach n $inputs {
		[$n replace] invoke
	    }
	}
    }
    
    method Press   {w x y} {
	# puts stderr "Press $w $x $y"
	adjust-coords-to $myHtml $w x y
	set nodelist [$myHtml node $x $y]
	# puts stderr "adjusted to $x $y nodelist=$nodelist"
    }
    method Motion  {w x y} {
	# puts stderr "Motion $w $x $y"
	adjust-coords-to $myHtml $w x y
	set nodelist [$myHtml node $x $y]
	# puts stderr "Motion adjusted to $x $y nodelist=$nodelist"
	# apply [list {myHtml w x y} {
	#     adjust-coords-from $myHtml $w x y
	#     puts stderr " reverse adjust => $x $y"
	# } ::minhtmltk] $myHtml $w $x $y
    }
    method Release {w x y} {
	adjust-coords-to $myHtml $w x y

	set nodelist [$myHtml node $x $y]
	set evlist {}
	foreach node $nodelist {
	    lappend evlist click $node
	}
	
	$self event generatelist $evlist
    }
    method {event generatelist} evlist {
	foreach {event node} $evlist {
	    $self node event trigger $node $event
	}
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
        -fill both -expand yes
}

list ::minhtmltk

