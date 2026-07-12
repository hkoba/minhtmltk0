# -*- mode: tcl; coding: utf-8 -*-

namespace eval ::minhtmltk::taghelper {}

#
# Image loading support (-imagecmd) for minhtmltk. data: URIs are
# decoded inline; everything else is fetched via [$self nav read], so
# supported schemes follow the navigator. Loaded images are cached per
# URI; the cache is flushed by [image reset], which is called from the
# widget's Reset method.
#
snit::macro ::minhtmltk::taghelper::imagecmd {} {

    variable stateImageCache -array {}

    method {image install} {} {
        $myHtml configure -imagecmd [list $self image load]
    }

    method {image reset} {} {
        foreach {uri img} [array get stateImageCache] {
            catch {image delete $img}
        }
        array unset stateImageCache
        $self image install
    }

    # Called by Tkhtml for <img src=...>, css background-image url(...)
    # and -tkhtml-replacement-image. Returns a Tk photo image name, or
    # "" if the image can not be loaded.
    method {image load} uri {
        if {[info exists stateImageCache($uri)]} {
            return $stateImageCache($uri)
        }
        set img ""
        catch {set img [$self image create-from $uri]}
        if {$img ne ""} {
            set stateImageCache($uri) $img
        }
        return $img
    }

    method {image create-from} uri {
        if {[regexp {^data:image/[^;,]+;base64,(.*)$} $uri -> b64]} {
            # data: URIs may be %-encoded (e.g. %2F for '/').
            set b64 [::minhtmltk::taghelper::percent-decode $b64]
            return [image create photo -data $b64]
        }
        if {[regexp {^data:} $uri]} {
            return ""
        }
        # [nav read] dispatches on the URI scheme, so which schemes
        # work here follows the navigator (file only for localnav,
        # +http/https for webnav). Unsupported schemes and fetch
        # failures raise; [image load] catches them into "".
        set response [$self nav read $uri -mode binary]
        image create photo -data [dict get $response body]
    }
}

namespace eval ::minhtmltk::taghelper {
    # %XX decoding only ('+' is kept as-is; this is not a query string).
    proc percent-decode str {
        regsub -all {%([0-9A-Fa-f]{2})} $str {\\u00\1} str
        subst -novariables -nocommands $str
    }
}
