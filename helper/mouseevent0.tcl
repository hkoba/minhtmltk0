# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::helper {}

snit::macro ::minhtmltk::helper::mouseevent0 {} {

    #========================================
    # mouse event handling, salvaged and extended from ::hv3::hv3::mousemanager
    #========================================

    set evlist [list \
		    ready \
		    submit \
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
	if {[dict exists $stateTriggerDict $node $ourEvDict($event)]} {
	    $self error add "Replacing handler for $event with $command"
	}
	dict set stateTriggerDict $node $ourEvDict($event) $command
	# puts stateTriggerDict=$stateTriggerDict
    }

    method {node event trigger} {startNode event args} {

	set handlers [$self node event list-handlers $startNode $event]
	# puts startNode=$startNode,[if {$startNode ne ""} {
	#     list tag=[$startNode tag]
	# }],event=$event,handlers=$handlers

	foreach {node cmd} $handlers {

	    # XXX: What kind of API should we have?
	    apply [list {self win selfns node args} $cmd] \
		$self $win $selfns $node {*}$args
	}
    }
    
    method {node event dump-handlers} {} {
	set stateTriggerDict
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

	    # puts stderr looking=$key-$event,in=$stateTriggerDict
	    if {![dict-getvar $stateTriggerDict $key $event cmd]} continue

	    lappend result $node $cmd

	} {*}$altList [list "" [$myHtml node]]

	set result
    }

    method install-mouse-handlers {} {
	bindtags $myHtml [linsert-lsearch [bindtags $myHtml] . \
			      $win $ourClass]

	bind $win <ButtonPress-1>   +[mymethod Press   %W %x %y]
	bind $win <Motion>          +[mymethod Motion  %W %x %y]
	bind $win <ButtonRelease-1> +[mymethod Release %W %x %y]
	
	$self node event on a click {
	    
	    if {[set href [$node attr -default "" href]] eq ""} return
	    
	    if {[regexp ^\# $href]} {
		$self See $href
	    } else {
		puts stderr "Not yet implemented: href=$href"
	    }
	}

	$self node event on label click {
	    # puts stderr label-clicked:$node,tag=[$node tag]

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
	
	$self event generatelist $evlist
    }
    method {event generatelist} evlist {
	foreach {event node} $evlist {
	    $self node event trigger $node $event
	}
    }
}
