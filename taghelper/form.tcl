# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

::minhtmltk::taghelper::add parse form
::minhtmltk::taghelper::add node  input by-input-type
::minhtmltk::taghelper::add node  textarea
::minhtmltk::taghelper::add node  select

snit::macro ::minhtmltk::taghelper::form {} {

    ::minhtmltk::taghelper nodeutil
    ::minhtmltk::taghelper errorlogger

    method {node path} node {
        if {[set id [$node attr -default "" id]] eq ""} {
            set id [string map {: _} $node]
        }
        return $myHtml._$id
    }
    
    method {with form} command {
        upvar 1 form form
        set form [$self form current]
        uplevel 1 $command
    }
    
    method {with path-of} {node command} {
        upvar 1 path path
        set path [$self node path $node]
        uplevel 1 $command
        if {[info exists path] && $path ne "" && [winfo exists $path]} {
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

    #========================================
    # form (formstate)
    #========================================
    variable stateInForm ""
    variable stateFormList {}
    variable stateFormNameDict -array {}
    variable stateFormNodeDict -array {}
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
	set stateFormNodeDict($node) $form
        lappend stateFormList $form
        set $vn $form
    }
    
    method {form of-node} startNode {
        set node [upward-find-tag $startNode form]
        set stateFormNodeDict($node)
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
        formstate $self.form%AUTO% -window $win -name $name {*}$args
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
                                 set state [$t cget -state]
                                 $t configure -state normal
                                 $t delete 1.0 end
                                 $t insert end $value
                                 $t configure -state $state
                             }} $t]]
                set $var [$self innerTextPre $node]
                
                if {[$node attr -default no readonly] ne "no"
                    || [$node attr -default no disabled] ne "no"} {
                    $t configure -state disabled -undo no
                }
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
            nodeDefs labelList selected valueList

        set var [$form node add single $selNode [dict create name $name]]
        set labelVar ${var}_label

        $form node trace configure $selNode \
            setter [list {{path form name labelVar labelList value} {
                set valueList [$form choicelist $name]
                set pos [lsearch -exact $valueList $value]
                if {$pos >= 0} {
                    set $labelVar [lindex $labelList $pos]
                }
            }} $path $form $name $labelVar $labelList]

        foreach spec $nodeDefs {
            lassign $spec node value
            $form node add single $node \
                [dict create name $name value $value]
        }

        set menu $path.menu
        menubutton $path -textvariable $labelVar -indicatoron 1 -menu $menu \
            -relief raised -highlightthickness 1 -anchor c \
            -direction flush
        menu $menu -tearoff 0
        foreach value $valueList label $labelList {
            $menu add radiobutton -variable $var -label $label -value $value
        }
        if {$labelList eq ""} {
            return
        } elseif {$selected ne ""} {
            set $var [lsearch -exact $valueList $selected]
        } else {
            set $var [lindex $valueList 0]
        }
    }

    method {add select-multi} {path selNode form args} {
        set name [$selNode attr -default "" name]
        lassign [$self form collect options $selNode] \
            nodeDefs labelList selected

        $form node add multi $selNode [dict create name $name] \
            getter [list {{path form name ix} {
                set pos [lsearch -exact [$form choicelist $name] $ix]
                if {$pos < 0} return
                $path selection includes $pos
            }} $path $form $name] \
            setter [list {{path form name ix value} {
                set pos [lsearch -exact [$form choicelist $name] $ix]
                if {$pos < 0} return
                if {$value} {
                    $path selection set $pos
                } else {
                    $path selection clear $pos
                }
            }} $path $form $name]

        foreach spec $nodeDefs {
            lassign $spec node value
            $form node add multi $node \
                [dict create name $name value $value]
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
        set valueList {}
        set selected {}
        set i -1
        foreach node [$self search option -root $selNode] {
            incr i
            set label [if {[set kids [$node children]] eq ""} {
                list
            } else {
                [lindex $kids 0] text
            }]
            lappend labelList $label
            set value [if {"value" in [$node attr]} {
                $node attr value
            } else {
                set label
            }]
            lappend valueList $value
            lappend nodeDefs [list $node $value]
            if {[$node attr -default no selected] ne "no"} {
                lappend selected $i
            }
        }
        list $nodeDefs $labelList $selected $valueList
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

    option -use-tk-button no

    method {add input button} {path node form args} {
	if {$options(-use-tk-button)} {
	    set text [$node attr -default [from args -text] value]
	    ttk::button $path -takefocus 1 -text $text \
		-command [list $self node event trigger $node click \
			      form $form] \
		{*}$args
	}
    }

    method {add input submit} {path node form args} {
        set atts [node-atts-assign $node name {value Submit}]
        if {$name ne ""} {
            $form node add submit $node $atts
        }

	# XXX: This node event API is not yet stabilized.
	if {$options(-use-tk-button)} {
	    ttk::button $path -takefocus 1 -text $value \
		-command [list $self node event trigger $node submit \
			      form $form name $name] {*}$args
	} else {
	    $self node event on $node click \
		[list $self node event trigger $node submit \
		     form $form name $name]
	}
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

