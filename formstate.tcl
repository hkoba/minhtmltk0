#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec tclsh -encoding utf-8 "$0" ${1+"$@"}

package require snit

source [file dirname [info script]]/utils.tcl

namespace eval ::minhtmltk::formstate {
    namespace import ::minhtmltk::utils::*
}

snit::type ::minhtmltk::formstate {
    option -name ""
    option -action ""

    option -data ""; # Other "satellite" data from Dynamic HTML.
    option -outer-data ""; # Other "satellite" data from User.

    option -node ""
    option -logger ""

    variable myNameList {}
    variable myNameDict -array {}
    
    typevariable ourItemSlots {
        name {}
        type {}
        valueList {}
        value2IxDict {}
        labelList {}
        nodeList {}
        optList {}
        gettable no
        disabled no
        has-choice no
    }
    
    # has-choice denotes it has predefined list of choices.
    # if this is false, value could be anything (free answer).

    typemethod {slot names} {} {
        array names ourItemSlots
    }

    variable myLog
    method log {kind args} {
        if {$options(-logger) ne ""} {
            $options(-logger) $kind {*}$args
        } else {
            error [list $kind {*}$args]
        }
    }

    method names {} {
        set myNameList
    }

    # Note: this can't be used for QUERY_STRING
    method get {} {
        set result {}
        foreach name [$self names] {
            set item [$self item of-name $name]
            if {![$self item is gettable $item]} continue
            if {![$item get value]} continue
            lappend result $name $value
        }
        set result
    }

    method {item is gettable} item { set ${item}(gettable) }

    # Each form variable has array with same name, prefixed by '#'.
    method {item of-name} {name {kind ""} {has_choice ""}} {
        set vn myNameDict($name)
        if {[info exists $vn]} {
            set item [set $vn]
            set oldKind [set ${item}(type)]
            if {$kind ne "" && $oldKind ne $kind} {
                error "item type mismatch! was:'$oldKind' new:'$kind' for name=$name"
            }
            set oldHasChoice [set ${item}(has-choice)]
            if {$has_choice ne "" && $oldHasChoice ne $has_choice} {
                error "item property(has-choice) mismatch! was: '$oldHasChoice' new: $has_choice for name=$name"
            }
        } else {
            set escaped [string map {: _} $name]
            set item ${selfns}::#$escaped
            lappend myNameList $name
            set $vn $item
            array set $item $ourItemSlots
            set ${item}(name) $name
            set ${item}(type) $kind
            set ${item}(has-choice) $has_choice
            if {[llength [$self info methods [list item $kind get]]]} {
                set ${item}(gettable) yes
                interp alias {} $item \
                    {} apply [list {self kind item method args} {
                        uplevel 1 [list $self item $kind $method $item {*}$args]
                    }] $self $kind $item
            }
        }
        set item
    }

    # For multiple choice(checkbox & select multi), each flags are
    # held as array element, prefixed by '#'.
    # The flag can be empty.
    method {item var} {item {value ""}} {
        return ${item}(#$value)
    }
    
    method {item type} item { set ${item}(type) }
    method {item name} item { set ${item}(name) }
    method {item has-choice} item { set ${item}(has-choice) }
    method {item valuelist} item { set ${item}(valueList) }
    method {item nodelist} item { set ${item}(nodeList) }
    # method {item optlist} item { set ${item}(optList) }

    #
    # Caller must explicitly give required slots of opts.
    # (Because I don't want to rely on [$node attr] API from this class).
    #
    method {item register node} {kind node opts} {
        set name [dict-cut opts name]
        set has_value [dict exists $opts value]
        set value [dict-cut opts value ""]
        set item [$self item of-name $name $kind \
                      [dict-cut opts has-choice no]]
        set vn ${item}(type)
        if {[$self item has-choice $item]} {
            dict set ${item}(value2IxDict) $value \
                [llength [set ${item}(valueList)]]
            lappend ${item}(valueList) $value
            lappend ${item}(labelList) [dict-cut opts label ""]
        } elseif {$has_value} {
            set [$self item var $item] $value
        }
        lappend ${item}(nodeList) $node
        lappend ${item}(optList) [dict-cut opts option ""]
        if {[dict size $opts]} {
            error "Unknown option for item(name=$name): opts=$opts"
        }
        set item
    }
    
    #
    # Note: [item $kind $method] can't have multi word method name
    # because of calling convention of interp alias.
    # That is why belows are named node-at, node-widget-at
    # and not "node at", "node widget at".
    #
    foreach kind [list single multi] {
        method [list item $kind nodelist] item {set ${item}(nodeList)}
        method [list item $kind node-at] {item nth} {
            lindex [set ${item}(nodeList)] $nth
        }
        method [list item $kind node-widget-at] {item nth} {
            [lindex [set ${item}(nodeList)] $nth] replace
        }
    }

    method {item single unset} {item} {
        unset [$self item var $item]
    }
    method {item single get} {item {outVar ""}} {
        set vn [$self item var $item]
        if {$outVar ne ""} {
            if {[set rc [info exists $vn]]} {
                upvar 1 $outVar out
                set out [set $vn]
            }
            set rc
        } else {
            set $vn
        }
    }

    method {item single set} {item value} {
        set vn [$self item var $item]
        if {[$self item has-choice $item]
            && $value ni [$self item valuelist $item]} {
            $self log error unknown value "($value)" for $options(-name).[$self item name $item]
        }
        set $vn $value
    }

    method {item multi get} {item {outVar ""}} {
        set result {}
        foreach value [$self item valuelist $item] {
            if {[default [$self item var $item $value] no]} {
                lappend result $value
            }
        }
        if {$outVar ne ""} {
            upvar 1 $outVar out
            set out $result
            llength $result
        } else {
            set result
        }
    }
    method {item multi set} {item values} {
        set knownDict [set ${item}(value2IxDict)]
        foreach value $values {
            if {[dict exists $knownDict $value]} {
                set [$self item var $item $value] 1
                dict unset knownDict $value
            }
        }
        foreach value [dict keys $knownDict] {
            set [$self item var $item $value] 0     
        }
        set values
    }
}
