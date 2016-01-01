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
	
	$self install-mouse-handlers

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
    # mouse handling, salvaged from ::hv3::hv3::mousemanager
    #========================================

    set evlist [list submit \
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
	dict set stateTriggerDict $node $ourEvDict($event) $command
	# puts stateTriggerDict=$stateTriggerDict
    }

    method {node event trigger} {startNode event args} {
	
	foreach {node cmd} [$self node event list-handlers $startNode $event] {

	    # XXX: What kind of API should we have?
	    apply {{cmd node args} {eval $cmd {*}$args}} $cmd $node {*}$args
	}
    }

    option -generate-tag-class-event yes
    method {node event list-handlers} {startNode event} {
	set result {}
	for-upward-node nspec $startNode {
	    set key  [lindex $nspec 0]
	    set node [lindex $nspec end]
	    if {![dict exists $stateTriggerDict $key $event]} {
		continue
	    }
	    set cmd [dict get $stateTriggerDict $key $event]
	    lappend result $node $cmd

	} {*}[tag-class-list-of-node $startNode] ""
	set result
    }

    proc for-upward-node {nvar startNode command args} {
    	upvar 1 $nvar n

	set nodeList ""
    	for {set n $startNode} {$n ne ""} {set n [$n parent]} {
	    lappend nodeList $n
    	}
	foreach n [list {*}$nodeList {*}$args] {
    	    rethrow-control {uplevel 1 $command} yes
	}
    }

    proc tag-class-list-of-node node {
	set list ""
	set node [parent-of-textnode $node]
	if {$node ne "" && [set tag [$node tag]] ne ""} {
	    foreach cls [$node attr -default "" class] {
		lappend list [list $tag.$cls $node]
	    }
	    lappend list [list $tag $node]
	}
	set list
    }

    proc parent-of-textnode node {
	if {[$node tag] eq ""} {
	    $node parent
	} else {
	    set node
	}
    }

    proc rethrow-control {command {no_loop no}} {
	set rc [catch {uplevel 1 $command} result]
	if {$no_loop && $rc in {3 4}} {
	    return $result
	} else {
	    return -code $rc $result
    	}
    }

    method install-mouse-handlers {} {
	bindtags $myHtml [list {*}[bindtags $myHtml] $win]

	# puts win-bindtags=[bindtags $win]
	# puts html-bindtags=[bindtags $myHtml]
	
	bind $win <ButtonPress-1>   +[mymethod Press   %W %x %y]
	bind $win <Motion>          +[mymethod Motion  %W %x %y]
	bind $win <ButtonRelease-1> +[mymethod Release %W %x %y]
	
	$self node event on label click \
	    {puts stderr "clicked! node=$node,args=$args"}
    }
    
    method Press   {w x y} {
	adjust-coords-to $myHtml $w x y
	set nodelist [$myHtml node $x $y]
	puts "Press $w $x $y; nodelist=$nodelist"
    }
    method Motion  {w x y} {
	#puts "Motion $w $x $y"
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

    proc adjust-coords-to {to W xVar yVar} {
	upvar 1 $xVar x
	upvar 1 $yVar y
	while {$W ne "" && $W ne $to} {
	    incr x [winfo x $W]
	    incr y [winfo y $W]
	    set W [winfo parent $W]
	}
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
        -fill both -expand yes
}
