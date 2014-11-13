package require tdbc::sqlite3

if {[llength $argv] != 1} {
    puts stderr "Usage: extract_templates.tcl <filename>"
    exit 1
}

tdbc::sqlite3::connection create db [lindex $argv 0]

set stmnt1 [db prepare {select * from pages where name = :name}]
set stmnt2 [db prepare {select * from pages_content where id = :pid}]

foreach n {content cssjs edit editarea preview error login sessionlogin updateuser deleteuser insertuser new rename page query upload} {
    puts [string repeat # 80]
    puts ""
    set name "TEMPLATE:$n"
    $stmnt1 foreach -as dicts d {
	set pid [dict get $d id]
	$stmnt2 foreach -as dicts c {
	    puts "    set $n \{[string map {\x0d {}} [dict get $c content]]\}"
	    break
	}
	break
    }
    puts ""
}
puts [string repeat # 80]

db close

