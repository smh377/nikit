# Script to create database with information about the external links used in the Wiki pages
#
# Usage:
#
#     tclsh rlinks.tcl <args>
#
# Arguments:
#
#     linkdb <path>        : path to database with link information
#     wikidb <path>        : path to database with wiki data
#     create_table <bool>  : create the link info table
#     update_table <bool>  : extract link info from wiki data and add it to the link info table
#     check_links <bool>   : check if the links exist
#     show_stats <bool>    : print some stats
#     max_checks <int>     : maximum number of links to check
#     update_usage <bool>  : (re-)create the table containing info in which wiki page a link is used

lappend auto_path [file dirname [info script]]

package require tdbc::sqlite3
package require http
package require uri
package require WFormat

set create_table 0
set update_table 0
set check_links 0
set show_stats 0
set max_checks 5000
set update_usage 0
set curr_time [clock seconds]
set ref_time [expr {$curr_time - (7*26*60*60)}]
set page_ref_time [expr {$curr_time - (7*26*60*60)}]

foreach {k v} $argv {
    set $k $v
}

if {![string is integer -strict $ref_time]} {
    set ref_time [clock scan $ref_time]
}

if {![string is integer -strict $page_ref_time]} {
    set page_ref_time [clock scan $page_ref_time]
}

proc exec_sql {db stmt {callback {}}} {
    set qs [$db prepare $stmt]
    set rs [uplevel [list $qs execute]]
    while {1} {
	while {[$rs nextdict d]} {
	    if {[llength $callback]} {
		{*}$callback $d
	    } else {
		puts $d
	    }
	}
	if {![$rs nextresults]} {
	    break
	}
    }
    $rs close
    $qs close
}

proc count {db stmt} {
    set pqs [$db prepare $stmt]
    set pqrs [uplevel [list $pqs execute]]
    $pqrs nextdict pd
    $pqrs close
    $pqs close
    return [dict get $pd COUNT(*)]
}

proc split_url_link_text { text } {
    if { [string match "*%|%*" $text] } {
	return [split [string map [list "%|%" \1] $text] \1]
    }
    return [list $text $text]
}

tdbc::sqlite3::connection create rdb $linkdb
tdbc::sqlite3::connection create wdb $wikidb

if {$create_table} {

    catch {
	exec_sql rdb {DROP TABLE link_usage}
	exec_sql rdb {DROP TABLE link}
    }
    exec_sql rdb {CREATE TABLE link (url TEXT NOT NULL, status_code INT NOT NULL, last_check INT NOT NULL,
				     PRIMARY KEY (url))}
    exec_sql rdb {CREATE TABLE link_usage (url TEXT NOT NULL, page INT NOT NULL,
					   PRIMARY KEY (url, page),
					   FOREIGN KEY (url) REFERENCES link(url))}
}

if {$update_usage} {
    exec_sql rdb {DELETE FROM link_usage}
}

if {$update_table} {
    set wqs [wdb prepare {SELECT a.id, b.content FROM pages a, pages_content b WHERE a.id = b.id AND a.date > :page_ref_time}]
    $wqs foreach -as dicts wd {
	set page [dict get $wd id]
	set content [dict get $wd content]
	if {[string match -nocase "<!DOCTYPE *" $content]} {
	    continue
	}
	puts "content: $content"
	foreach {k v} [WFormat::StreamToUrls [WFormat::TextToStream $content]] {
	    puts "k=$k, v=$v"
	    lassign [split_url_link_text $k] k
	    switch -glob -- $k {
		"mailto:*" - "ftp:*" - "news:*" {
		}
		default {
		    if {[count rdb {SELECT COUNT(*) FROM link WHERE url = :k}] == 0} {
			exec_sql rdb {INSERT INTO link (url, status_code, last_check) VALUES (:k, -1, :curr_time)}
			puts "New url: $k"
		    }
		    if {[count rdb {SELECT COUNT(*) FROM link_usage WHERE url = :k AND page = :page}] == 0} {
			exec_sql rdb {INSERT INTO link_usage (url, page) VALUES (:k, :page)}
			puts "New url usage1: $k -> $page -> [count rdb {SELECT COUNT(*) FROM link_usage WHERE url = :k AND page = :page}]"
		    }
		}
	    }
	}
    }
    $wqs close
    puts ""
}

if {$update_usage} {
    exec_sql rdb {DELETE FROM link WHERE url NOT IN (SELECT url FROM link_usage)}
}

if {$check_links} {
    set rqs [rdb prepare {SELECT url, status_code, last_check FROM link WHERE last_check < :ref_time OR status_code = -1}]
    set n 0
    $rqs foreach -as dicts rd {
	if {$n < $max_checks} {
	    set url [dict get $rd url]
	    puts "$n: $url, [dict get $rd status_code], [clock format [dict get $rd last_check]]"
	    if {[catch {http::geturl $url -timeout 10000} t]} {
		puts "$t"
		set stat -2
	    } else {
		puts " -> status = [http::status $t]"
		switch -exact -- [http::status $t] {
		    "ok" {
			set stat [http::ncode $t]
			if {![string is integer -strict $stat]} {
			    set stat -7
			}
		    }
		    "timeout" {
			if {[string length [http::data $t]]} {
			    set stat 299
			} else {
			    set stat -6
			}
		    }
		    "eof" {
			set stat -5
		    }
		    "error" {
			set stat -4
		    }
		    default {
			set stat -3
		    }
		}
		http::cleanup $t
	    }
	    puts " -> stat = $stat"
	    exec_sql rdb {UPDATE link SET status_code = :stat, last_check = :curr_time WHERE url = :url}
	    incr n
	}
    }
    $rqs close
}

if {$show_stats} {
    puts "Number of pages with content: [count wdb {SELECT COUNT(*) FROM pages_content}]"
    puts "Number of url's: [count rdb {SELECT COUNT(*) FROM link}]"
    puts "Number of url usages: [count rdb {SELECT COUNT(*) FROM link_usage}]"
    exec_sql rdb "SELECT status_code, COUNT(*) FROM link GROUP BY status_code"
    #exec_sql rdb "SELECT b.page, a.url cnt FROM link a, link_usage b WHERE a.url = b.url AND a.status_code = 404 ORDER BY b.page"
    #exec_sql rdb "SELECT url FROM link WHERE status_code = 404 ORDER BY url"


    # proc group_on_server {d} {
    # 	set url [dict get $d url]
    # 	incr ::gs([dict get [uri::split [dict get $d url]] host])
    # }
    # exec_sql rdb "SELECT url FROM link WHERE status_code = 404" group_on_server
    # foreach {k v} [array get gs] {
    # 	lappend l [list $k $v]
    # }
    # set l [lsort -index 1 -integer -decreasing $l]
    # puts [join $l \n]
}

rdb close
wdb close



