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
    # HTML Tag handling
    #========================================

    option -handle-parse [list form]
    option -handle-script [list style]
    option -handle-node [list [list input by-input-type]\
			     textarea \
			     select \
			    ]
    # To be handled
    list {
        a link
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

    method {with path-of} {node command} {
        upvar 1 path path
        set path [$self node path $node]
        uplevel 1 $command
        if {[info exists path] && $path ne ""} {
            $node replace $path -deletecmd [list destroy $path] \
		-configurecmd [list $self node configure $path]
        }
    }

    method {node configure} {path values} {
	if {[set font [from values font ""]] eq ""} {
	    if {![catch {$path cget -font} font]} {
		return 0
	    }
	}
	$self font-baseline $path $font
    }

    # Stolen from hv3_form.tcl ::hv3::forms::configurecmd
    method font-baseline {path font} {
	set descent [font metrics $font -descent]
	set ascent  [font metrics $font -ascent]
	expr {([winfo reqheight $path] + $descent - $ascent) / 2}
    }

    method {node path} node {
        if {[set id [$node attr -default "" id]] eq ""} {
            set id [string map {: _} $node]
        }
        return $myHtml._$id
    }

    #========================================
    # node utils
    #========================================

    # extract attr (like [lassign]) returns [dict]
    proc node-atts-assign {node args} {
        set _atts {}
        foreach _spec $args {
            lassign $_spec _key _default
            upvar 1 $_key _upvar
            set value [$node attr -default $_default $_key]
            lappend _atts $_key $value
            set _upvar $value
        }
        set _atts
    }

    #========================================
    # logging... hmm...
    variable stateParseErrors ""
    option -debug no
    method logged args {
        set rc [catch {
            $self {*}$args
        } error]
        if {$rc} {
            $self error add [list error $error $::errorInfo]
        }
    }
    method {error get} {} {
	set stateParseErrors
    }
    method {error add} error {
        lappend stateParseErrors $error
        if {$options(-debug)} {
            puts stderr $error
        }
    }
    method {error raise} error {
        lappend stateParseErrors $error
        error $error
    }

    #========================================
    # form (formstate)
    #========================================
    variable stateInForm ""
    variable stateFormList {}
    variable stateFormNameDict -array {}
    variable stateOuterForm ""

    method {add parse form} {node args} {
        if {[regexp ^/ [$node tag]]} {
            set stateInForm ""
        } else {
            $self form add-for-node $node
            set stateInForm 1
        }
    }

    method {form list} {} {
        set stateFormList
    }

    method {form names} {args} {
        array names stateFormNameDict {*}$args
    }

    method {form get} {ix {fallback yes}} {
        if {[string is integer $ix]} {
            if {$ix == 0 && ![llength $stateFormList]} {
                if {!$fallback} {
                    error "No form tag!"
                }
                set stateOuterForm
            } else {
                lindex $stateFormList $ix
            }
        } elseif {[regexp ^@(.*) $ix -> name]} {
            set stateFormNameDict($name)
        } else {
            # XXX: ix に css selector を渡せても良いのでは。
            error "Invalid form index: $ix"
        }
    }

    method {form add-for-node} {node} {
        set name [$node attr -default "" name]
        set vn stateFormNameDict($name)
        if {$name ne "" && [info exists $vn]} {
            $self error add [list form name=$name appeared twice!]
        }

        set form [$self form new $name -action [$node attr -default "" action] \
                     -node $node]
        lappend stateFormList $form
        set $vn $form
    }
    
    method {with form} command {
        upvar 1 form form
        set form [$self form current]
        uplevel 1 $command
    }
    
    method {form current} {} {
        if {$stateInForm ne ""} {
            lindex $stateFormList end
        } elseif {$stateOuterForm ne ""} {
            set stateOuterForm
        } else {
            set stateOuterForm [$self form new ""]
        }
    }

    method {form new} {name args} {
        formstate $self.form%AUTO% -name $name {*}$args
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

    method innerTextPre node {
	set contents {}
	foreach kid [$node children] {
	    append contents [$kid text -pre]
	}
	set contents
    }

    #
    # <textarea>
    #
    method {add node textarea} node {
        $self with form {
            $self with path-of $node {
                widget::scrolledwindow $path
		set t $path.text
		#set t $path
                text $t -width [$node attr -default 60 cols]\
		    -height [$node attr -default 10 rows] \
		    -undo yes
		$path setwidget $t
		$path configure -width 600 -height 100

                set var [$form node add text $node \
			     [node-atts-assign $node name value] \
			     getter [list {{t} {
				 $t get 1.0 end-1c
			     }} $t] \
			     setter [list {{t value} {
				 $t delete 1.0 end
				 $t insert end $value
			     }} $t]]
                set $var [$self innerTextPre $node]
            }
        }
    }

    method {add node select} node {
        $self with form {
            $self with path-of $node {
		if {[$node attr -default "no" multi] ne "no"} {
		    $self add select-multi $path $node $form
		} else {
		    $self add select-single $path $node $form
		}
	    }
	}
    }
    
    method {add select-single} {path selNode form args} {
	set name [$selNode attr -default "" name]
	lassign [$self form collect options $selNode] \
	    nodeDefs labelList selected

	foreach spec $nodeDefs {
	    lassign $spec node value
	    $form node add single $node \
		[dict create name $name value $value] \
		getter [list {{path form name} {
		    lindex [$form choicelist $name] \
			[$path current]
		}} $path $form $name] \
		setter [list {{path form name value} {
		    set pos [lsearch -exact [$form choicelist $name] $value]
		    if {$pos >= 0} {
			$path current $pos
		    }
		}} $path $form $name]
	}
	ttk::combobox $path -state readonly -values $labelList
	if {$selected ne ""} {
	    $path current $selected
	} else {
	    $path current 0
	}
    }

    method {add select-multi} {path selNode form args} {
	set name [$selNode attr -default "" name]
	lassign [$self form collect options $selNode] \
	    nodeDefs labelList selected

	foreach spec $nodeDefs {
	    lassign $spec node value
	    $form node add multi $node \
		[dict create name $name value $value] \
		array-getter [list {{path form name ix} {
		    set pos [lsearch -exact [$form choicelist $name] $ix]
		    if {$pos < 0} return
		    $path selection includes $pos
		}} $path $form $name] \
		array-setter [list {{path form name ix value} {
		    set pos [lsearch -exact [$form choicelist $name] $ix]
		    if {$pos < 0} return
		    if {$value} {
			$path selection set $pos
		    } else {
			$path selection clear $pos
		    }
		}} $path $form $name]
	}
	listbox $path -selectmode extended
	$path insert end {*}$labelList
	$path selection clear 0 end
	foreach sel $selected {
	    $path selection set $sel
	}
    }

    method {form collect options} {selNode} {
	set name [$selNode attr -default "" name]
	set nodeDefs {}
	set labelList {}
	set selected {}
	set i -1
	foreach node [$self search option -root $selNode] {
	    incr i
	    lappend labelList [set label [[lindex [$node children] 0] text]]
	    set value [if {"value" in [$node attr]} {
		$node attr value
	    } else {
		set label
	    }]
	    lappend nodeDefs [list $node $value]
	    if {[$node attr -default no selected] ne "no"} {
		lappend selected $i
	    }
	}
	list $nodeDefs $labelList $selected
    }

    #----------------------------------------
    # <input type=...>
    #----------------------------------------
    method {add by-input-type} node {
        $self with form {
            $self with path-of $node {
                set t [$node attr -default text type]
                set methName [list add input $t]
                if {[llength [$self info methods $methName]]} {
                    $self {*}$methName $path $node $form
                } else {
                    $self error add [list unknown input-type $t $node]
                    set path ""; # To avoid $node replace $path
                }
            }
        }
    }

    method {add input text} {path node form args} {
        set var [$form node add text $node \
		     [node-atts-assign $node name value]]
        ::ttk::entry $path \
            -textvariable $var \
            -width [$node attr -default 20 size] {*}$args
	if {[set script [$node attr -default "" onchange]] ne ""} {
	    bind $path <Return> \
		[list apply [list {win node path form} $script]\
		     $win $node $path $form]
	}
    }

    method {add input password} {path node form args} {
        $self add input text $path $node $form -show * {*}$args
    }

    method {add input button} {path node form args} {
        set text [$node attr -default [from args -text] value]
        ttk::button $path -takefocus 1 -text $text {*}$args
    }
        
    method {add input submit} {path node form args} {
        $form node add submit $node \
	    [node-atts-assign $node name {value Submit}]

	# XXX: This -command behavior is experimental.
        ttk::button $path -takefocus 1 -text $value \
            -command [list $self trigger submit $form $name] {*}$args
    }

    method {add input checkbox} {path node form args} {
        set var [$form node add multi $node \
		     [node-atts-assign $node name {value on}]]
	set $var [expr {[$node attr -default "no" checked] ne "no"}]
        ttk::checkbutton $path -variable $var
    }

    method {add input radio} {path node form args} {
        set var [$form node add single $node \
		     [node-atts-assign $node name {value on}]]
        if {[$node attr -default "no" checked] ne "no"} {
            set $var $value
        }
        ttk::radiobutton $path -variable $var -value $value
    }

    method {add input hidden} {path node form args} {
        $form node add text $node \
	    [node-atts-assign $node name value]
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
        -fill both -expand yes
}
