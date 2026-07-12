# -*- mode: tcl; coding: utf-8 -*-
#
# Minimal in-process HTTP stub server for tests.
#
# Routes dict: path -> {status content-type body}
# For 3xx statuses the content-type slot holds the Location value.
#
# This server runs on the same event loop as the code under test.
# That is fine for the synchronous [http::geturl] used by http_scheme,
# since its internal vwait services our fileevents too.
#

namespace eval ::minhtmltk::test {

    variable httpdRoutes [dict create]
    variable httpdSock ""
    variable httpdPath ;# array: sock -> request path

    # Returns the port number (listens on 127.0.0.1, ephemeral port).
    proc httpd-start routes {
        variable httpdRoutes $routes
        variable httpdSock
        set httpdSock [socket -server [namespace code httpd-accept] \
                           -myaddr 127.0.0.1 0]
        lindex [fconfigure $httpdSock -sockname] 2
    }

    proc httpd-stop {} {
        variable httpdSock
        if {$httpdSock ne ""} {
            close $httpdSock
            set httpdSock ""
        }
    }

    proc httpd-accept {sock addr port} {
        fconfigure $sock -translation crlf -blocking 0
        fileevent $sock readable [namespace code [list httpd-serve $sock]]
    }

    proc httpd-serve sock {
        variable httpdPath
        while {[gets $sock line] >= 0} {
            if {![info exists httpdPath($sock)]} {
                # Request line: GET /path HTTP/1.1
                set httpdPath($sock) [lindex [split $line] 1]
            } elseif {$line eq ""} {
                # End of request headers.
                httpd-respond $sock $httpdPath($sock)
                unset httpdPath($sock)
                return
            }
        }
        if {[eof $sock]} {
            close $sock
            unset -nocomplain httpdPath($sock)
        }
    }

    proc httpd-respond {sock path} {
        variable httpdRoutes
        if {[dict exists $httpdRoutes $path]} {
            lassign [dict get $httpdRoutes $path] status ctype body
        } else {
            lassign [list 404 text/plain "not found: $path"] \
                status ctype body
        }
        set extra ""
        if {[string match 3* $status]} {
            # For redirects, the content-type slot holds Location.
            append extra "Location: $ctype\r\n"
            lassign [list text/plain ""] ctype body
        }
        fconfigure $sock -translation binary
        puts -nonewline $sock [join [list \
            "HTTP/1.1 $status MinhtmltkTest" \
            "Content-Type: $ctype" \
            "Content-Length: [string length $body]" \
            "Connection: close" \
        ] \r\n]\r\n$extra\r\n
        puts -nonewline $sock $body
        close $sock
    }
}
