#!/usr/bin/tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit
package require http

namespace eval ::minhtmltk::navigator {
    #
    # https needs the tls package. Registration is deferred to first
    # use so that plain http keeps working without tls installed.
    #
    variable ourHttpsRegistered 0

    proc ensure-https-registered {} {
        variable ourHttpsRegistered
        if {$ourHttpsRegistered} return
        package require tls
        http::register https 443 [list ::tls::socket -autoservername 1]
        set ourHttpsRegistered 1
    }

    # [http::meta] returns header/value pairs; header names are matched
    # case-insensitively.
    proc header-get {meta name {default ""}} {
        set name [string tolower $name]
        foreach {k v} $meta {
            if {[string tolower $k] eq $name} {
                return $v
            }
        }
        return $default
    }
}

snit::macro ::minhtmltk::navigator::http_scheme {} {

    typevariable ourMaxRedirect 5

    #
    # [scheme http read] fetches content only and returns a response
    # dict {uri content-type status body}, like [scheme file read].
    #
    # This is synchronous: [http::geturl] without -command still runs
    # the event loop (internal vwait), so the UI stays responsive.
    #
    method {scheme http read} {uriObj args} {
        set mode    [from args -mode text]
        set timeout [from args -timeout 30000]

        set geturlOpts [list -timeout $timeout]
        if {$mode eq "binary"} {
            lappend geturlOpts -binary 1
        }

        set uri [$uriObj get]
        for {set nth 0} {$nth <= $ourMaxRedirect} {incr nth} {
            set token [http::geturl $uri {*}$geturlOpts]
            # Each iteration adds one more unset trace; every token is
            # cleaned up when this method scope ends.
            ::minhtmltk::utils::scope_guard token [list http::cleanup $token]

            if {[http::status $token] ne "ok"} {
                error "HTTP fetch failed ([http::status $token]): $uri"
            }

            set code [http::ncode $token]
            if {$code in {301 302 303 307 308}} {
                set location [::minhtmltk::navigator::header-get \
                                  [http::meta $token] location]
                if {$location eq ""} {
                    error "HTTP $code without Location: $uri"
                }
                # Location may be relative; resolve against current uri.
                set uri [$self resolve $location $uri]
                continue
            }
            if {![string match 2* $code]} {
                error "HTTP $code: $uri"
            }

            return [dict create \
                        uri $uri \
                        content-type [::minhtmltk::navigator::header-get \
                                          [http::meta $token] content-type] \
                        status $code \
                        body [http::data $token]]
        }
        error "Too many redirects: $uri"
    }

    method {scheme https read} {uriObj args} {
        ::minhtmltk::navigator::ensure-https-registered
        $self scheme http read $uriObj {*}$args
    }
}
