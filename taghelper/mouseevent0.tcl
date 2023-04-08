# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

snit::macro ::minhtmltk::taghelper::mouseevent0 {} {

    #========================================
    # mouse event handling, salvaged and extended from ::hv3::hv3::mousemanager
    #========================================

    # Note: this event registration system is basically isolated from
    # Tk's [bind widget <<Event>>] system.
    # You can't add/invoke input[type=checkbox] via [~ node event on/trigger]
    # (at least currently).

    variable stateHoverNodes -array []
    variable stateActiveNodes [dict create]

    option -debug-mouse-event 0

    method Press {w x y} {
        $self node event change allow __scope__
        focus $w

        adjust-coords-to $myHtml $w x y
        set nodelist [$myHtml node $x $y]
        # XXX: Selection handling, and its prevention
        
        foreach startNode $nodelist {
            set startNode [parent-of-textnode $startNode]
            for-upward-node node $startNode {
                dict set stateActiveNodes $node 1
            }
        }
        
	set evlist {}
        foreach node [dict keys $stateActiveNodes] {
            $node dynamic set active
            lappend evlist mousedown $node
        }
        
        set rc [$self node event generatelist $evlist]

        $self node event selection press $rc [lindex $nodelist end] $x $y
    }

    method Release {w x y} {
        $self node event change allow __scope__
        adjust-coords-to $myHtml $w x y
        set nodeDict [dict create]
        foreach node [$myHtml node $x $y] {
            dict set nodeDict $node 1
        }

        set evlist {}
        foreach node [dict keys $stateActiveNodes] {
            $node dynamic clear active
            lappend evlist mouseup $node
            if {[dict exists $nodeDict $node]} continue
            dict set nodeDict $node 1
        }
        set stateActiveNodes [dict create]
        
        foreach node [dict keys $nodeDict] {
            lappend evlist click $node
        }

        # puts stderr [list Release generates: $evlist]

        $self node event generatelist $evlist

        $self node event selection release \
            [lindex [dict keys $nodeDict] end] $x $y
    }

    method Motion {w x y} {
        $self node event change allow __scope__
        adjust-coords-to $myHtml $w x y
        
        set nodelist [$myHtml node $x $y]

        array set evNodes [$self node hover analyze $nodelist topChanged]
        if {$topChanged} {
            $self node hover changeCursor [lindex $nodelist end]
        }
	# puts stderr evNodes=[array get evNodes]

        array set actions [list mouseover set mouseout clear]

        set handlers [list]
        foreach event [list mouseover mouseout] {
            foreach node $evNodes($event) {
                $node dynamic $actions($event) hover
                lappend handlers [$self node event list-handlers $node $event]
            }
        }

        if {[set N [lindex $nodelist end]] eq ""} {
            set N [$myHtml node]
        }
        foreach handler [$self node event list-handlers $N mousemove] {
            # event node cmd {*}$args
            lappend handlers [linsert $handler end x $x y $y]
        }

        # puts handlers=[join $handlers \n]

        $self node event handlelist $handlers

        $self node event selection motion [lindex $nodelist end] $x $y
    }

    method {node hover analyze} {nodelist {topChangedVar ""}} {

        if {$topChangedVar ne ""} {
            upvar 1 $topChangedVar topChanged
            set topnode [lindex $nodelist end]
            set topChanged [expr {$topnode ne "" 
                                  && $topnode ne $stateTopHoverNode}]
        }

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
    # Cursor setting
    
    typevariable ourCURSORS -array [list      \
                                        crosshair crosshair      \
                                        default   ""             \
                                        pointer   hand2          \
                                        move      fleur          \
                                        text      xterm          \
                                        wait      watch          \
                                        progress  box_spiral     \
                                        help      question_arrow \
                                       ]

    variable stateTopHoverNode ""
    variable stateCursor ""
    method {node hover changeCursor} {topnode} {
        set Cursor ""
        if {[$topnode tag] eq ""} {
            set Cursor xterm
            set topnode [$topnode parent]
        }

        set css2_cursor [$topnode property cursor]
        set vn ourCURSORS($css2_cursor)
        set Cursor [if {[info exists $vn]} {set $vn} else {set Cursor}]

        if {$Cursor ne $stateCursor} {
            [winfo toplevel $myHtml] configure -cursor $Cursor
            set stateCursor $Cursor
        }
        
        set stateTopHoverNode $topnode
    }

    #========================================
    #
    # Valid event names should be registered below:
    #
    set evlist [list \
                    ready \
                    submit \
                    change \
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
        if {![$self state is DocumentReady]} return
        if {$event eq "change"} {
            if {[$self node event change is-handling]} return
            $self node event change set-handling
        }
        set handlers [$self node event list-handlers $startNode $event \
			  $args]
        if {$handlers eq ""} {
            # XXX
        }
        $self node event handlelist $handlers
    }

    #
    # This single loop runs all matched handlers at once.
    #
    option -event-in-apply yes
    method {node event handlelist} handlers {
        set count 0
        if {$options(-event-in-apply)} {
            # Safer, but need to use [return -code break] instead of [break]
            foreach spec $handlers {
                set args [lassign $spec event node cmd]
                $self node event apply $event $node $cmd {*}$args
                incr count
            }
        } else {
            # Can be fragile.
            foreach spec $handlers {
                set args [lassign $spec event node cmd]
                set this $node
                eval $cmd
                incr count
            }
        }

        # returns whether all handlers are processed.
        expr {[llength $handlers] == $count}
    }

    method {node event apply} {event node cmd args} {
        # XXX: What kind of API should we have?
        apply [list {self win selfns node this args} $cmd] \
            $self $win $selfns $node $node {*}$args
    }

    method {node event generatelist} evlist {
        set handlers {}
        array set seen {}
        foreach {event node} $evlist {
            foreach spec [$self node event list-handlers $node $event] {
                if {[incr seen($spec)] >= 2} continue
                lappend handlers $spec
            }
        }
        if {$options(-debug-mouse-event) >= 2} {
            puts stderr "(node event generatelist) => $handlers"
        }
        $self node event handlelist $handlers
    }

    #
    # This was introduced to define event triggering order, but now it isn't.
    #
    option -generate-tag-class-event yes
    method {node event list-handlers} {startNode event {arglist ""}} {

        if {$startNode ne ""} {
            set startNode [parent-of-textnode $startNode]
        }
        set nodeSpecList [if {$startNode ne ""
                         && $options(-generate-tag-class-event)} {
            tag-class-list-of-node $startNode
        } else {
            list $startNode
        }]

        set result []
        foreach nspec $nodeSpecList {
            # In simple case, nspec = key = node
            # In tag-class-list, nspec = [list tag_class node]
            set key  [lindex $nspec 0]
            set node [lindex $nspec end]

            # puts [list look-for $event $key $node]
            if {!(
                  [dict-getvar $stateTriggerDict $node $event cmdlist]
                  || [dict-getvar $stateTriggerDict $key $event cmdlist]
                  )
            } continue

            if {$options(-debug-mouse-event) >= 3} {
                puts "list-handlers($node $key $event) => cmdlist($cmdlist)"
            }

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
        }

        # global event
        if {$result eq ""
            && [dict-getvar $stateTriggerDict "" $event cmdlist]} {
            foreach cmd $cmdlist {
                lappend result [list $event $node $cmd {*}$arglist]
            }
        }
        if {$result eq ""} {
            # puts [list no handler for $event $startNode]
        } else {
            # puts [list event $event on $startNode generates: $result]
        }

        set result
    }

    variable stateHandlingEventsList ""
    method {node event change allow} {{scopeVar ""}} {
        set stateHandlingEventsList ""
        if {$scopeVar ne ""} {
            uplevel 1 [list ::minhtmltk::utils::scope_guard $scopeVar \
                           [list set [myvar stateHandlingEventsList] ""]]
        }
    }
    method {node event change is-handling} {} {
        expr {"change" in $stateHandlingEventsList}
    }
    method {node event change set-handling} {} {
        if {"change" in $stateHandlingEventsList} return
        lappend stateHandlingEventsList change
    }
    method {node event change suppressing} {command} {
        ::minhtmltk::utils::scope_guard command \
            [list set [myvar stateHandlingEventsList] $stateHandlingEventsList]
        if {"change" ni $stateHandlingEventsList} {
            lappend stateHandlingEventsList change
        }
        uplevel 1 $command
    }

    #========================================
    # install-mouse-handlers is called everytime [$self interactive] is called.
    # So, I want to avoid `+` prefix for bind handlers.
    #
    method install-mouse-handlers {} {

        bind $win <ButtonPress-1>   [list $self Press   %W %x %y]
        bind $win <Motion>          [list $self Motion  %W %x %y]
        bind $win <ButtonRelease-1> [list $self Release %W %x %y]
        
        bind $win <<Copy>> [list $win selection toClipboard]

        #
        # Install all [~ node event tag *] handlers
        #
        foreach meth [$self info methods [list node event tag *]] {
            set rest [lassign $meth n e t]
            $self node event on {*}$rest \
                [string map [list %% $rest] {$self node event tag %% $node}]
        }

        selection handle $win [list $win selection read]
    }
    
    #========================================
    method {node event tag a click} node {
        if {[set href [$node attr -default "" href]] eq ""} return

        if {[regexp ^\# $href]} {
            $self See $href
        } else {
            # puts "loading $href from $node"
            $self nav loadURI $href
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

    #========================================
    # Salvaged from ::hv3::hv3::selectionmanager.
    # selection mode feature (char/word/block) is dropped to make code simple.
    #

    # Since state$VAR is repeatedly initialized to "" by Reset,
    # use of "false" here can lead inconsistent result.
    # So I explicitly initialize these flag vars with "".
    variable stateMouseDown ""
    variable stateMouseIgnoreMotion ""

    variable stateMouseFromNode ""
    variable stateMouseFromIdx ""
    variable stateMouseToNode ""
    variable stateMouseToIdx ""

    method {node event selection press} {successEv node x y} {
        $self selection clear
        if {$successEv} {
            set stateMouseDown yes
            $self selection adjust $node $x $y
        }
    }

    method {node event selection motion} {node x y} {
        if {$stateMouseDown eq "" || $stateMouseIgnoreMotion ne ""} return
        $self selection adjust $node $x $y
    }

    method {node event selection release} {node x y} {
        set stateMouseDown ""
    }

    method {selection clear} {} {
        # node is ignored.

        $myHtml tag delete selection
        $myHtml tag configure selection \
            -foreground white -background darkgrey
        set stateMouseFromNode ""
        set stateMouseToNode ""
        
        # Memo: stateMouseFromNode が "" にされた時に bacgrace を出す
        # set vn [myvar stateMouseFromNode]
        # trace add variable $vn write \
        #     [list apply [list [list self varName args] {
        #         if {[set $varName] eq ""} {
        #             puts [join [::minhtmltk::utils::getBacktrace] \n]\n
        #         }
        #     }] $self $vn]
    }

    method {selection adjust} {node x y} {
        if {$node eq ""} {
            set node [$myHtml node]
        }

        set to [$myHtml node -index $x $y]
        lassign $to toNode toIdx

        if {$node ne "" && $toNode ne ""
            && [$node stacking] ne [$toNode stacking]} {
            set to ""
        } elseif {$stateMouseFromNode eq ""} {
            set stateMouseFromNode $toNode
            set stateMouseFromIdx $toIdx
        }

        if {$to ne ""} {

            set rc [catch {
                if {$stateMouseToNode ne $toNode || $toIdx != $stateMouseToIdx} {
                    if {$stateMouseToNode ne ""} {
                        $myHtml tag remove selection \
                            $stateMouseToNode $stateMouseToIdx $toNode $toIdx
                    }

                    #puts [list $stateMouseFromNode $stateMouseFromIdx $toNode $toIdx]

                    $myHtml tag add selection \
                        $stateMouseFromNode $stateMouseFromIdx $toNode $toIdx

                    if {$stateMouseFromNode ne $toNode || $stateMouseFromIdx != $toIdx} {
                        selection own $win
                    }
                }

                set stateMouseToNode $toNode
                set stateMouseToIdx  $toIdx
            } msg]

            # Note: node が削除される可能性があるから、とのこと。
            if {$rc && [regexp {[^ ]+ is an orphan} $msg]} {
                $me selection clear
            }
        }

        # XXX: scroll

    }

    method {selection toClipboard} {} {
        clipboard clear
        clipboard append [set s [$self selection get]]
    }

    method {selection get} {{maxChars 10000000}} {
        if {$stateMouseFromNode eq ""} return
        $self selection read 0 $maxChars
    }

    # XXX: Original ::hv3::hv3::selectionmanager::get_selection wrapped below
    # with ::hv3::bg, which capture ::errorCode/::errorInfo and resume
    # them [after idle]. I'm not exactly sure what requires it,
    # so I postpone implementing ::hv3::bg equiv here.
    method {selection read} {offset maxChars} {
        set t [$myHtml text text]

        set n1 $stateMouseFromNode
        set i1 $stateMouseFromIdx
        set n2 $stateMouseToNode
        set i2 $stateMouseToIdx

        set stridx_a [$myHtml text offset $stateMouseFromNode $stateMouseFromIdx]
        set stridx_b [$myHtml text offset $stateMouseToNode $stateMouseToIdx]
        if {$stridx_a > $stridx_b} {
            lassign [list $stridx_b $stridx_a] stridx_a stridx_b
        }

        set T [string range $t $stridx_a [expr $stridx_b - 1]]
        set T [string range $T $offset [expr $offset + $maxChars]]

        return $T
    }
}
