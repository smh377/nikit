set writer 0
foreach {k v} $argv {
    set [string trim $k -] $v
}

lappend auto_path [file dirname [info script]] [file dirname [file dirname [info script]]]/lib

package require MkUp
package require SCGIWiki
package require WDB_sqlite
package require Wiki
package require WikiUtils
package require scgi

set WikiDatabase [file dirname [file dirname [info script]]]/local.tkd
if {![file readable $WikiDatabase]} {
    set WikiDatabase [file dirname [file dirname [info script]]]/nikit.tkd
}
puts stderr "Using database $WikiDatabase"
WDB WikiDatabase readonly [expr {!$writer}] file $WikiDatabase

set LinkDatabase [file dirname [file dirname [info script]]]/rlinks.tkd
if {[file readable $LinkDatabase]} {
    puts stderr "Using link database $LinkDatabase"
    WDB LinkDatabase file $LinkDatabase
}

proc handle_request {sock headers body} {

#    puts "####################################################################################################"
#    foreach header $headers { puts $header }
#    puts "----------------------------------------------------------------------------------------------------"
#    puts $body
#    puts "####################################################################################################"

    set cgi [SCGIWiki new sock $sock headers $headers body $body]
    set wikiserver [Wiki new cgi $cgi server_name localhost read_only 0 writer $::writer]
    $cgi configure server $wikiserver
    $cgi process
    $cgi destroy
    $wikiserver destroy
    close $sock
}

scgi::listen [expr {$writer ? 9998 : 9999}]
vwait forever
