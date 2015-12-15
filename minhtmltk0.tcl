#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec wish -encoding utf-8 "$0" ${1+"$@"}

package require Tkhtml 3
package require snit
package require widget::scrolledwindow

snit::widget minhtmltk {
    component myHtml -public document -inherit yes
    variable myStyleList
    
    option -encoding ""

    typeconstructor {
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
    
    variable myLocation ""
    method replace_location_html {uri html} {
	$self Reset
	set myLocation $uri
	$myHtml parse -final $html
    }

    method Reset {} {
	$myHtml reset
	set myStyleList ""
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

    option -handle-parse ; #[list form]
    option -handle-script [list style]
    option -handle-node [list textarea]
    list {
	a link
	textarea select button
	iframe menu
	base meta title object embed
    }

    method install-html-handlers {} {
	
	$myHtml handler node input [list $self add by-input-type]

	foreach kind {parse script node} {
	    foreach tag $options(-handle-$kind) {
		set meth [list add $kind $tag]
		if {![llength [$self info methods $meth]]} {
		    error "Can't find tag handler for $tag"
		}
		$myHtml handler $kind $tag [list $self {*}$meth]
	    }
	}
    }

    method {with path-of} {node command} {
	upvar 1 path path
	set path [$self node path $node]
	uplevel 1 $command
	$node replace $path -deletecmd [list destroy $path]
    }

    method {node path} node {
	if {[set id [$node attr -default "" id]] eq ""} {
	    set id [string map {: _} $node]
	}
	return $myHtml._$id
    }

    #========================================

    method {add script style} {atts data} {
	# media, type
	regsub {^\s*<!--} $data {} data
	regsub -- {-->\s*$} $data {} data
	lappend myStyleList $data
	set id author.[format %.4d [llength $myStyleList]]
	$myHtml style -id $id \
	    [string map [list \r ""] $data]
    }

    method {add node textarea} node {
	$self with path-of $node {
	    widget::scrolledwindow $path
	    set t [text $path.text -width [$node attr -default 60 cols]\
		       -height [$node attr -default 10 rows]]
	    $path setwidget $t
	    set contents {}
	    foreach kid [$node children] {
		append contents [$kid text -pre]
	    }
	    $t insert end $contents
	}
    }

    method {add by-input-type} node {
	$self with path-of $node {
	    $self add input [$node attr -default text] \
		$path $node
	}
    }

    method {add input text} {path node args} {
	::ttk::entry $path \
	    -width [$node attr -default 20 size] {*}$args
	$path delete 0 end
	$path insert end [$node attr -default "" value]
    }

    method {add input button} {path node args} {
	set text [$node attr -default [from args -text] value]
	ttk::button $path -takefocus 1 -text $text {*}$args
    }

    method {add input checkbox} {path node args} {
	ttk::checkbutton $path
    }

    method {add input radio} {path node args} {
	ttk::radiobutton $path
    }

    proc parsePosixOpts {varName {dict {}}} {
	upvar 1 $varName opts

	for {} {[llength $opts]
		&& [regexp {^--?([\w\-]+)(?:(=)(.*))?} [lindex $opts 0] \
			-> name eq value]} {set opts [lrange $opts 1 end]} {
	    if {$eq eq ""} {
		set value 1
	    }
	    dict set dict -$name $value
	}
	set dict
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
	-fill both -expand yes
}
