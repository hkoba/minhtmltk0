# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

package require tooltip

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

    method {node form kind} node {
        set tag [$node tag]
        switch $tag {
            input {
                return [list input [$node attr -default text type]]
            }
            select {
                if {[$node attr -default "no" multi] ne "no"} {
                    return select-multi
                } else {
                    return select-single
                }
            }
            default {
                return $tag
            }
        }
    }

    method {form redraw} {node args} {
        $self form redraw-input [$self node form kind $node] $node {*}$args
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
                      -node $node \
                      -debug [expr {$options(-debug) && $options(-debug) >= 2}]]
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
    
    method {form event configure} {form node args} {
        if {$args eq ""} {set args [list change]}
        foreach event $args {
            if {![info exists ourEvDict($event)]} {
                $self logger error "event not supported: $event (on $node [$node tag] [$node attr])"
                continue
            }
            if {[set script [$node attr -default "" on$event]] eq ""} continue
            set var [$form node var $node]
            # puts [list add node event on $node $event var: $var script: $script]
            $self node event configure $node $event \
                form $form varName $var
        }
    }

    method {node event configure} {node event args} {
        if {[set script [$node attr -default "" on$event]] eq ""} return
        set formalArgs [list self win node]
        set actualArgs [list [$self script-self] $win $node]
        foreach {n v} $args {
            lappend formalArgs $n
            lappend actualArgs $v
        }
        $self node event on $node $event \
            [list apply \
                 [list args \
                      [list apply \
                           [list [list {*}$formalArgs args] \
                                $script] \
                           {*}$actualArgs]]]
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
                $self add [$self node form kind $node] $path $node $form
            }
        }
    }

    method {add select-single} {path selNode form args} {
        set name [$selNode attr -default "" name]
        lassign [$self form collect options $selNode] \
            recordList nodeDefs labelList selected valueList

        set var [$form node add single $selNode [dict create name $name]]
        set labelVar ${var}_label

        $form node trace configure $selNode \
            setter [list {{self selNode path form name var labelVar labelList value} {
                set valueList [$form choicelist $name]
                set pos [lsearch -exact $valueList $value]
                if {[$self cget -debug] >= 2} {
                    puts [list setter value $value var $var \
                              varValue [set $var] \
                              labelVar $labelVar \
                              labelValue [set $labelVar] \
                              pos $pos valueList $valueList]
                }
                if {$pos >= 0} {
                    set $labelVar [lindex $labelList $pos]
                }
            }} $self $selNode $path $form $name $var $labelVar $labelList]

        $self form event configure $form $selNode

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

        # replace early
        $selNode replace $path

        $self form redraw-input select-single $selNode \
            $recordList
    }

    method {form redraw-input select-single} {node recordList} {
        set menuButton [$node replace]
        set menu [$menuButton cget -menu]
        $menu delete 0 end

        set form [$self form of-node $node]
        set var [$form node var $node]
        set isSet [info exists $var]

        set i -1
        set labelList {}
        set valueList {}
        set selectedList {}
        foreach item $recordList {
            incr i
            set value [dict get $item value]
            $menu add radiobutton \
                -label [dict get $item label] \
                -command [list set $var $value]
            # -value {} doesn't work for radiobutton entry!
            # -variable $var with -command causes double-assignment!

            lappend labelList [dict get $item label]
            lappend valueList $value
            if {[dict get $item selected]} {
                lappend selectedList $i
            }
        }
        if {$labelList eq "" || $isSet} {
            return
        } else {
            set newValue [if {$selectedList ne ""} {
                set comment [list redraw set: var $var $selectedList]
                lsearch -exact $valueList $selectedList
            } else {
                set comment [list redraw reset: var $var to [lindex $valueList 0]]
                lindex $valueList 0
            }]
            if {!$isSet || $newValue ne [set $var]} {
                if {$options(-debug) >= 2} {
                    puts $comment
                }
                set $var $newValue
            }
        }
    }

    method {add select-multi} {path selNode form args} {
        set name [$selNode attr -default "" name]
        lassign [$self form collect options $selNode] \
            recordList nodeDefs labelList selected

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
        set recordList {}
        set nodeDefs {}
        set labelList {}
        set valueList {}
        set selectedList {}
        set i -1
        foreach node [$self search option -root $selNode] {
            incr i
            set label [if {[set kids [$node children]] eq ""} {
                list
            } else {
                [lindex $kids 0] text
            }]
            # XXX: ./src/htmltcl.c:381: checkRestylePointCb: Assertion `p' failed.
            # if {![$self node is-shown $node]} continue
            lappend labelList $label
            set value [if {"value" in [$node attr]} {
                $node attr value
            } else {
                set label
            }]
            lappend valueList $value
            lappend nodeDefs [list $node $value]
            set selected [expr {[$node attr -default no selected] ne "no"}]
            if {$selected} {
                lappend selectedList $i
            }
            lappend recordList [dict create value $value label $label node $node selected $selected]
        }
        list $recordList $nodeDefs $labelList $selectedList $valueList
    }

    method {node title configure} {node path} {
        set title [$node attr -default "" title]
        if {$title eq ""} return
        ::tooltip::tooltip $path $title
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

                    $self form event configure $form $node

                    $self node title configure $node $path
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

        trace add variable $var write \
            [list $form do-trace scalar write $node]

        # if {[set script [$node attr -default "" onchange]] ne ""} {
        #     bind $path <Return> \
        #         [list apply [list {win node path form} $script]\
        #              $win $node $path $form]
        # }
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

        $self node event configure $node click \
            form $form
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
            # Not worked
            # -class [$type ttk-style-get button]
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
        trace add variable $var write \
            [list $form do-trace array write $node]
        ttk::checkbutton $path -variable $var
        # -class [$type ttk-style-get checkbutton]
    }

    method {add input radio} {path node form args} {
        set var [$form node add single $node \
                     [node-atts-assign $node name {value on}]]
        if {[$node attr -default "no" checked] ne "no"} {
            set $var $value
        }
        trace add variable $var write \
            [list $form do-trace scalar write $node]
        ttk::radiobutton $path -variable $var -value $value
        # -class [$type ttk-style-get radiobutton]
    }

    method {add input hidden} {path node form args} {
        set var [$form node add text $node \
                     [node-atts-assign $node name value]]

        trace add variable $var write \
            [list $form do-trace scalar write $node]
    }
}

