#
# These patched version of event handlers fixes "immediate unposting of select options"
#

namespace eval ::minhtmltk::form {
    ::variable ourMenubuttonFirstPost no
}


# Stolen from menubutton.tcl and patched

# TransferGrab (X11 only) --
#   Switch from pulldown mode (menubutton has an implicit grab)
#   to popdown mode (menu has an explicit grab).
#
proc ::minhtmltk::form::TransferGrab {mb {kind ""}} {
    # puts "Called ::minhtmltk::form::TransferGrab"
    if {[$mb cget -direction] eq "flush"} {
        set ::minhtmltk::form::ourMenubuttonFirstPost yes
    }
    variable ::ttk::menubutton::State
    if {$State(pulldown)} {
    $mb configure -cursor $State(oldcursor)
    $mb state {!pressed !active}
    set State(pulldown) 0

    set menu [$mb cget -menu]
    foreach {x y entry} [::ttk::menubutton::PostPosition $mb $menu] { break }
        tk_popup $menu [winfo rootx $menu] [winfo rooty $menu]
    }
}

# Stolen from menu.tcl and patched

proc ::minhtmltk::form::MenuInvoke {w buttonRelease} {
    # puts "called ::minhtmltk::form::MenuInvoke"
    variable ::tk::Priv

    if {$buttonRelease && $Priv(window) eq ""} {
        # Mouse was pressed over a menu without a menu button, then
        # dragged off the menu (possibly with a cascade posted) and
        # released.  Unpost everything and quit.

        $w postcascade none
        $w activate none
        event generate $w <<MenuSelect>>
        ::tk::MenuUnpost $w
        return
    }
    if {[$w type active] eq "cascade"} {
        $w postcascade active
        set menu [$w entrycget active -menu]
        ::tk::MenuFirstEntry $menu
    } elseif {[$w type active] eq "tearoff"} {
        ::tk::TearOffMenu $w
        ::tk::MenuUnpost $w
    } elseif {[$w cget -type] eq "menubar"} {
        $w postcascade none
        set active [$w index active]
        set isCascade [string equal [$w type $active] "cascade"]

        # Only de-activate the active item if it's a cascade; this prevents
        # the annoying "activation flicker" you otherwise get with
        # checkbuttons/commands/etc. on menubars

        if { $isCascade } {
            $w activate none
            event generate $w <<MenuSelect>>
        }

        ::tk::MenuUnpost $w

        # If the active item is not a cascade, invoke it.  This enables
        # the use of checkbuttons/commands/etc. on menubars (which is legal,
        # but not recommended)

        if { !$isCascade } {
            uplevel #0 [list $w invoke $active]
        }
    } else {
        set active [$w index active]
        if {$::minhtmltk::form::ourMenubuttonFirstPost} {
            set ::minhtmltk::form::ourMenubuttonFirstPost no
            return
        }
        if {$Priv(popup) eq "" || $active ne "none"} {
            ::tk::MenuUnpost $w
        }
        uplevel #0 [list $w invoke active]
    }
}
