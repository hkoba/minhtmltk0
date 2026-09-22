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
        if {$options(-debug-mouse-event) >= 3} {
            puts stderr [list Press: $w $x $y]
        }
        $self node event change allow __scope__
        focus $w

        adjust-coords-to $myHtml $w x y
        set nodelist [$myHtml node $x $y]
        # XXX: Selection handling, and its prevention
        if {$options(-debug-mouse-event) >= 2} {
            puts stderr [list Press: nodelist $nodelist]
        }

        foreach startNode $nodelist {
            set startNode [parent-of-textnode $startNode]
            for-upward-node node $startNode {
                dict set stateActiveNodes $node 1
            }
        }

        if {$options(-debug-mouse-event) >= 2} {
            puts stderr [list Press> stateActiveNodes: [dict keys $stateActiveNodes]]
        }

        set evlist {}
        foreach node [dict keys $stateActiveNodes] {
            $node dynamic set active
            lappend evlist mousedown $node
        }

        if {$options(-debug-mouse-event) >= 2} {
            puts stderr [list Press> evlist $evlist]
        }

        set rc [$self node event generatelist $evlist]

        # Start text selection only if click handler is empty
        if {[$self node event list-handlers [lindex $nodelist end] click] eq ""} {
            $self node event selection press $rc [lindex $nodelist end] $x $y
        }
    }

    method Release {w x y} {
        if {$options(-debug-mouse-event) >= 3} {
            puts stderr [list Release: $w $x $y]
        }

        $self node event change allow __scope__
        adjust-coords-to $myHtml $w x y
        set nodelist [$myHtml node $x $y]
        if {$options(-debug-mouse-event) >= 2} {
            puts stderr [list Release: nodelist $nodelist]
        }

        ::minhtmltk::utils::scope_guard nodeDict \
            [list $self node event selection release \
                 [lindex $nodelist end] $x $y]

        set evlist {}
        foreach startNode $nodelist {
            set startNode [parent-of-textnode $startNode]
            for-upward-node node $startNode {
                lappend evlist mouseup $node
                if {[dict exists $stateActiveNodes $node]} {
                    # Generate click event if node was active
                    dict unset stateActiveNodes $node
                    $node dynamic clear active
                    lappend evlist click $node
                }
            }
        }

        # Clear rest of dynamic active
        foreach node [dict keys $stateActiveNodes] {
            $node dynamic clear active
        }
        set stateActiveNodes [dict create]

        if {$options(-debug-mouse-event) >= 2} {
            puts stderr [list Release> evlist $evlist]
        }

        $self node event generatelist $evlist
    }

    method Motion {w x y} {
        if {$options(-debug-mouse-event) >= 3} {
            puts stderr [list Motion: $w $x $y]
        }

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

    #
    # Handlers registered with -persistent survive [Reset] (i.e. every
    # [load]): they are copied into stateTriggerDict again by
    # install-mouse-handlers, ahead of the built-in tag handlers. Keys
    # are "" (global), a tag or tag.class; node handles die with the
    # document and are rejected.
    #
    variable myPersistentTriggerDict [dict create]

    method {node event dump-handlers} {} {
        set stateTriggerDict
    }
    method {node event dump-persistent} {} {
        set myPersistentTriggerDict
    }

    #
    # Global event. This can be registered before parse.
    #
    #   $self on ?-persistent? EVENT COMMAND
    #
    method on {args} {
        set opts [lrange $args 0 end-2]
        lassign [lrange $args end-1 end] event command
        $self node event on {*}$opts "" $event $command
    }
    method trigger {event args} {
        $self node event trigger "" $event {*}$args
    }

    #
    # Node event.
    #
    method {node event add} {node event command} {
	$self node event on $node $event $command
    }
    method raise-if-strict-event msg {
	if {$options(-strict-event)} {
	    error $msg
	} else {
	    return -code return
	}
    }

    # Splits a leading -persistent off $args; returns 0 or 1.
    proc cut-persistent-opt {argsVar} {
        upvar 1 $argsVar args
        if {[lindex $args 0] eq "-persistent"} {
            set args [lrange $args 1 end]
            return 1
        }
        return 0
    }

    proc dict-list-get {dict args} {
        if {[dict exists $dict {*}$args]} {
            dict get $dict {*}$args
        }
    }

    option -strict-event no
    method {node event remove} {args} {
        set persistent [cut-persistent-opt args]
        lassign $args node event command
	if {![info exists ourEvDict($event)]} {
	    $self raise-if-strict-event "Unknown event name $event"
	}
        if {![dict exists $stateTriggerDict $node]} {
	    $self raise-if-strict-event "No events are known for $node"
	}
        if {![dict exists $stateTriggerDict $node $event]} {
	    $self raise-if-strict-event "No $event handlers are known for $node"
        }
        if {$persistent} {
            set plist [dict-list-get $myPersistentTriggerDict $node $event]
            if {[set pos [lsearch -exact $plist $command]] >= 0} {
                dict set myPersistentTriggerDict $node $event \
                    [lreplace $plist $pos $pos]
            }
        }
        set curList [dict get $stateTriggerDict $node $event]
        if {[set pos [lsearch -exact $curList $command]] >= 0} {
            dict set stateTriggerDict $node $event \
                [lreplace $curList $pos $pos]
        }
    }

    #
    #   $self node event on ?-persistent? NODE EVENT COMMAND
    #
    method {node event on} {args} {
        set persistent [cut-persistent-opt args]
        if {[llength $args] != 3} {
            error "Usage: node event on ?-persistent? node event command"
        }
        lassign $args node event command
        if {![info exists ourEvDict($event)]} {
            error "Unknown event name $event"
        }
        # Note: [dict with] can't be used here: it only writes back
        # variables that were keys at entry, so a handler for a new
        # event name on an existing node would be silently dropped.
        set curList [dict-list-get $stateTriggerDict $node $event]
        if {$persistent} {
            if {[string match ::tkhtml::node* $node]} {
                error "-persistent accepts \"\" (global), a tag or tag.class,\
 not a node handle: $node"
            }
            set plist [dict-list-get $myPersistentTriggerDict $node $event]
            # Persistent handlers sit in front of the others (see
            # install-mouse-handlers); keep that order here as well.
            set curList [linsert $curList [llength $plist] $command]
            lappend plist $command
            dict set myPersistentTriggerDict $node $event $plist
        } else {
            lappend curList $command
        }
        dict set stateTriggerDict $node $event $curList
    }

    #
    #   $self node event clear ?-persistent? NODE EVENT
    #
    method {node event clear} {args} {
        set persistent [cut-persistent-opt args]
        lassign $args node event
        if {$persistent} {
            dict set myPersistentTriggerDict $node $event {}
        }
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
            # Safer. A handler stops the remaining handlers with
            # [return -code break] (see [node event apply]).
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

    #
    # Runs one handler. [return -code break] inside the handler is
    # re-raised as a break of the caller's loop ([handlelist]), so the
    # remaining handlers for this event are skipped (like
    # stopImmediatePropagation). [return -code continue] just ends the
    # handler. Anything else (values, errors) is passed through.
    #
    method {node event apply} {event node cmd args} {
        # XXX: What kind of API should we have?
        set rc [catch {
            apply [list {self win selfns node this event args} $cmd] \
                $self $win $selfns $node $node $event {*}$args
        } result opts]
        switch $rc {
            3 { return -code break }
            4 { return }
            default { return -options $opts $result }
        }
    }

    #
    # $evlist is a flat {event node ...} list, innermost node first for
    # each event (see Press/Release). Tag/class handlers bubble: each
    # ancestor gets its own call. Global handlers are looked up only for
    # the first (innermost) node of each event, so [$self on click ...]
    # runs once per click with $node = the innermost target, as a
    # document-level listener does in a browser.
    #
    method {node event generatelist} evlist {
        set handlers {}
        array set seen {}
        array set firstSeen {}
        foreach {event node} $evlist {
            set withGlobal [expr {![info exists firstSeen($event)]}]
            set firstSeen($event) 1
            foreach spec [$self node event list-handlers \
                              $node $event "" $withGlobal] {
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
    # Handler lookup for one (node, event):
    #
    #   1. node-level handlers of $startNode itself, if any; otherwise
    #   2. tag.class and tag handlers matching $startNode
    #      (when -generate-tag-class-event is yes);
    #   3. global handlers ([$self on ...]), once, with $node bound to
    #      $startNode (or the root node when $startNode is "").
    #
    # Node-level handlers shadow tag/class ones. Global handlers are
    # independent of 1 and 2 and are always included unless $withGlobal
    # is 0 (generatelist passes 0 for all but the innermost node).
    #
    option -generate-tag-class-event yes
    method {node event list-handlers} {startNode event {arglist ""} {withGlobal 1}} {

        if {$startNode ne ""} {
            set startNode [parent-of-textnode $startNode]
        }
        set nodeSpecList [if {$startNode eq ""} {
            list
        } elseif {[dict exists $stateTriggerDict $startNode $event]
                  && [dict get $stateTriggerDict $startNode $event] ne ""} {
            list [list $startNode $startNode]
        } elseif {$options(-generate-tag-class-event)} {
            tag-class-list-of-node $startNode
        } else {
            list
        }]

        set result []
        foreach nspec $nodeSpecList {
            # nspec = [list key node], where key is the node itself
            # or a tag/tag.class name.
            set key  [lindex $nspec 0]
            set node [lindex $nspec end]

            if {![dict-getvar $stateTriggerDict $key $event cmdlist]} continue

            if {$options(-debug-mouse-event) >= 3} {
                puts "list-handlers($node $key $event) => cmdlist($cmdlist)"
            }

            foreach cmd $cmdlist {
                lappend result [list $event $node $cmd {*}$arglist]
            }
        }

        # global event
        if {$withGlobal
            && [dict-getvar $stateTriggerDict "" $event cmdlist]} {
            set node [if {$startNode ne ""} {
                set startNode
            } else {
                $myHtml node
            }]
            foreach cmd $cmdlist {
                lappend result [list $event $node $cmd {*}$arglist]
            }
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
        # Re-install persistent handlers first, so that they run before
        # the built-in tag handlers below (and can [return -code break]
        # to prevent the default action, e.g. <a> navigation).
        #
        dict for {node evDict} $myPersistentTriggerDict {
            dict for {event cmdList} $evDict {
                foreach cmd $cmdList {
                    $self node event on $node $event $cmd
                }
            }
        }

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
        if {$options(-debug-mouse-event) >= 2} {
            puts stderr [list selection-press successEv $successEv $node $x $y]
        }

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
        if {$options(-debug-mouse-event) >= 2} {
            puts stderr [list selection-release $node $x $y]
        }

        set stateMouseDown ""
    }

    method {selection exists} {} {
        expr {$stateMouseFromNode ne "" && $stateMouseToNode ne ""}
    }
    method {selection clear} {} {
        # node is ignored.

        $myHtml tag delete selection
        $myHtml tag configure selection \
            -foreground white -background darkgrey
        set stateMouseFromNode ""
        set stateMouseToNode ""
        
        # Memo: stateMouseFromNode が "" にされた時に backtrace を出す
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
        if {$options(-debug-mouse-event) >= 3} {
            puts [list selection-adjust $node $x $y]
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
