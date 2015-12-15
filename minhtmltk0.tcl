#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec wish -encoding utf-8 "$0" ${1+"$@"}

package require Tkhtml 3
package require snit
package require widget::scrolledwindow

namespace eval ::minhtmltk {
    proc dict-cut {dictVar key args} {
	upvar 1 $dictVar dict
	if {[dict exists $dict $key]} {
	    set res [dict get $dict $key]
	    dict unset dict $key
	    set res
	} elseif {[llength $args]} {
	    lindex $args 0
	} else {
	    error "No such key: $key"
	}
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
    
    namespace export *
}

source [file dirname [info script]]/formstate.tcl

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

    variable myParseErrors ""
    #========================================
    method raise error {
	lappend myParseErrors [list $error]
	error $error
    }

    #========================================
    variable myFormList {}
    variable myFormDict -array {}
    variable myOuterForm ""

    method {form list} {} {
	set myFormList
    }

    method {form names} {args} {
	array names myFormDict {*}$args
    }

    method {form get} {ix {fallback yes}} {
	if {[string is integer $ix]} {
	    if {$ix == 0 && ![llength $myFormList]} {
		if {!$fallback} {
		    error "No form tag!"
		}
		set myOuterForm
	    } else {
		lindex $myFormList $ix
	    }
	} elseif {[regexp ^@(.*) $ix -> name]} {
	    set myFormDict($name)
	} else {
	    error "Invalid form index: $ix"
	}
    }

    method {form of-node} {node} {
	set name [$node attr -default "" name]
	set vn myFormDict($name)
	if {[info exists $vn]} {
	    error [list form name=$name appeared twice!]
	}

	set form [$self form new $name -action [$node attr -default "" action] \
		     -node $node]
	lappend myFormList $form
	set $vn $form
    }
    
    method {with form} command {
	upvar 1 form form
	set form [$self form current]
	uplevel 1 $command
    }
    
    method {form current} {} {
	if {[llength $myFormList]} {
	    lindex $myFormList end
	} elseif {$myOuterForm ne ""} {
	    set myOuterForm
	} else {
	    set myOuterForm [$self form new ""]
	}
    }

    method {form new} {name args} {
	formstate $self.form%AUTO% -name $name {*}$args
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
	$self with form {
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
    }

    method {add by-input-type} node {
	$self with form {
	    $self with path-of $node {
		$self add input [$node attr -default text] \
		    $path $node $form
	    }
	}
    }

    proc node-atts-assign {node args} {
	set _atts {}
	foreach _key $args {
	    upvar 1 $_key _upvar
	    set value [$node attr -default "" $_key]
	    lappend _atts $_key $value
	    set _upvar $value
	}
	set _atts
    }

    method {add input text} {path node form args} {
	set item [$form item register node single $node \
		      [node-atts-assign $node name value]]
	set var [$form item var $item]
	set $var $value
	::ttk::entry $path \
	    -textvariable $var \
	    -width [$node attr -default 20 size] {*}$args
    }

    method {add input password} {path node form args} {
	$self add input text $path $node $form -show * {*}$args
    }

    method {add input button} {path node form args} {
	set text [$node attr -default [from args -text] value]
	ttk::button $path -takefocus 1 -text $text {*}$args
    }

    method {add input checkbox} {path node form args} {
	set item [$form item register node multi $node \
		      [node-atts-assign $node name value]]
	set var [$form item var $item $value]
	if {[$node attr -default "no" checked] ne "no"} {
	    set $var 1
	}
	ttk::checkbutton $path -variable $var
    }

    method {add input radio} {path node form args} {
	set item [$form item register node multi $node \
		      [node-atts-assign $node name value]]
	set var [$form item var $item]
	if {[$node attr -default "no" checked] ne "no"} {
	    set $var $value
	}
	ttk::radiobutton $path -variable $var -value $value
    }

    method {add input hidden} {path node form args} {
	set item [$form item register node multi $node \
		      [node-atts-assign $node name value]]
	set var [$form item var $item]
	set $var $value
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
	-fill both -expand yes
}
