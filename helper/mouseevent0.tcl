# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::mouseevent0 {} {

    #========================================
    # mouse event handling, salvaged and extended from ::hv3::hv3::mousemanager
    #========================================

    # Note: this event registration system is basically isolated from
    # Tk's [bind widget <<Event>>] system.
    # You can't add/invoke input[type=checkbox] via [~ node event on/trigger]
    # (at least currently).

    variable stateHoverNodes -array []
    variable stateActiveNodes -array []

    method Press {w x y} {
        adjust-coords-to $myHtml $w x y
        set nodelist [$myHtml node $x $y]
        # XXX: Selection handling, and its prevention
        
        foreach startNode $nodelist {
            set startNode [parent-of-textnode $startNode]
            for-upward-node node $startNode {
                set stateActiveNodes($node) 1
            }
        }
        
	set evlist {}
        foreach node [array names stateActiveNodes] {
            $node dynamic set active
            lappend evlist mousedown $node
        }
        
        $self node event generatelist $evlist   
    }

    method Release {w x y} {
        adjust-coords-to $myHtml $w x y
        set nodelist [$myHtml node $x $y]

        set evlist {}
        foreach node [array names stateActiveNodes] {
            $node dynamic clear active
            lappend evlist mouseup $node
        }
        array unset stateActiveNodes
        
        foreach node $nodelist {
            lappend evlist click $node
        }

        $self node event generatelist $evlist
    }

    method Motion {w x y} {
        adjust-coords-to $myHtml $w x y
        
        array set evNodes [$self node gather hovernodes \
                               [$myHtml node $x $y]]
	# puts stderr evNodes=[array get evNodes]

        array set actions [list mouseover set mouseout clear]

        set evlist [list]
        foreach key [list mouseover mouseout] {
            foreach node $evNodes($key) {
                $node dynamic $actions($key) hover
                lappend evlist $key $node
            }
        }

        $self node event generatelist $evlist
    }

    method {node gather hovernodes} nodelist {
        array set hovernodes  []
        set evNodes(mouseover) []
        set evNodes(mouseout)  []

        foreach startNode $nodelist {
            set startNode [parent-of-textnode $startNode]
            for-upward-node node $startNode {
                set vn hovernodes($node)
                if {[info exists $vn]} break
                set sn stateHoverNodes($node)
                if {[info exists $sn]} {
                    unset $sn
                } else {
                    lappend evNodes(mouseover) $node
                }
                set $vn ""
            }
        }
        
        set evNodes(mouseout) [array names stateHoverNodes]
        array unset stateHoverNodes
        array set stateHoverNodes [array get hovernodes]

        array get evNodes
    }

    #========================================
    #
    # Valid event names should be registered below:
    #
    set evlist [list \
                    ready \
                    submit \
                    mouseover mousemove mouseout click \
                    dblclick mousedown mouseup]
    typevariable ourMouseEventList $evlist
    typevariable ourEvDict -array [set ls {}; foreach i $evlist {
        lappend ls $i $i
    }; set ls]

    #
    # This holds all node->event->{handler list}
    #
    variable stateTriggerDict [dict create]

    method {node event dump-handlers} {} {
        set stateTriggerDict
    }

    #
    # Global event. This can be registered before parse.
    #
    method on {event command} {
        $self node event on "" $event $command
    }
    method trigger {event args} {
        $self node event trigger "" $event {*}$args
    }

    #
    # Node event.
    #
    method {node event add} {node event command} {
	$self $node event on $node $event $command
    }
    method raise-if-strict-event msg {
	if {$options(-strict-event)} {
	    error $msg
	} else {
	    return -code return
	}
    }

    option -strict-event no
    method {node event remove} {node event command} {
	if {![info exists ourEvDict($event)]} {
	    $self raise-if-strict-event "Unknown event name $event"
	}
        if {![dict exists $stateTriggerDict $node]} {
	    $self raise-if-strict-event "No events are known for $node"
	}
	dict with stateTriggerDict $node {
	    set curList [set $ourEvDict($event)]
	    if {[set pos [lsearch $curList $command]] >= 0} {
		set $ourEvDict($event) [lreplace $curList $pos $pos]
	    }
	}
    }

    method {node event on} {node event command} {
        if {![dict exists $stateTriggerDict $node]} {
            dict set stateTriggerDict $node \
                [dict create $ourEvDict($event) [list $command]]
        } else {
            dict with stateTriggerDict $node {
                lappend $ourEvDict($event) $command
            }
        }
        # puts stateTriggerDict=$stateTriggerDict
    }

    method {node event clear} {node event} {
        dict set stateTriggerDict $node $event {}       
    }

    method {node event trigger} {startNode event args} {

        set handlers [$self node event list-handlers $startNode $event \
			  $args]
        # puts startNode=$startNode,[if {$startNode ne ""} {
        #     list tag=[$startNode tag]
        # }],event=$event,handlers=$handlers

        $self node event handlelist $handlers
    }
    
    #
    # This single loop runs all matched handlers at once.
    #
    option -event-in-apply yes
    method {node event handlelist} handlers {
        if {$options(-event-in-apply)} {
            # Safer, but need to use [return -code break] instead of [break]
            foreach spec $handlers {
                set args [lassign $spec event node cmd]
                $self node event apply $event $node $cmd {*}$args
            }
        } else {
            # Can be fragile.
            foreach spec $handlers {
                set args [lassign $spec event node cmd]
                set this $node
                eval $cmd
            }
        }
    }

    method {node event apply} {event node cmd args} {
        # XXX: What kind of API should we have?
        apply [list {self win selfns node this args} $cmd] \
            $self $win $selfns $node $node {*}$args
    }

    option -debug-mouse-event 0
    method {node event generatelist} evlist {
        if {$options(-debug-mouse-event) >= 2} {
            puts stderr "(node event generatelist) $evlist"
        }
        set handlers {}
        foreach {event node} $evlist {
            lappend handlers {*}[$self node event list-handlers $node $event]
        }
        $self node event handlelist $handlers
    }

    #
    # This defines event triggering order.
    #
    option -generate-tag-class-event yes
    method {node event list-handlers} {startNode event {arglist ""}} {
        set result {}
        if {$startNode ne ""} {
            set startNode [parent-of-textnode $startNode]
        }
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

            if {![dict-getvar $stateTriggerDict $key $event cmdlist]} continue

	    if {$node eq ""} {
		set node [if {$startNode ne ""} {
		    set startNode
		} else {
		    $myHtml node
		}]
	    }

            foreach cmd $cmdlist {
                lappend result [list $event $node $cmd {*}$arglist]
            }

        } {*}$altList ""

        set result
    }

    #========================================
    method install-mouse-handlers {} {

        bind $win <ButtonPress-1>   +[mymethod Press   %W %x %y]
        bind $win <Motion>          +[mymethod Motion  %W %x %y]
        bind $win <ButtonRelease-1> +[mymethod Release %W %x %y]
        
        #
        # Install all [~ node event tag *] handlers
        #
        foreach meth [$self info methods [list node event tag *]] {
            set rest [lassign $meth n e t]
            $self node event on {*}$rest \
                [string map [list %% $rest] {$self node event tag %% $node}]
        }
    }
    
    #========================================
    method {node event tag a click} node {
        if {[set href [$node attr -default "" href]] eq ""} return
        
        if {[regexp ^\# $href]} {
            $self See $href
        } else {
            puts stderr "Not yet implemented: href=$href"
        }
    }

    method {node event tag label click} node {
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
