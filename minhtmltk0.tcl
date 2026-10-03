#!/bin/sh
# -*- mode: tcl; coding: utf-8 -*-
# the next line restarts using tclsh \
    exec wish -encoding utf-8 "$0" ${1+"$@"}

package require Tkhtml 3
package require snit
package require widget::scrolledwindow; # for <textarea> (taghelper/form.tcl)
#package require BWidget

source [file dirname [info script]]/utils.tcl

namespace eval ::minhtmltk {
    namespace import ::minhtmltk::utils::*

    # Keep in sync with pkgIndex.tcl and python/pyproject.toml.
    # ([set], not [variable]: once the snit type exists, this
    # namespace has its own [variable] command.)
    set ::minhtmltk::version 0.2
}

source [file dirname [info script]]/formstate1.tcl
source [file dirname [info script]]/query-string.tcl

source [file dirname [info script]]/taghelper.tcl

source [file dirname [info script]]/navigator/localnav.tcl
source [file dirname [info script]]/navigator/webnav.tcl

snit::widget minhtmltk {
    ::minhtmltk::taghelper::start

    typevariable ourClass Minhtmltk

    component myHtml -inherit yes
    variable stateStyleList

    option -encoding ""

    # Used from include/script-tag.tcl, to expose custom $self to tcl <script>
    option -script-self ""
    option -script-type [list text/x-tcl text/tcl tcl]

    # Whether document-supplied Tcl (<script type="tcl">, on<event>
    # attributes) may run. "" means: decided in the constructor from
    # whether -navigator was given explicitly.
    option -allow-script ""

    typevariable ourTtkDefaultBackground white
    typevariable ourTtkDefaultActiveBackground white
    typevariable ourTtkClassMap [dict create {*}{
        checkbutton TCheckbutton
        radiobutton TRadiobutton
        button      TButton
    }]

    # $self for script/event handlers
    method script-self {} {
        if {$options(-script-self) ne ""} {
            set options(-script-self)
        } else {
            set self
        }
    }

    component myURINavigator -public nav
    delegate option -uri to myURINavigator as -uri
    delegate option -file to myURINavigator as -uri
    delegate option -home to myURINavigator
    delegate option -scheme-command to myURINavigator
    delegate method location to myURINavigator

    option -html ""

    option -install-default-handlers yes

    # Which scrollbars exist (creation-time only), and which of them
    # are hidden while the document fits: both|vertical|horizontal|none.
    option -scrollbar -default both -readonly yes \
        -type {snit::enum -values {both vertical horizontal none}}
    option -auto -default both -configuremethod Configure-auto \
        -type {snit::enum -values {both vertical horizontal none}}

    variable myLogHistory [list]
    variable stateCurrentLog [list]

    typeconstructor {
        if {[ttk::style theme use] eq "default"} {
            ttk::style theme use clam
        }

        $type fixup-ttk-style

        $type fixup-select-single-mouseup

        bind $ourClass <<DocumentReady>> {%W trigger ready}
    }

    typemethod ttk-style-get key {
        dict get $ourTtkClassMap $key
    }

    typemethod ensure-ttk-style-is-fixed {} {
        set config [::ttk::style configure \
                        [dict get $ourTtkClassMap radiobutton]]
        if {[dict-default $config -background] ne $ourTtkDefaultBackground} {
            $type fixup-ttk-style
        }
    }

    typemethod fixup-ttk-style {} {
        foreach widget [dict keys $ourTtkClassMap] {
            set style [dict get $ourTtkClassMap $widget]
            if {[::ttk::style configure $style] eq ""} {
                # puts [list setting style for $style]
                set parent T[string totitle $widget]
                ::ttk::style configure $style \
                    {*}[::ttk::style configure $parent]
            }
            ::ttk::style configure $style \
                -background $ourTtkDefaultBackground \
                -activebackground  $ourTtkDefaultActiveBackground
            # puts [list style $style [::ttk::style configure $style]]
        }
    }

    #========================================
    # Debugging aid
    method myvar varName { myvar $varName }

    constructor args {
        $type ensure-ttk-style-is-fixed

        if {[set nav [from args -navigator ""]] ne ""} {
            if {[info commands $nav] eq ""
                && [info commands ::minhtmltk::navigator::$nav] ne ""} {
                # -navigator also accepts a navigator type name
                # (e.g. webnav), useful from the command line.
                set nav [::minhtmltk::navigator::$nav ${selfns}::navigator]
            }
            install myURINavigator using set nav
        } else {
            install myURINavigator \
                using ::minhtmltk::navigator::localnav ${selfns}::navigator
            # puts "navigator is created!>>>"
            # trace add command $myURINavigator delete \
            #     [list apply {args {
            #         getBackTrace bt
            #         puts "navigator is deleted!<<<\nbacktrace=$bt"
            #     }}]
        }
        $myURINavigator setwidget $win

        # A widget with the default navigator only sees local files,
        # so document scripts stay allowed as before. An explicitly
        # passed navigator (e.g. webnav) may reach untrusted remote
        # documents, so they default to no.
        if {[set allowScript [from args -allow-script ""]] eq ""} {
            set allowScript [expr {$nav eq "" ? "yes" : "no"}]
        }
        set options(-allow-script) $allowScript

        set options(-scrollbar) [from args -scrollbar both]
        set options(-auto) [from args -auto both]
        install myHtml using html $win.html
        $self scroll install

        if {[from args -install-default-handlers yes]} {
            $self Reset
        }

        $self configurelist $args

        if {[$self location get] eq ""} {
            $self nav gotoHome
        }
    }

    #========================================
    # Scrollbars
    #
    # They are managed here, directly in the hull, rather than by
    # widget::scrolledwindow: that saves one mapped window per widget,
    # and its auto-hide runs [update idletasks] from inside the
    # -yscrollcommand, which re-enters Tkhtml's update callback and
    # makes it lose pending scroll/redraw requests (e.g. a [See] right
    # after [load]). Here a scrollbar is only gridded/removed; the
    # resulting geometry change is handled later by the event loop.
    #========================================

    typevariable ourScrollbarSpec {
        y {name vscroll orient vertical   view yview row 0 column 1 sticky ns}
        x {name hscroll orient horizontal view xview row 1 column 0 sticky ew}
    }
    variable myScrollbarShown -array {x 0 y 0}

    method {scroll install} {} {
        grid $myHtml -row 0 -column 0 -sticky news
        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 0 -weight 1
        dict for {axis spec} $ourScrollbarSpec {
            dict with spec {}
            if {$options(-scrollbar) ni [list both $orient]} continue
            ttk::scrollbar $win.$name -orient $orient -takefocus 0 \
                -command [list $myHtml $view]
            $myHtml configure -${axis}scrollcommand \
                [list $self scroll set $axis]
            $self scroll update $axis
        }
    }

    # The -xscrollcommand/-yscrollcommand of the Tkhtml widget.
    method {scroll set} {axis first last} {
        $win.[dict get $ourScrollbarSpec $axis name] set $first $last
        $self scroll update $axis
    }

    # Show or hide the scrollbar of $axis according to -auto.
    method {scroll update} axis {
        dict with ourScrollbarSpec $axis {}
        set sb $win.$name
        if {![winfo exists $sb]} return
        lassign [$sb get] first last
        set show [expr {$options(-auto) ni [list both $orient]
                        || $first > 0 || $last < 1}]
        if {$show == $myScrollbarShown($axis)} return
        set myScrollbarShown($axis) $show
        if {$show} {
            grid $sb -row $row -column $column -sticky $sticky
        } else {
            grid remove $sb
        }
    }

    method Configure-auto {option value} {
        set options($option) $value
        foreach axis {x y} {
            $self scroll update $axis
        }
    }

    # The scrollbar widget of $axis (x or y), or "" if it was not created.
    method {scroll bar} axis {
        set sb $win.[dict get $ourScrollbarSpec $axis name]
        expr {[winfo exists $sb] ? $sb : ""}
    }

    destructor {
        safe_destroy $myURINavigator
    }
    proc safe_destroy obj {
        if {$obj ne "" && [info commands $obj] ne ""} {
            rename $obj ""
        }
    }

    onconfigure -html html {
        $self load "" $html
    }

    method interactive {} {

        $self install-html-handlers
        
        bindtags $myHtml [luniq [linsert-lsearch [bindtags $myHtml] \
                                     [winfo toplevel $win] \
                                     $win $ourClass]]

        $self install-mouse-handlers

        $self install-keyboard-handlers

        $self install-wheel-handlers
    }
    
    method html args {
        if {$args eq ""} {
            set myHtml
        } else {
            $myHtml {*}$args
        }
    }

    #----------------------------------------
    
    option -emit-ready-immediately no

    variable stateHtmlSource ""
    variable stateDocumentReady ""
    method parse args {
        append stateHtmlSource [lindex $args end]
        $myHtml parse {*}$args
        if {[lindex $args 0] eq "-final"} {
            set stateDocumentReady yes
            set cmd [list event generate $win <<DocumentReady>>]
            # This cmd will call [$self node event trigger "" ready]
            if {$options(-emit-ready-immediately)} {
                {*}$cmd
            } else {
                after idle $cmd
            }
        }
    }

    method {state is DocumentReady} {} {
        expr {$stateDocumentReady ne ""}
    }

    method {state source} {} {
        set stateHtmlSource
    }

    variable stateQueryParameterDict [list]
    method {state parameter set} dict {
        set stateQueryParameterDict $dict
    }
    method {state parameter merge} qslist {
        set stateQueryParameterDict \
            [dict merge $stateQueryParameterDict [qslist2dict $qslist]]
    }
    method {state parameter exists} name {
        dict exists $stateQueryParameterDict $name
    }
    method {state parameter get} name {
        dict get $stateQueryParameterDict $name
    }
    method {state parameter default} {name {default ""}} {
        if {[dict exists $stateQueryParameterDict $name]} {
            dict get $stateQueryParameterDict $name
        } else {
            set default
        }
    }

    #
    # [load] = content replacement (+ location/history update).
    # Content fetching is not done here; that is [$self nav read]
    # (see navigator/common_macro.tcl for the naming convention).
    #
    method load {uri html args} {
        set params [from args -parameter ""]
        set histMode [from args -history push]
        $self Reset
        $self configurelist $args
        $myURINavigator location load $uri
        set query [$myURINavigator location query]
        if {[catch {qs2dict $query} dict]} {
            $self logger error "Parse error in query string: $dict: $query"
        } else {
            $self state parameter set $dict
        }
        if {$params ne ""} {
            $self state parameter merge $params
        }
        $self parse -final $html
        $myURINavigator history $histMode $uri
    }

    # Deprecated older name of [load].
    method replace_location_html {uri html args} {
        $self load $uri $html {*}$args
    }

    method Reset {} {
        $myHtml reset
        $self image reset
        foreach form [list {*}$stateFormList $stateOuterForm] {
            if {$form eq ""} continue
            $form destroy
        }
	# XXX: commands <= for tQuery
        foreach stVar [info vars ${selfns}::state*] {
            if {[array exists $stVar]} {
                array unset $stVar
            } else {
                set $stVar ""
            }
        }

        # Reinstall default tag/event handlers
        $self interactive
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

    ::minhtmltk::taghelper errorlogger

    ::minhtmltk::taghelper form
    ::minhtmltk::taghelper style
    ::minhtmltk::taghelper anchor
    ::minhtmltk::taghelper link
    ::minhtmltk::taghelper imagecmd
    ::minhtmltk::taghelper object
    ::minhtmltk::taghelper details

    # To be handled
    list {
        button
        iframe menu
        base meta title embed
    }

    method install-html-handlers {} {
        foreach {kind tag handler} [::minhtmltk::taghelper::handledTags] {
            if {$handler ne ""} {
                set meth [list add $handler]
            } else {
                set meth [list add $kind $tag]
            }
            if {![llength [$self info methods $meth]]} {
                error "Can't find tag handler for $tag"
            }
            set cmd [list handler $kind $tag [list $self logged {*}$meth]]
            # puts $cmd
            $myHtml {*}$cmd
        }
    }

    #========================================
    # mouse event handling
    #========================================

    ::minhtmltk::taghelper mouseevent0
    
    #========================================
    # keyboard event handling
    #========================================

    # Keyboard focus is not taken here (this runs on every [load]);
    # the widget gets it when it is clicked (see Press).
    method install-keyboard-handlers {} {
        bind $win <KeyPress-Up>     [list $myHtml yview scroll -1 units]
        bind $win <KeyPress-Down>   [list $myHtml yview scroll  1 units]
        bind $win <KeyPress-Return> [list $myHtml yview scroll  1 units]
        bind $win <KeyPress-Right>  [list $myHtml xview scroll  1 units]
        bind $win <KeyPress-Left>   [list $myHtml xview scroll -1 units]
        bind $win <KeyPress-Next>   [list $myHtml yview scroll  1 pages]
        bind $win <KeyPress-space>  [list $myHtml yview scroll  1 pages]
        bind $win <KeyPress-Prior>  [list $myHtml yview scroll -1 pages]

        bind $win <Alt-Right> [list $myURINavigator history go-offset +1]
        bind $win <Alt-Left> [list $myURINavigator history go-offset -1]
    }

    method install-wheel-handlers {} {
        # Tk 8.7+/9 (TIP 474): every platform delivers <MouseWheel> to
        # the window under the pointer; one wheel notch is +/-120 in %D
        # (touchpads may send smaller deltas).
        bind $win <MouseWheel>       [list $self wheel scroll yview %D]
        bind $win <Shift-MouseWheel> [list $self wheel scroll xview %D]

        # Tk 8.6 on X11 sends <Button-4>/<Button-5> instead. Some
        # Tkhtml builds already scroll on them via their Html class
        # bindings; add ours only when they don't, to avoid scrolling
        # twice per notch.
        if {[bind Html <Button-4>] eq ""} {
            bind $win <Button-4> [list $self wheel scroll yview  120]
            bind $win <Button-5> [list $self wheel scroll yview -120]
        }
    }

    variable stateWheelPending ""

    method {wheel scroll} {view delta} {
        set units [expr {-$delta / 40}]
        if {$units == 0 && $delta != 0} {
            set units [expr {$delta < 0 ? 1 : -1}]
        }
        # Tkhtml applies [$view scroll] at idle time, starting from the
        # already-applied offset; back-to-back calls before that idle
        # overwrite each other, so fast wheel spins would lose notches.
        # Accumulate here and issue a single call per idle round.
        # (catch: the widget may be destroyed before the idle fires)
        if {$stateWheelPending eq ""} {
            after idle [list catch [list $self wheel flush]]
        }
        dict incr stateWheelPending $view $units
    }

    method {wheel flush} {} {
        set pending $stateWheelPending
        set stateWheelPending ""
        foreach {view units} $pending {
            $myHtml $view scroll $units units
        }
    }

    #========================================
    # Misc.
    #========================================

    method See {node_or_selector {now no}} {
        set node [if {[regexp ^::tkhtml::node $node_or_selector]} {
            set node_or_selector
        } else {
            lindex [$self search $node_or_selector] 0
        }]
        # puts Seeing-$node_or_selector->$node
        if {$node eq ""} {
            return 0
        }
        $self yview $node
        return 1
    }

    #========================================
    typevariable ourHtmlSelectButton HtmlSelectSingleButton
    typevariable ourHtmlSelectMenu   HtmlSelectSingleMenu
    typemethod fixup-select-single-mouseup {} {
        set evList {"<ButtonRelease-1>" "<B1-Leave>"}
        set class $ourHtmlSelectButton
        clone-tk-bind TMenubutton $class \
            except $evList
        foreach ev $evList {
            bind $class $ev {::minhtmltk::form::TransferGrab %W}
        }

        set evList {"<ButtonRelease>"}
        set class $ourHtmlSelectMenu
        clone-tk-bind Menu $class \
            except $evList
        foreach ev $evList {
            bind $class $ev {::minhtmltk::form::MenuInvoke %W 1}
        }
    }
}

if {![info level] && [info exists ::argv0]
    && [info script] eq $::argv0} {

    # Load the extras (e.g. the <script type="tcl"> handler) before
    # the widget is created, so that they also apply to the initial
    # --file/--uri document.
    foreach inc [glob [file dirname [info script]]/include/*.tcl] {
        source $inc
    }

    snit::method minhtmltk Open {file args} {
        $self nav loadURI $file {*}$args
    }

    pack [minhtmltk .win {*}[minhtmltk::parsePosixOpts ::argv]] \
        -fill both -expand yes
    focus .win

    if {$::argv ne ""} {
        puts [.win {*}$::argv]
    }
}

package provide minhtmltk $::minhtmltk::version

list ::minhtmltk

