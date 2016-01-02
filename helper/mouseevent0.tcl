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

	set handlers [$self node event list-handlers $startNode $event]
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

    method {node event generatelist} evlist {
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
    method {node event list-handlers} {startNode event} {
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

	    foreach cmd $cmdlist {
		lappend result [list $event $node $cmd]
	    }

	} {*}$altList [list "" [$myHtml node]]

	set result
    }

    method install-mouse-handlers {} {
	bindtags $myHtml [linsert-lsearch [bindtags $myHtml] . \
			      $win $ourClass]

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
	# puts stderr click-nodelist=$nodelist
	set evlist {}
	foreach node $nodelist {
	    lappend evlist click $node
	}
	
	$self node event generatelist $evlist
    }
}
