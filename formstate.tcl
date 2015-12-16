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
        editable no
    }
    
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
    method {item of-name} {name {kind ""}} {
        set vn myNameDict($name)
        if {[info exists $vn]} {
            set item [set $vn]
            set oldKind [set ${item}(type)]
            if {$kind ne "" && $oldKind ne $kind} {
                error "item type mismatch! was:'$oldKind' new:'$kind' for name=$name"
            }
        } else {
            set escaped [string map {: _} $name]
            set item ${selfns}::#$escaped
            lappend myNameList $name
            set $vn $item
            array set $item $ourItemSlots
            set ${item}(name) $name
            set ${item}(type) $kind
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
    method {item is editable} item { set ${item}(editable) }
    method {item valuelist} item { set ${item}(valueList) }
    # method {item nodelist} item { set ${item}(nodeList) }
    # method {item optlist} item { set ${item}(optList) }

    #
    # Caller must explicitly give required slots of opts.
    # (Because I don't want to rely on [$node attr] API from this class).
    #
    method {item register node} {kind node opts} {
        set name [dict-cut opts name]
        set item [$self item of-name $name $kind]
        set vn ${item}(type)
        if {[dict exists $opts value]} {
            set value [dict get $opts value]
            dict set ${item}(value2IxDict) $value \
                [llength [set ${item}(valueList)]]
            lappend ${item}(valueList) $value
            lappend ${item}(labelList) [dict-cut opts label ""]
        } else {
            set ${item}(editable) [dict-cut opts editable no]
        }
        lappend ${item}(nodeList) $node
        lappend ${item}(optList) $opts
        set item
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
        if {![$self item is editable $item]
            && $value ni [$self item valuelist $item]} {
            $self log error unknown value for $options(-name).[$self item name $item]
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
    method {item multi set} {item args} {
        set knownDict [set ${item}(value2IxDict)]
        foreach value $args {
            if {[dict exists $knownDict $value]} {
                set [$self item var $item $value] 1
                dict unset knownDict $value
            }
        }
        foreach value [dict keys $knownDict] {
            set [$self item var $item $value] 0     
        }
        set args
    }
}
