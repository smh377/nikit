package require struct
package require sha256
package require http
package require mime

package provide Wiki 1.0.0

oo::class create Wiki {

    variable allow_inline_html
    variable allow_user_query
    variable cgi
    variable comment_template
    variable days_in_history
    variable days_in_rss_history
    variable enc
    variable included_pages
    variable max_search_results
    variable mpm_template
    variable namecache
    variable read_only
    variable server_http_port
    variable server_https_port
    variable server_name
    variable tcl_uid
    variable writer
    variable writer_host
    variable writer_port
    variable oneprocess

    constructor {args} {
	set enc(rpcwriter) {N 0 C 1 who 1 name 1 type 1 time 0}
	set enc(rpcareawriter) {N 0 C 1}
	set enc(rpcrenamer) {N 0 M 0 oldname 1 oldtime 0 oldwho 1 oldtype 1 newname 1 newtime 0 newwho 1 newtype 1}
	set enc(rpcpagecreator) {name 1}
	set enc(rpcupdaterusersid) {uname 1 sid 1}
	set enc(rpcupdateruser) {uname 1 pword 1 sid 1 role 1}
	set enc(rpcinserteruser) {uname 1 pword 1 sid 1 role 1}
	set enc(rpcdeleteruser) {uname 1}
	set max_search_results 10000
	set days_in_history 100
	set comment_template "<Enter your comment here and a header with your wiki nickname and timestamp will be inserted for you>"
	set allow_inline_html 1
	set allow_user_query 1
	set days_in_rss_history 3
	set read_only 0
	set server_name localhost
	set server_http_port 80
	set server_https_port 443
	set writer_host localhost
	set writer_port 8009
	set tcl_uid 0
	set writer 0
	set cgi {}
	set included_pages {}
	set oneprocess 0
	foreach {k v} $args {
	    set $k $v
	}
	if {$oneprocess} {
	    set writer 1
	}
    }

    destructor {}

    method configure {args} {
	if {[llength $args] == 1} {
	    return [set [lindex $args 0]]
	} elseif {([llength $args] % 2) == 0} {
	    foreach {k v} $args {
		set $k $v
	    }
	}
    }

    method timestamp {{t ""}} {
	if {$t == ""} { set t [clock seconds] }
	return [clock format $t -gmt 1 -format {%Y-%m-%d %T}]
    }

    method datestamp {{t ""}} {
	if {$t == ""} { set t [clock seconds] }
	return [clock format $t -gmt 1 -format {%Y-%m-%d}]
    }

    method formatSnippet {s} {
	set s [armour $s]
	set s [string map {^^^^^^^^^^^^ <b> ~~~~~~~~~~~~ </b>} $s]
	return $s
    }

    method getTemplate {templ} {
	set N [my LookupPage $templ 1]
	if {[string is integer -strict $N]} {
	    set C [my html [WDB GetContent $N] 1]
	} else {
	    return ""
	}
    }

    method formatTemplate {template args} {
	set type "text/html"
	set Headers {Cache-Control No-Cache}
	foreach {k v} $args {
	    set $k $v
	}
	$cgi asText [subst -nobackslashes -nocommands [my getTemplate $template]] $type $Headers
    }

    method formatPage {args} {
	set HeaderTitle ""
	set PageTitle ""
	set SubTitle ""
	set Content ""
	set TOC ""
	set Menu [my menuLI]
	set PostLoad ""
	set Headers {Cache-Control No-Cache}
	set type "text/html"
	foreach {k v} $args {
	    set $k $v
	}
	set TOC "" ;# TBD: format the page TOC in the left-hand menu
	my formatTemplate TEMPLATE:page HeaderTitle $HeaderTitle PageTitle $PageTitle SubTitle $SubTitle Content $Content TOC $TOC Menu $Menu PostLoad $PostLoad Headers $Headers type $type
    }

    method errorPage {code title content} {
	my formatTemplate TEMPLATE:error Title $title Content $content
    }

    method asTCL {C} {
	return [string match -nocase {<!DOCTYPE TCL>*} $C]
    }

    method asHTML {C} {
	return [expr {[string match -nocase {<!DOCTYPE HTML*} $C] && ![my asHTMLPart $C]}]
    }

    method asHTMLPart {C} {
	return [string match -nocase {<!DOCTYPE HTMLPART>*} $C]
    }

    # Values must be armoured!
    method list2Table {l header} {
	set row 0
	set C "<table class='sortable'>\n"
	append C "<thead><tr>\n"
	foreach t $header {
	    append C [my aTag <th> class $t [string totitle $t]]\n
	}
	append C "</tr></thead>\n"
	append C "<tbody>\n"
	set row 0
	foreach vl $l {
	    append C "<tr class='[expr {[incr row] % 2 ? "even" : "odd"}]'>\n"
	    foreach th $header v $vl {
		append C [my tag <td> class $t $v]\n
	    }
	    append C "</tr>\n"
	}
	append C "</tbody>\n"
	append C "</table>\n"
    }

    method subTitle {date who pfx {redir_from -1}} {
	set l {}
	if {[string is integer -strict $date] && $date != 0} {
	    set update [clock format $date -gmt 1 -format {%Y-%m-%d %T}]
	    lappend l [armour $update]
	}
	if {$who ne "" && [regexp {^(.+)[,@](.*)} $who - who_nick who_ip] && $who_nick ne ""} {
	    my LookupPage $who_nick
	    set lwho "by [my aTag <a> href /page/[$cgi encode $who_nick] $who_nick]"
	    if {[string length $who_ip]} {
		append lwho @[my aTag <a> rel nofollow target _blank href http://ip-lookup.net/index.php?ip=$who_ip $who_ip]
	    }
	    lappend l $lwho
	}
	if {$redir_from >= 0} {
	    lassign [WDB GetPage $redir_from date name who] pcdate name pcwho
	    lappend l "redirected from [my aTag <a> href /page/[$cgi encode $name]?R=0 $name]"
	}
	set subtitle ""
	if {[llength $l]} {
	    set subtitle "$pfx [join $l \ ]"
	}
	return $subtitle
    }

    method isGnomeEdit {who} {
	if {$who ne "" && [regexp {^(.+)[,@](.*)} $who - who_nick who_ip] && $who_nick ne "" } {
	    if {[WDB CountUser $who_nick]} {
		set d [WDB GetUserByName $who_nick]
		return [expr {[lsearch [dict get $d role] gnome] >= 0}]
	    }
	}
	return 0
    }

    method whoUrl { who {ip 1} } {
	if {$who ne "" && [regexp {^(.+)[,@](.*)} $who - who_nick who_ip] && $who_nick ne "" } {
	    my LookupPage $who_nick
	    set who [my aTag <a> href /page/[$cgi encode $who_nick] $who_nick]
	    if {$ip && [string length $who_ip]} {
		append who @[my aTag <a> rel nofollow target _blank href http://ip-lookup.net/index.php?ip=$who_ip $who_ip]
	    }
	}
	return $who
    }

    method menus { args } {
	if {![info exists menus(Recent)]} {
	    set menus(Home)   [my aTag <a> href /welcome Home]
	    set menus(Recent) [my aTag <a> rel nofollow href /recent "Recent changes"]
	    set menus(Help)   [my aTag <a> rel nofollow href /help Help]
	    set menus(HR)     <br>
	    set menus(Search) [my aTag <a> rel nofollow href /search Search]
	    set menus(WhoAmI) [my aTag <a> rel nofollow href /whoami Who]/[my aTag <a> rel nofollow href /login Login]/[my aTag <a> rel nofollow href /logout Logout]
	    set menus(Session) [my aTag <a> rel nofollow href /session Session]
	    set menus(Random) [my aTag <a> rel nofollow href /random "Random page"]
	    set menus(New)    [my aTag <a> rel nofollow href /new "Create new page"]
	}
	set m {}
	foreach arg $args {
	    if {[string match "<*" $arg]} {
		lappend m $arg
	    } elseif {$arg ne ""} {
		lappend m $menus($arg)
	    }
	}
	return $m
    }

    method menuLI {{l {}} {add_hr 1}} {
	set ml [my menus Home Recent Help WhoAmI Session New Random]
	if {[llength $l]} {
	    if {$add_hr} {
		lappend ml {*}[my menus HR]
	    }
	    lappend ml {*}$l
	}
	set r {}
	foreach li $ml {
	    append r <li>$li</li>
	}
	return $r
    }

    # Access rules

    # Predefined roles are:
    #
    # all    : each user of the site gets this role
    # known  : edit logged in (as today on Tcler's wiki)
    # trusted: session logged in (user is given username+password to login)
    # gnome  : edits by this user are not shown in the recent changes list, must
    #          be assigned to a user in the users table.
    # admin  : full access to pages and users, must be assigned to a user in the
    #          users table.
    #
    # When a user is session logged in, the roles assigned to the user in the
    # users table are also added to his role list.

    # Known privileges are: read, write, admin. The following list shows which
    # privileges are needed to access the different method:
    #
    # -     : login, logout, session, users, whoami
    # read  : brokenlinks, cleared, diff, help, history, htmlpreview, image,
    #         nextpage*, page, preview, previouspage*, random, recent, ref,
    #         revision, rss*, search*, sitemap*, tclpreview, welcome
    # write : edit, new, rename, save, saveupload, upload
    # admin : editarea, query, savearea
    #
    # Note: rpc methods are not protected. The are protected from being called
    # in a non-writer process and protections on non-rpc pages must prevent them
    # being call with insufficient user rights.

    # The access rules for a page are stored in a dict with roles as keys and a
    # list of privileges as values. Each page gets the access rules from the
    # last matching page area specified in page ACCESSRULES using the following
    # syntax:
    #
    # <area match string> {<role> { ?<privilege> ...? } ...}

    # To check if a user can access a method, for each of his user-roles it is
    # checked if the required privilege is in the access rules dict for the
    # roles in the access rules dict matching userrole. When a user has the
    # admin role, he can access every method.

    # Example: Wiki style roles specified in page ACCESSRULES:
    # --------
    #
    # * {all {read write}}
    # admin {}
    #
    # Some users can be given the 'gnome' role to keep the recent changes and
    # RSS clean.

    # Example: CMS style roles specified in page ACCESSRULES:
    # --------
    #
    # * {all {read} trusted {write}}
    # admin {}
    #

    # Example: Area of responsability style roles specified in page ACCESSRULES:
    # --------
    #
    # * {all {read}}
    # tcl {all {read} tcl {write}}
    # tk {all {read} tk {write}}
    # admin {}
    #
    # Create users with roles for the different areas: tcl, tk, ...
    #
    # A user with role 't*' will be able to write both tcl and tk pages.


    method GetRoles {} {
	set roles [list all]
	if {[my loggedIn]} {
	    lappend roles known
	}
	if {[my session_active dnm]} {
	    lappend roles trusted
	    lappend roles session [dict get $dnm username] {*}[dict get $dnm role]
	}
	return $roles
    }

    method GetDefaultPageAcessRules {name} {
	set acd {}
	set prard [string map {\n " "} [WDB GetContent [my LookupPage "ACCESSRULES" 1]]]
	dict for {page role_access_rules} $prard {
	    if {[string match $page $name]} {
		set acd {}
		dict for {role access_rules} $role_access_rules {
		    dict set acd $role $access_rules
		}
	    }
	}
	return $acd
    }

    method has_access {N what {report 1}} {
	set roles [my GetRoles]
	# Admins can do anything.
	if {"admin" in $roles} {
	    return 1
	}
	# Parse the access rules text
	set acd {}
	if {$N >= 0} {
	    set acd [my GetDefaultPageAcessRules [WDB GetPage $N area]]
	} else {
	    set acd [my GetDefaultPageAcessRules ""]
	}
	# Check role with access rules
	foreach role $roles {
	    foreach pagerole [dict keys $acd $role] {
		if {$what in [dict get $acd $pagerole]} {
		    return 1
		}
		if {"admin" in [dict get $acd $pagerole]} {
		    return 1
		}
	    }
	}
	if {$report} {
	    my formatTemplate TEMPLATE:noaccess
	}
	return 0
    }

    method has_role {what} {
	return [expr {$what in [my GetRoles]}]
    }

    method render {N C query_only} {
	set mkup [my GetMkUp $N $query_only]
	set html [$mkup render $C]
	set toc [$mkup cget toc]
	set brefs [$mkup cget backrefs]
	set irefs [$mkup cget includes]
	$mkup destroy
	return [list $html $toc $brefs $irefs]
    }

    method rss {} {
	if {![my has_access -1 read]} return
	set C "<?xml version='1.0'?><rss version='0.91'>\n"
	append C "<channel>\n"
	append C "<title>[xmlarmour "Tcler's Wiki - Recent Changes"]</title>\n"
	append C "<link>[xmlarmour "http://$server_name:$server_http_port"]</link>\n"
	append C "<description>[xmlarmour "Recent changes to Tcler's Wiki"]</description>\n"
	set i 0
	set edate [expr {[clock seconds]-$days_in_rss_history*86400}]
	set pages [WDB RecentChanges $edate]
	foreach pager $pages {
	    append C "<item>\n"
	    append C "  <title>[xmlarmour [dict get $pager name]]</title>\n"
	    append C "  <link>[xmlarmour http://$server_name:$server_http_port/page/[$cgi encode [dict get $pager name]]]</link>\n"
	    append C "  <gui>[xmlarmour http://$server_name:$server_http_port/revision/[$cgi encode [dict get $pager name]]?V=[WDB Versions $id]]</link>\n"
	    append C "  <pubDate>[xmlarmour [my timestamp [dict get $pager date]]]</pubDate>\n"
	    append C "  <description>Modified by [xmlarmour [dict get $pager who]]</description>\n"
	    append C "</item>\n"
	}
	append C "</channel>\n"
	append C "</rss>\n"
	$cgi asText $C text/xml
    }

    method sitemap {} {
	if {![my has_access -1 read]} return
	set C "<?xml version='1.0'?>\n"
	append C "<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>\n"
	foreach record [WDB AllPages] {
	    append C "<url><loc>[xmlarmour "http://$server_name:$server_http_port/page/[$cgi encode [dict get $record name]]"]</loc><lastmod>[clock format [dict get $record date] -format {%Y-%m-%dT%H:%M:%SZ}]</lastmod></url>\n"
	}
	append C "</urlset>\n"
	$cgi asText $C text/xml
    }

    method recent {} {
	if {![my has_access -1 read]} return
	set A [my getIntParam A 0]
	set C ""
	set N [my LookupPage ADMIN:MOTD 1]
	if {[string is integer -strict $N]} {
	    append C [WDB GetContent $N]\n
	}
	append C [my aTag <h4> "Recent changes"]
	set threshold [expr {[clock seconds] - $days_in_history * 86400}]
	set lastDay 0
	set records [WDB RecentChanges $threshold]
	set tablelist {}
	set pday ""
	foreach record $records {
	    if {![my has_access [dict get $record id] read]} continue ;# User has no read privilege
	    if {!$A && [my isGnomeEdit [dict get $record who]]} continue ;# Don't show gnome edits
	    if {!$A && [info exists visited([dict get $record id])]} continue ;# Show each page just once
	    set cday [my tag <h5> "[my aTag <b> [clock format [dict get $record date] -gmt 1 -format {%Y-%m-%d}]] [my aTag <span> class day [clock format [dict get $record date] -gmt 1 -format %A]]"]
	    if {$pday ne $cday} {
		if {[string length $pday]} {
		    append C "</table>\n"
		}
		append C $cday\n
		append C "<table class='rctable'>\n"
		set pday $cday
	    }
	    append C <tr>
	    append C [my tag <td> class rc1 [my aTag <a> href /page/[$cgi encode [dict get $record name]] [dict get $record name]][my aTag <a> class delta rel nofollow href /diff/[$cgi encode [dict get $record name]]#diff0 [subst \u25B2]]]
	    append C [my tag <td> class rc2 [my whoUrl [dict get $record who]]]
	    append C </tr>\n
	    set visited([dict get $record id]) 1
	}
	if {[string length $pday]} {
	    append C "</table>\n"
	}
	my formatPage HeaderTitle "Recent changes" PageTitle "Recent changes" Content $C
    }

    method cleared {} {
	if {![my has_access -1 read]} return
	set threshold [expr {[clock seconds] - $days_in_history * 86400}]
	set lastDay 0
	set records [WDB Cleared]
	set tablelist {}
	foreach record $records {
	    set l {}
	    lappend l [my aTag <a> href /page/[$cgi encode [dict get $record name]] [dict get $record name]]
	    lappend l [my whoUrl [dict get $record who]]
	    lappend l [my timestamp [dict get $record date]]
	    lappend tablelist $l
	}
	set C [my list2Table $tablelist {Name Who Date}]
	my formatPage HeaderTitle "Cleared pages" PageTitle "Cleared pages" Content $C
    }

    method removeNonWikitMarkup { t } {
	set r {}
	set skip 0
	foreach l [split $t \n] {
	    if {$l eq "<<inlinehtml>>"} {
		set skip [expr {!$skip}]
		continue
	    } elseif {!$skip} {
		lappend r $l
	    }
	}
	return [join $r \n]
    }

    method unWhiteSpace { t } {
	set n {}
	foreach l $t {
	    # Replace all but leading white-space by single space
	    set tl [string trimleft $l]
	    set nl [string range $l 0 [expr {[string length $l] - [string length $tl] - 1 }]]
	    append nl [regsub -all {\s+} $tl " "]
	    lappend n [string map {\t "        "} $nl]
	}
	return $n
    }

    method markDiff {t N V txt} {
 	return ">>>>>>$t;$N;$V;;\n$txt\n<<<<<<\n"
    }

    method query {} {
	if {!$allow_user_query} {
	    my pageNotFound query
	}
	if {![my has_access -1 admin]} return
	set Q [$cgi getParam Q "" 0]
	set R ""
	if {[string length $Q]} {
	    append R [my aTag <h3> "Query:"]
	    append R [my aTag <pre> $Q]
	    # Open the DB in readonly mode for the query
	    tdbc::sqlite3::connection create qdb $::WikiDatabase ;#-readonly 1
	    if {[catch {
		set qs [qdb prepare $Q]
		set tablelist {}
		set header {}
		set dl {}
		$qs foreach -as dicts d {
		    dict for {k v} $d {
			if {![info exists hkeys($k)]} {
			    lappend header $k
			    set hkeys($k) 1
			}
			if {$k eq "id"} {
			    dict set d id [my aTag <a> href /page/$v $v]
			} else {
			    dict set d id [armour $v]
			}
		    }
		    lappend dl $d
		}
		$qs close
		foreach d $dl {
		    set l {}
		    foreach h $header {
			if {[dict exists $d $h]} {
			    lappend l [dict get $d $h]
			} else {
			    lappend l ""
			}
		    }
		    lappend tablelist $l
		}
		append R [my aTag <h3> "Query result:"]
		append R [my list2Table $tablelist $header]
	    } msg]} {
		append R [my aTag <h3> "Query failed:"]
		append R [my aTag <pre> $msg]
	    }
	    qdb close
	}
	my formatTemplate TEMPLATE:query Q $Q R $R
    }

    method shiftNewline { s m } {
	if { [string index $s end] eq "\n" } {
	    return "$m[string range $s 0 end-1]$m\n"
	} else {
	    return "$m$s$m"
	}
    }

    method wordList { l } {
	set rl [split [string map {\  \0\  \n \ \n} $l] " "]
    }

    # Parameters:
    # - N = page number
    # - V = page version
    # - D = page version
    method diff {N} {
	if {![my getN N]} return
	if {![my has_access $N read]} return
	set V [my getIntParam V -1]
	set D [my getIntParam D -1]
	lassign [WDB GetPage $N type name] type name

	if {![my isTextPage $type]} {
	    my history
	    return
	}
	set SubTitle ""
	set nver [WDB Versions $N]
	if {$V > $nver || $D > $nver} {
	    my pageNotFound /diff/[$cgi encode $name]?V=$V&D=$D
	    return
	}
	if {$D < 0} {
	    set D $nver
	}
	if {$V < 0} {
	    set V [expr {$nver - 1}]
	}

	set t1 [my getPageWithVersion $N $V]
	set t1 [split $t1 "\n"]
	set uwt1 {}
	foreach l $t1 {
	    if {[string length $l] != 0} {
		lappend uwt1 $l
	    }
	}
	set t1 $uwt1

	set t2 [my getPageWithVersion $N $D]
	set t2 [split $t2 "\n"]
	set uwt2 {}
	foreach l $t2 {
	    if {[string length $l] != 0} {
		lappend uwt2 $l
	    }
	}
	set t2 $uwt2

	set p1 0
	set p2 0
	set C ""

	foreach {l1 l2} [::struct::list::LlongestCommonSubsequence $uwt1 $uwt2] {
	    foreach i1 $l1 i2 $l2 {
		if { $p1 < $i1 && $p2 < $i2 } {
		    set d1 ""
		    set d2 ""
		    set pd1 0
		    set pd2 0
		    while { $p1 < $i1 } {
			append d1 "[lindex $t1 $p1]\n"
			incr p1
		    }
		    while { $p2 < $i2 } {
			append d2 "[lindex $t2 $p2]\n"
			incr p2
		    }
		    set d1 [my wordList $d1]
		    set d2 [my wordList $d2]
		    foreach {ld1 ld2} [::struct::list::LlongestCommonSubsequence2 $d1 $d2 10] {
			foreach id1 $ld1 id2 $ld2 {
			    while { $pd1 < $id1 } {
				set w [lindex $d1 $pd1]
				if { [string length $w] } {
				    append C [my shiftNewline $w "^^^^"]
				}
				incr pd1
			    }
			    while { $pd2 < $id2 } {
				set w [lindex $d2 $pd2]
				if { [string length $w] } {
				    append C [my shiftNewline $w "~~~~"]
				}
				incr pd2
			    }
			    append C "[lindex $d1 $id1]"
			    incr pd1
			    incr pd2
			}
			while { $pd1 < [llength $d1] } {
			    set w [lindex $d1 $pd1]
			    if { [string length $w] } {
				append C [my shiftNewline $w "^^^^"]
			    }
			    incr pd1
			}
			while { $pd2 < [llength $d2] } {
			    set w [lindex $d2 $pd2]
			    if { [string length $w] } {
				append C [my shiftNewline $w "~~~~"]
			    }
			    incr pd2
			}
		    }
		} else {
		    while { $p1 < $i1 && $p2 < $i2 } {
			set txt1 [lindex $t1 $p1]
			set mtxt1 [string map {\  {} \t {} \n {}} $txt1]
			set txt2 [lindex $t2 $p2]
			set mtxt2 [string map {\  {} \t {} \n {}} $txt2]
			if {$mtxt1 eq $mtxt2} {
			    append C [my markDiff w $N $D $txt2]
			} else {
			    append C [my markDiff n $N $V $txt1]
			    append C [my markDiff o $N $D $txt2]
			}
			incr p1
			incr p2
		    }
		    while { $p1 < $i1 } {
			append C [my markDiff n $N $V [lindex $t1 $p1]]
			incr p1
		    }
		    while { $p2 < $i2 } {
			append C [my markDiff o $N $D [lindex $t2 $p2]]
			incr p2
		    }
		}
		if { [string equal [lindex $t1 $i1] [lindex $t2 $i2]] } {
		    append C "[lindex $t1 $i1]\n"
		} else {
		    append C [my markDiff w $N $V [lindex $t1 $i1]]
		}
		incr p1
		incr p2
	    }
	}
	while { $p1 < [llength $t1] } {
	    append C [my shiftNewline [lindex $t1 $p1] "^^^^"]
	    incr p1
	}
	while { $p2 < [llength $t2] } {
	    append C [my shiftNewline [lindex $t2 $p2] "~~~~"]
	    incr p2
	}

	set C [regsub -all "\0" $C " "]

	set mkup [my GetMkUp $N 1]
	set C [$mkup render_diff $C]
	$mkup destroy

	set menu {}
	lappend menu [my aTag <a> rel nofollow href /history/[$cgi encode $name] History]
	if {![string length $SubTitle]} {
	    set SubTitle "Difference between version "
	    append SubTitle [my aTag <a> rel nofollow href /revision/[$cgi encode $name]?V=$V $V]
	    append SubTitle " and "
	    append SubTitle [my aTag <a> rel nofollow href /revision/[$cgi encode $name]?V=$D $D]
	    append SubTitle "."
	}
	my formatPage HeaderTitle [armour $name] PageTitle [my aTag <a> href /page/[$cgi encode $name] $name] SubTitle $SubTitle \
	    Content $C Menu [my menuLI $menu]
    }

    method includes {N lnm} {
	upvar $lnm l
	foreach d [::WDB getIncludesInto $N] {
	    set I [dict get $d incid]
	    if {$I ni $l} {
		lappend l $I
		my includes $I l
	    }
	}
    }

    method etag {N args} {
	set etag "$N.[WDB Versions $N]"
	foreach arg $args {
	    append etag " $arg"
	}
	append etag " includes"
	set include_list {}
	my includes $N include_list
	foreach I $include_list {
	    append etag " $I.[WDB Versions $I]"
	}
	return [::sha2::sha256 $etag]
    }

    # Parameters: N = page number, T = 1 => textual 0 => rendered, R = allow redirect, O = redirected from
    method page {N} {
	if {![my getN N]} return
	return [my showpage $N]
    }

    method showpage {N} {
	if {![my has_access $N read 1]} return
	set T [my getIntParam T 0]
	set R [my getIntParam R 1]
	set O [my getIntParam O -1]
	# HTML pages display "as is" unless the edit flag is set
	set editHTML [my getIntParam E 0]
	lassign [::WDB GetPage $N name date who type] name date who type
	if {[my isTextPage $type]} {

	    if {$T} {
		my text $N -1
		return
	    }
	    set C [WDB GetContent $N]
	    if {$R && [string match "<<redirect>>*" $C]} {
		set rdpnm [string trim [string range $C 12 end]]
		lassign [my InfoProc $rdpnm 1 0] rdN rdName
		if {[string is integer -strict $rdN] && $rdN != $N} {
		    $cgi redirect /page/[$cgi encode $rdName]?R=0&O=$N
		    return
		}
	    }
	    if {[my asHTML $C]} {
		if {$editHTML} {
		    set C "======none\n$C\n======"
		} else {
		    my html $C
		    return
		}
	    } elseif {[my asHTMLPart $C]} {
		set C "======none\n$C\n======"
	    } elseif {[my asTCL $C]} {
		if {$editHTML} {
		    set C "======none\n$C\n======"
		} else {
		    my tcl $C 0 0 ""
		    return
		}
	    }
	    lassign [my render $N $C 0] C T BR IH
	    set PostLoad ""
	    set included_pages {}
	    set C [my serverIncludePages $C $IH]
	    set containerid 0
	    foreach bref $BR {
		if {[string length $bref]} {
		    set brefpage [my LookupPage $bref]
		} else {
		    set brefpage $N
		}
		append PostLoad "<script>getBackRefs($brefpage,'mkupbackref$containerid');</script>\n"
		incr containerid
	    }
	    set menu {}
	    lappend menu [my aTag <a> rel nofollow href /previouspage/[$cgi encode $name] "Previous page"]
	    lappend menu [my aTag <a> rel nofollow href /nextpage/[$cgi encode $name] "Next page"]
	    lappend menu {*}[my menus HR]
	    lappend menu "[my aTag <a> rel nofollow href /edit/[$cgi encode $name] Edit]/[my aTag <a> rel nofollow href /editarea/[$cgi encode $name] Access]"
	    lappend menu [my aTag <a> rel nofollow href /upload/[$cgi encode $name] Upload]
	    lappend menu [my aTag <a> rel nofollow href /edit/[$cgi encode $name]?A=1 Comment]
	    lappend menu [my aTag <a> rel nofollow href /history/[$cgi encode $name] History]
	    lappend menu [my aTag <a> rel nofollow href /ref/[$cgi encode $name] References]

	    my formatPage HeaderTitle [armour $name] PageTitle [my aTag <a> rel nofollow href /ref/[$cgi encode $name] $name] \
		SubTitle [my subTitle $date $who "Updated" $O] Content $C TOC $T Menu [my menuLI $menu 0] PostLoad $PostLoad
	} else {
	    if {$T} {
		my binary $N -1
		return
	    }
	    set etag $N.[WDB VersionsBinary $N]
	    set menu {}
	    lappend menu [my aTag <a> rel nofollow href /previouspage/[$cgi encode $name] "Previous page"]
	    lappend menu [my aTag <a> rel nofollow href /nextpage/[$cgi encode $name] "Next page"]
	    lappend menu {*}[my menus HR]
	    lappend menu [my aTag <a> rel nofollow href /upload/[$cgi encode $name] Upload]
	    lappend menu [my aTag <a> rel nofollow href /history/[$cgi encode $name] History]
	    lappend menu [my aTag <a> rel nofollow href /ref/[$cgi encode $name] References]
	    my formatPage HeaderTitle [armour $name] PageTitle [my aTag <a> rel nofollow href /ref/[$cgi encode $name] $name] \
		SubTitle [my subTitle $date $who "Updated"] \
		Content [my aTag <img> alt "" onerror "this.src='/plume404.png';" src /image/[$cgi encode $name]] Menu [my menuLI $menu 0]
	}
    }

    method serverIncludePages {C IH} {
	set cnt 0
	set postload {}
	foreach {ihid ih} $IH {
	    set qh ""
	    set nih $ih
	    if {[string is integer -strict $ih]} {
		set N $ih
	    } else {
		set N [my LookupPage $ih 1]
		if {![string is integer -strict $N]} {
		    set idx [string last "?" $ih]
		    if {$idx >= 0} {
			set nih [string range $ih 0 [expr {$idx-1}]]
			set qh [string range $ih [expr {$idx+1}] end]
			set N [my LookupPage $nih 1]
		    }
		}
	    }
	    set idx [string first "@@@@@@@@@@$ihid@@@@@@@@@@" $C]
	    set tC [string range $C 0 [expr {$idx-1}]]
	    if {[string is integer -strict $N] && $N ni $included_pages} {
		lappend included_pages $N
		lappend included_in_this_page $N
		set iC [WDB GetContent $N]
		if {[my asHTMLPart $iC]} {
		    set iC [my html [string range $iC 19 end] 1]
		} elseif {[my asTCL $iC]} {
		    set iC [my tcl $iC 1 [my asTCL $C] $qh]
		} else {
		    lassign [my render $N $iC 0] iC iT iBR iIH
		    set iC [my serverIncludePages $iC $iIH]
		}
	    } else {
		set iC [armour "<<include:$ih>>"]
	    }

	    append tC $iC

	    append tC [string range $C [expr {$idx+20+[string length $ihid]}] end]
	    set C $tC
	    incr cnt
	}
	return $C
    }

    method getPageWithVersion {N V} {
	if {$V >= 0} {
	    set C [WDB GetPageVersion $N $V]
	} else {
	    set C [WDB GetContent $N]
	}
	return $C
    }

    method text {N V} {
	if {$V >= 0} {
	    $cgi asText [my getPageWithVersion $N $V]
	} else {
	    $cgi asText [WDB GetContent $N]
	}
    }

    method binary {N V} {
	lassign [WDB GetBinary $N $V] content type
	$cgi asBinary $content $type
    }

    # Parameters: N = page number, V = version, T = 1 => textual 0=> rendered
    method revision {N} {
	if {![my getN N]} return
	if {![my has_access $N read]} return
	set V [my getIntParam V -1]
	set T [my getIntParam T 0]
	lassign [::WDB GetPage $N name date who type] name date who type
	if {[my isTextPage $type]} {
	    set nver [WDB Versions $N]
	    if {$V > $nver || $V < 0} {
		my pageNotFound /revision/[$cgi encode $name]&V=$V
		return
	    }
	    if {$T} {
		my text $N $V
		return
	    }
	    lassign [my render $N [my getPageWithVersion $N $V] 0] C T BR IH
	    set HeaderTitle [armour "Version $V of $name"]
	    set PageTitle "Version $V of [my aTag <a> href /page/[$cgi encode $name] $name]"
	    set C [string map [list <<TOC>> $T] $C]
	    set menu {}
	    if {$V > 0} {
		lappend menu [my aTag <a> rel nofollow href "/revision/[$cgi encode $name]?V=[expr {$V-1}]" "Previous version"]
	    }
	    if {$V < $nver} {
		lappend menu [my aTag <a> rel nofollow href "/revision/[$cgi encode $name]?V=[expr {$V+1}]" "Next version"]
	    }
	    lappend menu [my aTag <a> rel nofollow href /history/[$cgi encode $name] History]
	    lappend menu [my aTag <a> rel nofollow href /ref/[$cgi encode $name] References]
	    my formatPage HeaderTitle $HeaderTitle PageTitle $PageTitle SubTitle [my subTitle $date $who "Updated"] \
		Content $C TOC $T Menu [my menuLI $menu]
	} else {
	    set nver [WDB VersionsBinary $N]
	    set versions [WDB ListPageVersionsBinary $N]
	    set found 0
	    foreach row $versions {
		lassign $row vn date who
		if {$vn == $V} {
		    set found 1
		    break
		}
	    }
	    if {!$found} {
		my pageNotFound /revision/[$cgi encode $name]?V=$V
		return
	    }
	    if {$T} {
		my binary $N $V
		return
	    }
	    set menu {}
	    if {$V > 0} {
		lappend menu [my aTag <a> rel nofollow href "/revision/[$cgi encode $name]?V=[expr {$V-1}]" "Previous version"]
	    }
	    if {$V < $nver} {
		lappend menu [my aTag <a> rel nofollow href "/revision/[$cgi encode $name]?V=[expr {$V+1}]" "Next version"]
	    }
	    lappend menu [my aTag <a> rel nofollow href /history/[$cgi encode $name] History]
	    lappend menu [my aTag <a> rel nofollow href /ref/[$cgi encode $name] References]
	    my formatPage HeaderTitle [armour $name] PageTitle [my aTag <a> rel nofollow href /ref/[$cgi encode $name] $name] \
		SubTitle [my subTitle $date $who "Updated"] \
		Content [my aTag <img> alt "" onerror "this.src='/plume404.png';" src /image/[$cgi encode $name]?V=$V] Menu [my menuLI $menu]
	}
    }

    # Parameters: N = page number, V = version
    method image {N} {
	if {![my getN N]} return
	set V [my getIntParam V -1]
	if {![my has_access $N read]} return
	lassign [WDB GetPage $N type name] type name
	if {[my isTextPage $type]} {
	    my errorPage [armour "Not an image"] [armour "Page '$N' is not an image"]
	} else {
	    if {$V != -1} {
		set nver [WDB VersionsBinary $N]
		if {$V > $nver || $V < 0} {
		    my pageNotFound /image/[$cgi encode $name]?V=$V
		    return
		}
	    }
	    my binary $N $V
	}
    }

    # Parameters: N = page number
    method backRefs {N} {
	if {![my getN N]} return
	if {![my has_access -1 read]} return
	set A [my getIntParam A 0]
	lassign [::WDB GetPage $N name date who type] name date who type
	set refList ""
	foreach from [WDB ReferencesTo $N] {
	    if {[my has_access $from read]} {
		lassign [WDB GetPage $from name date who] rname rdate rwho
		lappend refList [list [my timestamp $rdate] $rname $rwho $from reference]
	    }
	}
	foreach from [WDB RedirectsTo [WDB GetPage $N name]] {
	    if {[my has_access $from read]} {
		lassign [WDB GetPage $from name date who] rname rdate rwho
		lappend refList [list [my timestamp $rdate] $rname $rwho $from redirect]
	    }
	}
	foreach from [WDB getIncludesFrom $N] {
	    if {[my has_access $from read]
		lassign [WDB GetPage [dict get $from id] name date who] rname rdate rwho
		lappend refList [list [my timestamp $rdate] $rname $rwho [dict get $from id] include]
	    }
	}
	set refList [lsort -dictionary -index 1 $refList]
	set tableList {}
	foreach ref $refList {
	    lassign $ref rdate rname rwho rfrom rwhat
	    lappend tableList [list $date [my aTag <a> href /page/[$cgi encode $rname]?R=0 $rname] [my whoUrl $rwho] $rwhat]
	}
	if {$A} {
	    set C "<ul class='backrefs'>\n"
	    foreach br $tableList {
		lassign $br rdate rref rwho
		append C [my tag <li> $rref]\n
	    }
	    append C "</ul>\n"
	    $cgi asText $C
	} else {
	    my formatPage HeaderTitle "References to, includes from and redirects to $N" \
		PageTitle "References to, includes from, and redirects to [my aTag <a> href /page/[$cgi encode $name] $name]" \
		Content [my list2Table $tableList {Date Name Who What}]
	}
    }

    # Parameters: N = page number
    method incrPage {N incr} {
	if {![my getN N]} return
	if {![my has_access -1 read]} return
	if {[string is integer -strict $N] && (($incr < 0 && $N > 0) || ($incr > 0 && $N < ([WDB PageCount]-1)))} {
	    incr N $incr
	    set name [WDB GetPage $N name]
	    $cgi redirect /page/[$cgi encode $name]?R=0&E=1 302
	} else {
	    set name [WDB GetPage $N name]
	    $cgi redirect /page/[$cgi encode $name]?R=0&E=1 302
	}
    }

    method randomPage {} {
	if {![my has_access -1 read]} return
	set size 0
	set pc [WDB PageCount]
	set n 0
	while {$size <= 1} {
	    set N [expr {int(rand()*$pc)}]
	    lassign [WDB GetPage $N date type name] pcdate type name
	    if {[my isTextPage $type] && $pcdate > 0 && [my has_access $N read]} {
		if {[string length [WDB GetContent $N]] > 1} {
		    break
		}
	    }
	    incr n
	    if {$n > 100} {
		$cgi redirect /home 302
		break
	    }
	}
	$cgi redirect /page/[$cgi encode $name]?E=1 302
    }

    # Parameters: N = page number, S = start-point in history, L = number of lines
    method history {N} {
	set origN $N
	if {![my getN N]} return
	if {![my has_access $N read]} return
	set S [my getIntParam S 0]
	set L [my getIntParam L 25]
	if {$S < 0 || $L <= 0} {
	    my pageNotFound /history/[$cgi encode $origN]?S=$S&L=$L
	    return
	}
	lassign [WDB GetPage $N name type] name type
	if {[my isTextPage $type]} {
	    append C [my aTag <button> type button onclick "versionCompare($N, 1);" "Compare version A and B"]
	}
	append C "<table class='history'><thead class='history'>\n<tr>"
	if {[my isTextPage $type]} {
	    set histheaders {Rev Date {Modified by} WikiText {Revert to} A B}
	} else {
	    set histheaders {Rev Date {Modified by} Image}
	}
	foreach column $histheaders {
	    append C [my aTag <th> class [lindex $column 0] $column]
	}
	append C "</tr>\n</thead><tbody>\n"
	if {[my isTextPage $type]} {
	    set rowcnt 0
	    set versions [WDB ListPageVersions $N $L $S]
	    foreach row $versions {
		lassign $row vn date who
		if { $rowcnt % 2 } {
		    append C "<tr class='odd'>"
		} else {
		    append C "<tr class='even'>"
		}
		append C [my tag <td> class Rev [my aTag <a> rel nofollow href /revision/[$cgi encode $name]?V=$vn rel nofollow $vn]]
		append C [my aTag <td> class Date [clock format $date -format "%Y-%m-%d %T" -gmt 1]]
		append C [my tag <td> class Who [my whoUrl $who]]
		append C [my tag <td> class WikiText [my aTag <a> rel nofollow rel nofollow href /revision/[$cgi encode $name]?V=$vn&T=1 $vn]]
		append C [my tag <td> class Revert [my aTag <a> rel nofollow rel nofollow href /edit/[$cgi encode $name]?V=$vn $vn]]
		if {$rowcnt == 0} {
		    append C [my tag <td> [my aTag <input> id historyA$rowcnt type radio name verA value $vn checked checked]]
		} else {
		    append C [my tag <td> [my aTag <input> id historyA$rowcnt type radio name verA value $vn]]
		}
		if {$rowcnt == 1} {
		    append C [my tag <td> [my aTag <input> id historyB$rowcnt type radio name verB value $vn checked checked]]
		} else {
		    append C [my tag <td> [my aTag <input> id historyB$rowcnt type radio name verB value $vn]]
		}
		append C </tr> \n
		incr rowcnt
	    }
	} else {
	    set rowcnt 0
	    set versions [WDB ListPageVersionsBinary $N $L $S]
	    foreach row $versions {
		lassign $row vn date who
		if { $rowcnt % 2 } {
		    append C "<tr class='odd'>"
		} else {
		    append C "<tr class='even'>"
		}
		append C [my tag <td> class Rev [my aTag <a> rel nofollow href /revision/[$cgi encode $name]?V=$vn rel nofollow $vn]]
		append C [my aTag <td> class Date [clock format $date -format "%Y-%m-%d %T" -gmt 1]]
		append C [my tag <td> class Who [my whoUrl $who]]
		append C [my tag <td> class Image [my aTag <img> alt {} src /image/[$cgi encode $name]?V=$vn height 100]]
		append C </tr> \n
		incr rowcnt
	    }
	}
	append C "</tbody></table>\n"
	set menu {}
	if {$S > 0} {
	    set pstart [expr {$S - $L}]
	    if {$pstart < 0} {
		set pstart 0
	    }
	    lappend menu [my aTag <a> rel nofollow href /history/[$cgi encode $name]?S=$pstart&L=$L "Previous $L"]
	}
	set nstart [expr {$S + $L}]
	set nver [WDB Versions $N]
	if {$nstart < $nver} {
	    lappend menu [my aTag <a> rel nofollow href /history/[$cgi encode $name]?S=$nstart&L=$L "Next $L"]
	}
	my formatPage HeaderTitle [armour "Change history of $name"] PageTitle "Change history of [my aTag <a> href /page/[$cgi encode $name] $name]" \
	    Content $C Menu [my menuLI $menu]
    }

    method read_only {} {
	if {$read_only} {
	    my formatTemplate TEMPLATE:readonly
	    return 1
	}
	return 0
    }

    # Parameters: N = page number, A = Comment, V = version, S = section
    method edit {N} {
	if {[my read_only]} return
	set origN $N
	if {![my getN N]} return
	if {![my has_access $N write]} return
	set A [my getIntParam A 0]
	set V [my getIntParam V -1]
	set S [my getIntParam S -1]
	if {![my loggedIn]} {
	    my login /edit/[$cgi encode $origN]?A=$A&V=$V&S=$S
	    return
	}
	lassign [WDB GetPage $N name date who type] name date who type
	if {[my isTextPage $type]} {
	    set as_comment 0
	    if {$A} {
		set as_comment 1
		set C $comment_template
		set PageTitle "Add comment to [my aTag <a> href /page/[$cgi encode $name] $name]"
	    } elseif {$V >= 0} {
		if {$V > [WDB Versions $N]} {
		    my pageNotFound /edit/[$cgi encode $name]?V=$V&A=$A&S=$S
		    return
		}
		set S -1
		set C [my getPageWithVersion $N $V]
		set PageTitle "Revert [my aTag <a> href /page/[$cgi encode $name] $name] to version $V"
	    } else {
		set C [WDB GetContent $N]
		if {$S >= 0} {
		    set mkup [my GetMkUp $N 1]
		    set C [$mkup get_section $C $S]
		    $mkup destroy
		}
		set PageTitle "Edit [my aTag <a> href /page/[$cgi encode $name] $name]"
	    }

	    my formatTemplate TEMPLATE:edit HeaderTitle "Edit [armour $name]" PageTitle $PageTitle SubTitle [my subTitle $date $who "Last edit"] \
		C [armour $C] date $date who $who N $N S $S V $V A $A
	} else {
	    my upload $N
	}
    }

    method editarea {N} {
	if {[my read_only]} return
	if {![my has_access $N admin]} return
	set origN $N
	if {![my getN N]} return
	if {![my loggedIn]} {
	    my login /editarea/[$cgi encode $origN]
	    return
	}
	lassign [WDB GetPage $N name area] name area
	set PageTitle "Edit area for [my aTag <a> href /page/[$cgi encode $name] $name]"
	my formatTemplate TEMPLATE:editarea HeaderTitle "Edit area for [armour $name]" PageTitle $PageTitle SubTitle "" C [armour $area] N $N
    }

    method RPCRenamer {args} {
	if {!$writer} {
	    $cgi asText "error\nTrying to write in non-writer process."
	}

	if {$oneprocess} {
	    lassign $args N M oldname oldtime oldwho oldtype newname newtime newwho newtype
	} else {
	    if {![my getNParam N N]} return
	    if {![my getNParam M M]} return
	    set newwho  [my dec rpcrenamer newwho  "" 0]
	    set oldwho  [my dec rpcrenamer oldwho  "" 0]
	    set newname [my dec rpcrenamer newname "" 0]
	    set oldname [my dec rpcrenamer oldname "" 0]
	    set newtime [my dec rpcrenamer newtime 0  1]
	    set oldtime [my dec rpcrenamer oldtime 0  1]
	    set newtype [my dec rpcrenamer newtype "" 0]
	    set oldtype [my dec rpcrenamer oldtype "" 0]
	}

	if {[catch {WDB RenamePage [mycode getRefs] [mycode getIncludes] $N $M $newname $newtime $newwho $newtype $oldname $oldtime $oldwho $oldtype} msg]} {
	    set txt "error\n$msg\n$::errorInfo"
	} else {
	    set txt "renamed"
	}
	if {$oneprocess} {
	    return $txt
	} else {
	    $cgi asText $txt
	}
    }

    method renamePage {N} {
	if {[my read_only]} return
	if {![my has_access $N write] || ![my has_access -1 write]} return
	if {[string length $N]} {
	    set origN $N
	    if {![my getN N]} return
	} else {
	    if {![my getNParam N]} return
	    set origN $N
	}
	if {![my loggedIn]} {
	    my login /rename/[$cgi encode $origN]
	    return
	}
	lassign [WDB GetPage $N name date who type] oldname olddate oldwho type
	if {![my isTextPage $type]} {
	    my errorPage 404 [armour "Not supported"] [armour "Page '$N' is an image. Renaming of images is not supported."]
  	    return
	}
	set newname [$cgi getParam pagename "" 0]
	if {[string length $newname]} {
	    # Create new page as copy of $N
	    lassign [my InfoProc $newname 1 1] M
	    if {[string is integer -strict $M]} {
		my errorPage 404 [armour "Duplicate name"] [armour "Page with name '$newname' already exists."]
		return
	    }
	    lassign [my InfoProc $newname 0 1] M
	    if {![string is integer -strict $M]} {
		my errorPage 404 [armour "Can't create page"] ["Page with name '$newname' could not be created."]
		return
	    }
	    set newnick [$cgi cookie get wikit_e]
	    set newwho $newnick@[$cgi getRequestParam REMOTE_ADDR]
	    my RPC rpcrenamer $N $M $oldname $olddate $oldwho $type $newname [clock seconds] $newwho $type
	    $cgi redirect /page/[$cgi encode $newname] 302
	} else {
	    my formatTemplate TEMPLATE:rename N $N oldname [armour $oldname]
	}
    }

    method newPage {} {
	if {[my read_only]} return
	if {![my has_access -1 write]} return
	if {![my loggedIn]} {
	    my login /new
	    return
	}
	set name [$cgi getParam pagename "" 0]
	if {[string length $name]} {
	    my InfoProc $name 0 1
	    $cgi redirect /edit/[$cgi encode $name] 302
	    return
	} else {
	    my formatTemplate TEMPLATE:new
	}
    }

    method htmlpreview {} {
	set N [$cgi getParam N "" 0]
	if {![my has_access $N read]} return
	if {[file exists preview_cache/$N]} {
	    set f [open preview_cache/$N r]
	    set O [read $f]
	    close $f
	    file delete -force preview_cache/$N
	    my html $O
	} else {
	    my pageNotFound preview
	}
    }

    method tclpreview {} {
	set N [$cgi getParam N "" 0]
	if {![my has_access $N read]} return
	if {[file exists preview_cache/$N]} {
	    set f [open preview_cache/$N r]
	    set O [read $f]
	    close $f
	    file delete -force preview_cache/$N
	    my tcl $O 0 0 ""
	} else {
	    my pageNotFound preview
	}
    }

    method preview {} {
	set N [$cgi getParam N "" 0]
	if {![my has_access $N read]} return
	set O [$cgi getParam P "" 0]
	set O [string map {\t "        "} $O]
	if {[my asHTML $O]} {
	    set sha [::sha2::sha256 $O]
	    set f [open preview_cache/$sha w]
	    puts $f $O
	    close $f
	    my formatTemplate TEMPLATE:preview Title [armour "Preview"]  Content [my tag <iframe> width 100% height 1000px src htmlpreview?N=$sha "HTML page preview"]
	} elseif {[my asTCL $O]} {
	    set sha [::sha2::sha256 $O]
	    set f [open preview_cache/$sha w]
	    puts $f $O
	    close $f
	    my formatTemplate TEMPLATE:preview Title [armour "Preview"]  Content [my tag <iframe> width 100% height 1000px src tclpreview?N=$sha "TCL page preview"]
	} else {
	    if {[my asHTMLPart $O]} {
		set O "======none\n$O\n======"
	    }
	    lassign [my render $N $O 1] O T BR
	    my formatTemplate TEMPLATE:preview Title [armour "Preview"] Content $O
	}
    }

    method RPCWriter {args} {
	if {!$writer} {
	    return [my RPCreturn "error\nTrying to write in non-writer process."]
	}
	if {[my read_only]} return

	if {$oneprocess} {
	    lassign $args N C who name type time
	} else {
	    if {![my getNParam N]} return
	    set C    [my dec rpcwriter C    "" 0]
	    set who  [my dec rpcwriter who  "" 0]
	    set name [my dec rpcwriter name "" 0]
	    set type [my dec rpcwriter type "" 0]
	    set time [my dec rpcwriter time 0  1]
	}

	if {[catch {WDB SavePage [mycode getRefs] [mycode getIncludes] $N $C $who $name $type $time} msg]} {
	    return [my RPCreturn "error\n$msg\n$::errorInfo"]
	} else {
	    return [my RPCreturn "written"]
	}
    }

    method RPCAreaWriter {args} {
	if {!$writer} {
	    return [my RPCreturn "error\nTrying to write in non-writer process."]
	}
	if {[my read_only]} return

	if {$oneprocess} {
	    lassign $args N C
	} else {
	    if {![my getNParam N]} return
	    set C [my dec rpcareawriter C    "" 0]
	}

	if {[catch {WDB SaveArea $N $C} msg]} {
	    return [my RPCreturn "error\n$msg\n$::errorInfo"]
	} else {
	    return [my RPCreturn "arwritten"]
	}
    }

    method RPCPageCreator {args} {
	if {!$writer} {
	    return [my RPCreturn "error\nTrying to write in non-writer process."]
	}
	if {[my read_only]} return
	if {$oneprocess} {
	    lassign $args name
	} else {
	    set name [my dec rpcpagecreator name "" 0]
	}
	if {[catch {WDB CreatePage $name} msg]} {
	    return [my RPCreturn "error\n$msg\n$::errorInfo"]
	} else {
	    return [my RPCreturn "pagecreated\n$msg"]
	}
    }

    method saveArea {} {
	if {[my read_only]} return
	if {![my getNParam N]} return
	if {![my has_access $N admin]} return
	set C [$cgi getParam C "" 0]
	set save [$cgi getParam save "" 0]
	set cancel [$cgi getParam cancel "" 0]
	set name [WDB GetPage $N name]
	if { [string tolower $cancel] eq "cancel" } {
	    $cgi redirect /page/[$cgi encode $name] 302
	    return
	}
	my RPC rpcareawriter $N $C
	$cgi redirect /page/[$cgi encode $name] 302
    }

    method save {} {
	if {[my read_only]} return
	if {![my getNParam N]} return
	if {![my has_access $N write]} return
	set C [$cgi getParam C "" 0]
	#	set C [encoding convertfrom utf-8 $C]
	set O [$cgi getParam O "" 0]
	set A [my getIntParam A 0]
	set S [my getIntParam S -1]
	set V [my getIntParam V -1]
	set save [$cgi getParam save "" 0]
	set cancel [$cgi getParam cancel "" 0]
	set preview [$cgi getParam preview "" 0]
	lassign [WDB GetPage $N name date who type ] name date who otype
	if { [string tolower $cancel] eq "cancel" } {
	    $cgi redirect /page/[$cgi encode $name] 302
	    return
	}
	# Page completely cleared, don't save, there must remain one character at least.
	if {$A} {
	    set C [string trim [string map [list $comment_template ""] $C]]
	}
	if {$C eq ""} {
	    $cgi redirect /page/[$cgi encode $name] 302
	    return
	}
	if {![my loggedIn]} {
	    my formatTemplate TEMPLATE:notloggedin N $N C [armour $C]
	    return
	}
	if {[string length $date] && [string length $who] && ($O ne "$date $who")} {
	    my formatTemplate TEMPLATE:conflict N $N who [my whoUrl $who] C [armour $C]
	    return
	}
	# Check types
	set type $otype
	# Save
	set nick [$cgi cookie get wikit_e]
	set who $nick@[$cgi getRequestParam REMOTE_ADDR]
	if {[my isTextPage $type]} {
	    # Reconstruct C if editing sections or append if adding comment
	    if {$S >= 0} {
		if {$V >= 0} {
		    if {$V > [WDB Versions $N]} {
			my pageNotFound /save/$N?V=$V&A=$A&S=$S
			return
		    }
		    set fC [my getPageWithVersion $N $V]
		} else {
		    set fC [WDB GetContent $N]
		}
		set mkup [my GetMkUp $N 1]
		set C [$mkup set_section $fC $S $C]
		$mkup destroy
	    }
	    if {$A} {
		# Look for category at end of page and insert comment before it
		set Cl [split [string trimright [WDB GetContent $N] \n] \n]
		if {[string trim [lindex $Cl end]] eq "!!!!!!" &&
		    [string trim [lindex $Cl end-2]] eq "!!!!!!" &&
		    [string match "----*" [string trim [lindex $Cl end-3]]] &&
		    [string match "%|*Category*|%" [string trim [lindex $Cl end-1]]]} {
		    set Cl [linsert $Cl end-4 ---- "'''\[$nick\] - [clock format [clock seconds] -gmt 1 -format {%Y-%m-%d %T}]'''" {} $C {}]
		} elseif {[string match "<<categories>>*" [lindex $Cl end]]} {
		    set Cl [linsert $Cl end-1 ---- "'''\[$nick\] - [clock format [clock seconds] -gmt 1 -format {%Y-%m-%d %T}]'''" {} $C {}]
		} else {
		    lappend Cl ---- "'''\[$nick\] - [clock format [clock seconds] -gmt 1 -format {%Y-%m-%d %T}]'''" {} $C
		}
		set C [join $Cl \n]
	    }
	    set C [string map {\t "        "} $C]
	    if {$C eq [WDB GetContent $N]} {
		# No need to save unchanged page
		$cgi redirect /page/[$cgi encode $name] 302
		return
	    }
	    my RPC rpcwriter $N $C $who $name $type [clock seconds]
	} else {
	    my errorPage 501 [armour "Edit failed"] "Editing of images not supported, try [my aTag <a> rel nofollow href /upload/[$cgi encode $name] uploading] the image."
	    return
	}
	$cgi redirect /page/[$cgi encode $name] 302
    }

    method mpm_boundary {} {
        return "----NikitFormBoundary[clock seconds][expr {int(rand()*1000000)}]"
    }

    method upload {N} {
	if {[my read_only]} return
	if {![my getN N]} return
	if {![my has_access $N write]} return
	if {![my loggedIn]} {
	    my login /upload/$N
	    return
	}
	lassign [WDB GetPage $N name date who type access_rules] name date who type ar
	my formatTemplate TEMPLATE:upload HeaderTitle "Upload [armour $name]" PageTitle "Upload [my aTag <a> href /page/[$cgi encode $name] $name]" \
	    SubTitle [my subTitle $date $who "Last edit"] N $N date $date who $who P
    }

    method saveUpload {} {
	if {[my read_only]} return
	if {![my getNParam N]} return
	if {![my has_access $N write]} return
	if {![my loggedIn]} {
	    my formatTemplate TEMPLATE:notloggedin N $N C ""
	    return
	}
	set ud [$cgi getUpload C]
	if {![dict get $ud exists]} {
	    my errorPage 402 [armour "No file specified"] "Upload failed: no file was specified, try to [my aTag <a> rel nofollow href /upload/$N upload] again."
	    return
	}
	set O [$cgi getParam O "" 0]
	lassign [WDB GetPage $N name date who type ] name date who otype
	if {[string length $date] && [string length $who] && ($O ne [list $date $who])} {
	    my formatTemplate TEMPLATE:uploadconflict N $N who [my whoUrl $who]
	    return
	}
	set C [dict get $ud data]
	set type [dict get $ud type]
	set nick [$cgi cookie get wikit_e]
	set who $nick@[$cgi getRequestParam REMOTE_ADDR]
	if {[my isTextPage $type] && [my isTextPage $otype]} {
#	    set C [encoding convertfrom utf-8 $C]
	    set C [string map {\t "        "} $C]
	    if {$C eq [WDB GetContent $N]} {
		# No need to save unchanged page
		$cgi redirect /page/[$cgi encode $name] 302
		return
	    }
	} elseif {[my isImagePage $type] && [my isImagePage $otype]} {
	    # nothing to do here
	} else {
	    my errorPage 501 [armour "Type changed"] "Type of page can not be changed. Type was <b>$otype</b>, new type is <b>$type</b>.<br>Try to [my aTag <a> rel nofollow href /upload/$N upload] again."
	    return
	}
	my RPC rpcwriter $N $C $who $name $type [clock seconds]
	$cgi redirect /page/[$cgi encode $name] 302
    }

    method dec {rpc n def int} {
	set s [$cgi getParam $n $def $int]
	if {[dict get $enc($rpc) $n]} {
	    return [encoding convertfrom utf-8 [base64::decode $s]]
	}
	return $s
    }

    method RPCreturn {txt} {
	if {$oneprocess} {
	    return $txt
	} else {
	    $cgi asText $txt
	    return ""
	}
    }

    method RPC {rpc args} {
	if {$oneprocess} {
	    switch -exact -- $rpc {
		rpcareawriter { set data [my RPCAreaWriter {*}$args] }
		rpcdeleteruser { set data [my RPCDeleterUser {*}$args] }
		rpcinserteruser { set data [my RPCInserterUser {*}$args] }
		rpcpagecreator { set data [my RPCPageCreator {*}$args] }
		rpcrenamer { set data [my RPCRenamer {*}$args] }
		rpcupdateruser { set data [my RPCUpdaterUser {*}$args] }
		rpcupdaterusersid { set data [my RPCUpdaterUserSID {*}$args] }
		rpcwriter { set data [my RPCWriter {*}$args] }
	    }
	} else {
	    set cmd [list http::formatQuery]
	    foreach {key encode} $enc($rpc) value $args {
		lappend cmd $key
		if {$encode} {
		    lappend cmd [base64::encode [encoding convertto utf-8 $value]]
		} else {
		    lappend cmd $value
		}
	    }
	    set tkn [http::geturl http://$writer_host:$writer_port/$rpc -query [{*}$cmd]]
	    http::wait $tkn
	    set data [string trim [http::data $tkn] \n]
	    http::cleanup $tkn
	}

	set datal [split $data \n]
	set stat [lindex $datal 0]
	set msg [join [lrange $datal 1 end] \n]
	if {$stat eq "error"} {
	    error $msg
	} else {
	    return $msg
	}
    }

    method loggedIn {} {
	set nick [$cgi cookie get wikit_e]
	return [expr {[string length $nick] && $nick ne "deleted"}]
    }

    method login {{url ""}} {
	set nick [$cgi getParam nickname "" 0]
	regsub -all {[^A-Za-z0-9_]} $nick {} nick
	if {[string length $nick] && ([WDB CountUser $nick] == 0 || [my userSessionActive $nick])} {
	    $cgi cookie set wikit_e $nick [clock scan "now + 10 days"] /
	    set R [$cgi getParam R "" 0]
	    if {[string length $R]} {
		$cgi redirect $R 302
		return
	    } else {
		$cgi redirect /whoami 302
		return
	    }
	}
	my formatTemplate TEMPLATE:login url [armour $url]
    }

    method whoAmI {} {
	set nick ""
	if {[my loggedIn]} {
	    set nick [$cgi cookie get wikit_e]
	}
	if {[string length $nick]} {
	    set C "You are: [my whoUrl [$cgi cookie get wikit_e]]"
	} else {
	    set C "You are not logged in"
	}
	if {[my session_active d]} {
	    append C "<br>Session user: [dict get $d username]"
	    append C "<br>Session role: [dict get $d role]"
	}
	my formatPage HeaderTitle [armour "Who Am I?"] PageTitle [armour "Who Am I?"] Content $C
    }

    method logout {} {
	$cgi cookie delete wikit_e
	my whoAmI
    }

    method help {} {
	if {![my has_access -1 read]} return
	my formatPage HeaderTitle [armour "Help"] PageTitle [armour "Help"] Content "No help yet"
    }

    method search {} {
	if {![my has_access -1 read]} return
	set S [$cgi getParam S "" 0]
	set C ""
	append C "<form method='get' action='/search' id='search'>\n"
	append C "<fieldset title='Construct a new search' id='sfield'>\n"
	append C [my aTag <legend> "Enter a Search Phrase"]\n
	append C [my aTag <input> name submit type submit id searchsubmit value Search]\n
	append C [my aTag <input> id searchstring title "Append an asterisk (*) to search on prefixes" name S type text value $S tabindex 1]\n
	append C [my aTag <a> rel nofollow href /help Help]\n
	append C [my aTag <input> name _charset_ type hidden value "" tabindex 2]\n
	append C "</fieldset>\n"
	append C "</form>\n"
	if {[string length $S]} {
	    # Prepare queries
	    set key $S
	    set stmtnm "SELECT a.id, a.name, a.date, a.type FROM pages a, pages_content_fts b WHERE a.id = b.id AND length(a.name) > 0 AND b.name MATCH :key and length(b.content) > 1"
	    set stmtct "SELECT a.id, a.name, a.date, a.type, snippet(pages_content_fts, \"^^^^^^^^^^^^\", \"~~~~~~~~~~~~\", \" ... \", -1, -32) as snip FROM pages a, pages_content_fts b WHERE a.id = b.id AND length(a.name) > 0 AND pages_content_fts MATCH :key and length(b.content) > 1"
	    set stmtimg "SELECT a.id, a.name, a.date, a.type FROM pages a, pages_binary b WHERE a.id = b.id"
	    set n 0
	    foreach k [split $key " "] {
		set keynm "key$n"
		set $keynm "*$k*"
		append stmtimg " AND lower(a.name) GLOB lower(:$keynm)"
		incr n
	    }
	    append stmtnm " AND a.date > 0 ORDER BY a.name"
	    append stmtct " AND a.date > 0 ORDER BY a.name"
	    append stmtimg " AND a.date > 0 ORDER BY a.name"
	    # Open the DB in readonly mode for the search
	    tdbc::sqlite3::connection create qdb $::WikiDatabase ;#-readonly 1
	    # Search titles
	    append C [my aTag <h3> class srheader id matches_pages Titles]\n
	    set n 0
	    set malformedmatch 0
	    set Cpages {}
	    if {[catch {
		set qs [qdb prepare $stmtnm]
		$qs foreach -as dicts d {
		    append Cpages [my tag <li> class srtitle [my aTag <a> href /page/[$cgi encode [dict get $d name]] [dict get $d name]]]\n
		    if {[incr n] >= $max_search_results} break
		}
		$qs close
	    } msg]} {
		if {[string match "malformed MATCH expression*" $msg]} {
		    set malformedmatch 1
		} elseif {$msg ne "Function sequence error: result set is exhausted."} {
		    qdb close
		    error $msg
		}
	    }
	    if {$malformedmatch} {
		append C <br>
		append C [my aTag <b> "Malformed MATCH expression. Correct the expression and try searching again."]
		append C <br>
	    } else {
		append C [my tag <ul> class srlist $Cpages]
	    }
	    # Search content
	    append C [my aTag <h3> class srheader id matches_content Content]\n
	    set n 0
	    set malformedmatch 0
	    set Ccontent {}
	    if {[catch {
		set qs [qdb prepare $stmtct]
		$qs foreach -as dicts d {
		    set link [my tag <span> class srtitle [my aTag <a> href /page/[$cgi encode [dict get $d name]] [dict get $d name]]]
		    set date [my aTag <span> class srdate [my datestamp [dict get $d date]]]
		    set dash [my tag <span> class srdate " &mdash; "]
		    set snip [my tag <span> class srsnippet [my formatSnippet [string trim [dict get? $d snip] \ .]]]
		    set il [my tag <div> class srsnippet $date$dash$snip]
		    append Ccontent [my tag <li> class srgroup "$link $il"]\n
		    if {[incr n] >= $max_search_results} break
		}
		$qs close
	    } msg]} {
		if {[string match "malformed MATCH expression*" $msg]} {
		    set malformedmatch 1
		} elseif {$msg ne "Function sequence error: result set is exhausted."} {
		    qdb close
		    error $msg
		}
	    }
	    if {$malformedmatch} {
		append C <br>
		append C [my aTag <b> "Malformed MATCH expression. Correct the expression and try searching again."]
		append C <br>
	    } else {
		append C [my tag <ul> class srlist $Ccontent]
	    }
	    # Search images
	    append C [my aTag <h3> class srheader id matches_pages Images]\n
	    set n 0
	    set stmt [qdb prepare $stmtimg]
	    set Cimage {}
	    $stmt foreach -as dicts d {
		if {[dict get $d type] ne "" && ![string match "text/*" [dict get $d type]]} {
#		    lappend iresults [list id [dict get $d id] name [dict get $d name] date [dict get $d date] type [dict get? $d type] what 2]
		    set l {}
		    lappend l [my timestamp [dict get $d date]]
		    lappend l [my aTag <a> href /page/[$cgi encode [dict get $d name]] [dict get $d name]]
		    lappend l [my tag <a> href /page/[$cgi encode [dict get $d name]] [my aTag <img> alt {} class imglink src /image/[$cgi encode [dict get $d name]] height 100]]
		    lappend Cimage $l
		    if {[incr n] >= $max_search_results} break
		}
	    }
	    $stmt close
	    qdb close
	    append C [my list2Table $Cimage {Date "Page name" Image}]
	}
	my formatPage HeaderTitle [armour "Search"] PageTitle "Search" \
	    SubTitle "Powered by [my aTag <a> href http://www.sqlite.org SQLite] [my aTag <a> href http://www.sqlite.org/fts3.html FTS]" \
	    Content $C
    }

    method tag {tag args} {
	set R [string range $tag 0 end-1]
	if {$tag in {<img> <input>}} {
	    foreach {k v} $args {
		append R " $k='$v'"
	    }
	    append R >
	} else {
	    foreach {k v} [lrange $args 0 end-1] {
		append R " $k='$v'"
	    }
	    append R >
	    append R [lindex $args end]
	    append R [string index $tag 0]/[string range $tag 1 end]
	}
	return $R
    }

    method aTag {tag args} {
	set l {}
	foreach a $args {
	    lappend l [armour $a]
	}
	return [my tag $tag {*}$l]
    }

    method pageNotFound {N} { my errorPage 404 [armour "Page not found"] [armour "Page '$N' could not be found."] }

    method isTextPage {type} {
	return [expr {$type eq "" || [string match "text/*" $type]}]
    }

    method isImagePage {type} {
	return [expr {$type eq "" || [string match "image/*" $type]}]
    }

    method getIntParam {name default} {
	return [$cgi getParam $name $default 1]
    }

    method getNParam {Nnm {name "N"}} {
	upvar $Nnm N
	set N [my getIntParam $name -1]
	if {![string is integer -strict $N] || $N < 0 || $N >= [WDB PageCount]} {
	    my pageNotFound $N
	    return 0
	} else {
	    return 1
	}
	my pageNotFound $N
	return 0
    }

    method getN {Nnm} {
	upvar $Nnm N
	set origN $N
	if {[string is integer -strict $N] && $N >= 0 && $N < [WDB PageCount]} {
	    return 1
	}
	set N [my LookupPage $N 1]
	if {[string is integer -strict $N] && $N >= 0 && $N < [WDB PageCount]} {
	    return 1
	}
	my pageNotFound $origN
	return 0
    }

    method welcome {} {
	set N [my LookupPage ADMIN:Welcome 1]
	if {[string is integer -strict $N] && [my has_access -1 read 0]} {
	    set C [WDB GetContent $N]
	    # include MOTD
	    set N [my LookupPage ADMIN:MOTD 1]
	    if {[string is integer -strict $N]} {
		set C [regsub {%MOTD%} $C [string map {& \\&} [WDB GetContent $N]]]
	    }
	    # include recent changes
	    set RC [my aTag <h4> "Recent changes to this wiki"]\n
	    append RC <ul>\n
	    set threshold [expr {[clock seconds] - $days_in_history * 86400}]
	    set records [WDB RecentChanges $threshold]
	    set n 0
	    foreach record $records {
		append RC [my tag <li> [my aTag <a> href /page/[$cgi encode [dict get $record name]] [dict get $record name]]]\n
		if {[incr n] > 10} {
		    break
		}
	    }
	    append RC </ul>\n
	    append RC [my aTag <a> href /recent "More recent changes ..."]<br>\n
	    set C [regsub {%RC%} $C [string map {& \\&} $RC]]
	    my formatPage HeaderTitle [armour "Welcome to the Tcler's Wiki"] PageTitle [armour "Welcome to the Tcler's Wiki"] Content $C
	} else {
	    $cgi redirect /home 302
	    return
	}
    }

    method brokenLinks {} {
	if {![my has_access -1 read]} return
	set lll {}
	lappend lll [list [armour -1] [armour "Not tested yet"]]
	lappend lll [list [armour -2] [armour  "http::geturl error"]]
	lappend lll [list [armour -3] [armour  "http::geturl returned http::status 'timeout'"]]
	lappend lll [list [armour -4] [armour  "http::geturl returned http::status 'error'"]]
	lappend lll [list [armour -5] [armour  "http::geturl returned http::status 'eof'"]]
	lappend lll [list [armour -6] [armour  "http::geturl returned http::status 'timeout' (timeout was set to 5 seconds)"]]
	lappend lll [list [armour -7] [armour  "http::geturl returned http::status 'ok' but http::ncode was not numeric"]]
	lappend lll [list [armour "> 0"] [armour  "http:ncode when http::geturl returned http::status 'ok'"]]
	set bll {}
	foreach d [WDB BrokenLinks] {
	    set l {}
	    set url [dict get $d url]
	    if {[string length $url] > 80} {
		set url [string range $url 0 80]...
	    }
	    lappend l [my aTag <a> rel nofollow target _blank href [dict get $d url] $url]
	    set name [WDB GetPage [dict get $d page] name]
	    lappend l [dict get $d status_code]
	    lappend l [my aTag <a> href /page/[$cgi encode $name] $name]
	    lappend bll $l
	}
	set C [my aTag <h4> "Status code description"]
	append C [my list2Table $lll {"Status code" "Description"}]
	append C [my aTag <h4> "Links believed broken"]
	append C [my list2Table $bll {URL "Status code" "Wiki Page"}]
	my formatPage HeaderTitle "Broken links" PageTitle "Broken links" Content $C
    }

    method tcl {content as_include include_in_tcl qstring} {

	set result ""
	set lidx 0
	set irefs ""
	set iid 0
	foreach {match0 match1} [regexp -all -indices -inline {<<include:(.*?)>>} $content] {
	    lassign $match0 idx00 idx01
	    lassign $match1 idx10 idx11
	    append result [string range $content $lidx [expr {$idx00-1}]]
	    set id [string trim [string range $content $idx10 $idx11]]
	    lappend irefs $iid $id
	    append result "\n@@@@@@@@@@$iid@@@@@@@@@@\n"
	    set lidx [expr {$idx01+1}]
	    incr iid
	}
	append result [string range $content $lidx end]
	set result [my serverIncludePages $result $irefs]

	if {$include_in_tcl} {
	    # <<include:>> in <!DOCTYPE TCL> page is just included, not evaluated"
	    return [string range $result 14 end]
	}

	set uid [incr tcl_uid]
	set f [open preview_cache/$uid.tcl w]
	set hdrs [$cgi configure headers]
	if {[string length $qstring]} {
	    if {[dict exists $hdrs REQUEST_URI]} {
		if {[string first ? [dict get $hdrs REQUEST_URI]]} {
		    dict append hdrs REQUEST_URI &$qstring
		} else {
		    dict append hdrs REQUEST_URI ?$qstring
		}
	    }
	    if {[dict exists $hdrs QUERY_STRING]} {
		if {[string length [dict get $hdrs QUERY_STRING]]} {
		    dict append hdrs QUERY_STRING &$qstring
		} else {
		    dict set hdrs QUERY_STRING &$qstring
		}
	    } else {
		dict set hdrs QUERY_STRING $qstring
	    }
	}
	puts $f [list set REQUEST_HEADERS $hdrs]
	puts $f [list set REQUEST_BODY \{[$cgi configure body]]
	puts $f ""
	puts $f [string range $result 14 end]
	close $f

	if {[catch {exec [info nameofexecutable] preview_cache/$uid.tcl > preview_cache/$uid.stdout 2> preview_cache/$uid.stderr} msg]} {
	    set emsg ""
	    if {[file exists preview_cache/$uid.stderr]} {
		set f [open preview_cache/$uid.stderr r]
		set emsg [read $f]
		close $f
	    }
	    if {!$as_include} {
		my errorPage 500 [armour "Scripts failed"] [armour $msg\n$emsg]
	    }
	} else {
	    set emsg ""
	    if {[file exists preview_cache/$uid.stdout]} {
		set f [open preview_cache/$uid.stdout r]
		set emsg [read $f]
		close $f
	    }
	    if {!$as_include} {
		my html $emsg
	    }
	}

	file delete -force preview_cache/$uid.tcl
	file delete -force preview_cache/$uid.stdout
	file delete -force preview_cache/$uid.stderr

	if {$as_include} {
	    return $emsg
	}
    }

    method html {content {as_include 0}} {
	set result ""
	set lidx 0
	set irefs ""
	set iid 0
	foreach {match0 match1} [regexp -all -indices -inline {<<include:(.*?)>>} $content] {
	    lassign $match0 idx00 idx01
	    lassign $match1 idx10 idx11
	    append result [string range $content $lidx [expr {$idx00-1}]]
	    set id [string trim [string range $content $idx10 $idx11]]
	    lappend irefs $iid $id
	    append result "\n<div class='include'>@@@@@@@@@@$iid@@@@@@@@@@</div>\n"
	    set lidx [expr {$idx01+1}]
	    incr iid
	}
	append result [string range $content $lidx end]
	if {$as_include} {
	    set result [my serverIncludePages $result $irefs]
	    return $result
	} else {
	    set included_pages {}
	    set result [my serverIncludePages $result $irefs]
	    my formatTemplate TEMPLATE:content content $result
	}
    }

    method home {} {
	set N [my LookupPage home 1]
	if {[string is integer -strict $N]} {
	    my showpage $N
	} else {
	    my welcome
	}
    }

    method sid {d} {
	set ip ""
	if {[$cgi existsRequestParam REMOTE_ADDR]} {
	    set ip [$cgi getRequestParam REMOTE_ADDR]
	}
	set agent ""
	if {[$cgi existsRequestParam HTTP_USER_AGENT]} {
	    set agent [$cgi getRequestParam HTTP_USER_AGENT]
		    }
	return [::sha2::sha256 "[dict get $d username] [dict get $d password] [dict get $d role] $ip $agent"]
    }

    method userSessionActive {nick} {
	set SIDl [$cgi cookie get wikit_sid]
	if {[llength $SIDl]} {
	    foreach SID $SIDl {
		if {[WDB CountSID $SID] == 1} {
		    set d [WDB GetUserBySID $SID]
		    if {[dict get $d username] eq $nick} {
			return 1
		    }
		}
	    }
	}
	return 0
    }

    method session_active {dnm} {
	set SIDl [$cgi cookie get wikit_sid]
	if {[llength $SIDl]} {
	    foreach SID $SIDl {
		if {[WDB CountSID $SID] == 1} {
		    upvar $dnm d
		    set d [WDB GetUserBySID $SID]
		    if {$SID eq [my sid $d]} {
			return 1
		    }
		}
	    }
	}
	return 0
    }

    method RPCUpdaterUserSID {args} {
	if {!$writer} {
	    return [my RPCreturn "error\nTrying to write in non-writer process."]
	}
	if {$oneprocess} {
	    lassign $args uname sid
	} else {
	    set uname [my dec rpcupdaterusersid uname  "" 0]
	    set sid [my dec rpcupdaterusersid sid "" 0]
	}
	if {[catch {WDB UpdateUserSID $uname $sid} msg]} {
	    return [my RPCreturn "error\n$msg\n$::errorInfo"]
	} else {
	    return [my RPCreturn "updatedusersid"]
	}
    }

    method session {action} {
	switch -exact -- $action {
	    "start" {
		set uname [$cgi getParam uname "" 0]
		set pword [$cgi getParam pword "" 0]
		if {[string length $uname] && [string length $pword]} {
		    if {[WDB CountUser $uname] == 1} {
			set d [WDB GetUserByName $uname]
			if {$pword eq [dict get $d password]} {
			    set sid [my sid $d]
			    my RPC rpcupdaterusersid $uname $sid
			    $cgi cookie set wikit_sid $sid [clock scan "now + 1 day"] /
			}
		    }
		}
		$cgi redirect /session 302
	    }
	    "stop" {
		if {[my has_role trusted]} {
		    my session_active d
		    my RPC rpcupdaterusersid [dict get $d username] ""
		}
		$cgi cookie delete wikit_sid
		$cgi redirect http://$server_name:$server_http_port/ 302
	    }
	    default {
		if {[my has_role trusted]} {
		    set C ""
		    set ul {}
		    if {[my has_role admin]} {
			lappend ul [my tag <li> [my tag <a> href /users [armour "Manage users"]]]
		    }
		    lappend ul [my tag <li> [my tag <a> href /session/stop [armour "Stop session"]]]
		    append C [my tag <ul> [join $ul \n]]
		    my formatPage Content $C HeaderTitle "Session" PageTitle "Session"
		} else {
		    if {![$cgi existsRequestParam HTTPS] || ![$cgi getRequestParam HTTPS]} {
			$cgi redirect https://$server_name:$server_https_port/session 302
		    } else {
			my formatTemplate TEMPLATE:sessionlogin
		    }
		}
	    }
	}
    }

    method RPCInserterUser {args} {
	if {!$writer} {
	    return [my RPCreturn "error\nTrying to write in non-writer process."]
	}
	if {$oneprocess} {
	    lassign $args uname pword sid role
	} else {
	    set uname [my dec rpcinserteruser uname "" 0]
	    set pword [my dec rpcinserteruser pword "" 0]
	    set sid   [my dec rpcinserteruser sid   "" 0]
	    set role  [my dec rpcinserteruser role  "" 0]
	}
	if {[catch {WDB InsertUser $uname $pword $sid $role} msg]} {
	    return [my RPCreturn "error\n$msg\n$::errorInfo"]
	} else {
	    return [my RPCreturn "userinserted"]
	}
    }

    method RPCUpdaterUser {args} {
	if {!$writer} {
	    return [my RPCreturn "error\nTrying to write in non-writer process."]
	}
	if {$oneprocess} {
	    lassign $args uname pword sid role
	} else {
	    set uname [my dec rpcinserteruser uname "" 0]
	    set pword [my dec rpcinserteruser pword "" 0]
	    set sid   [my dec rpcinserteruser sid   "" 0]
	    set role  [my dec rpcinserteruser role  "" 0]
	}
	if {[catch {WDB UpdateUser $uname $pword $sid $role} msg]} {
	    return [my RPCreturn "error\n$msg\n$::errorInfo"]
	} else {
	    return [my RPCreturn "userupdated"]
	}
    }

    method RPCDeleterUser {args} {
	if {!$writer} {
	    return [my RPCreturn "error\nTrying to write in non-writer process."]
	}
	if {$oneprocess} {
	    lassign $args uname
	} else {
	    set uname  [my dec rpcdeleteruser uname  "" 0]
	}
	if {[catch {WDB DeleteUser $uname} msg]} {
	    return [my RPCreturn "error\n$msg\n$::errorInfo"]
	} else {
	    return [my RPCreturn "userdeleted"]
	}
    }

    method users {action} {
	if {![my has_role admin]} {
	    my pageNotFound users
	    return
	}
	switch -exact -- $action {
	    "update" {
		set uname [$cgi getParam U "" 0]
		if {[WDB CountUser $uname] != 1} {
		    my pageNotFound users/update
		    return
		}
		set d [WDB GetUserByName $uname]
		my formatTemplate TEMPLATE:updateuser username [armour [dict get $d username]] password [armour [dict get $d password]] sid [armour [dict get $d sid]] role [armour [dict get $d role]]
	    }
	    "update/user" {
		set cancel [$cgi getParam cancel "" 0]
		if { [string tolower $cancel] eq "cancel" } {
		    $cgi redirect /users 302
		    return
		}
		set uname [$cgi getParam uname "" 0]
		set pword [$cgi getParam pword "" 0]
		set sid [$cgi getParam sid "" 0]
		set role [$cgi getParam role "" 0]
		if {[string length $pword] == 0 || [WDB CountUser $uname] != 1} {
		    my pageNotFound users/update/user
		    return
		}
		my RPC rpcupdateruser $uname $pword $sid $role
		$cgi redirect /users 302
	    }
	    "delete" {
		set uname [$cgi getParam U "" 0]
		if {[WDB CountUser $uname] != 1} {
		    my pageNotFound users/delete
		    return
		}
		set d [WDB GetUserByName $uname]
		my formatTemplate TEMPLATE:deleteuser username [armour [dict get $d username]] password [armour [dict get $d password]] sid [armour [dict get $d sid]] role [armour [dict get $d role]]
	    }
	    "delete/user" {
		set cancel [$cgi getParam cancel "" 0]
		if { [string tolower $cancel] eq "cancel" } {
		    $cgi redirect /users 302
		    return
		}
		set uname [$cgi getParam uname "" 0]
		my RPC rpcdeleteruser $uname
		$cgi redirect /users 302
	    }
	    "insert" {
		my formatTemplate TEMPLATE:insertuser
	    }
	    "insert/user" {
		set cancel [$cgi getParam cancel "" 0]
		if { [string tolower $cancel] eq "cancel" } {
		    $cgi redirect /users 302
		    return
		}
		set uname [$cgi getParam uname "" 0]
		set pword [$cgi getParam pword "" 0]
		set role [$cgi getParam role "" 0]
		if {[string length $uname] == 0 || [string length $pword] == 0 || [WDB CountUser $uname] != 0} {
		    my pageNotFound users/insert/user
		    return
		}
		my RPC rpcinserteruser $uname $pword "" $role
		$cgi redirect /users 302
	    }
	    default {
		set ll {}
		lappend ll [my tag <li> [my tag <a> href /session [armour "Manage session"]]]
		lappend ll [my tag <li> [my tag <a> href /users/insert [armour "New user"]]]
		set C [my tag <ul> [join $ll]]
		set tablelist {}
		foreach d [WDB AllUsers] {
		    set l {}
		    lappend l [armour [dict get $d username]]
		    lappend l [armour [dict get $d password]]
		    lappend l [armour [dict get $d role]]
		    lappend l [armour [dict get $d sid]]
		    lappend l [my tag <a> href [armour /users/update?U=[dict get $d username]] Update]
		    lappend l [my tag <a> href [armour /users/delete?U=[dict get $d username]] Delete]
		    lappend tablelist $l
		}
		append C [my list2Table $tablelist {Username Password Role SID Edit Delete}]
		my formatPage Content $C HeaderTitle "Users" PageTitle "Users"
	    }
	}
    }

    method getRefs {text} {
	set mkup [my GetMkUp -1 0]
	set refs [$mkup get_references $text]
	$mkup destroy
	set irefs {}
	foreach r $refs {
	    if {[string is integer -strict $r]} {
		lappend irefs $r
	    } else {
		lassign [my InfoProc $r 1 1] r
		if {[string is integer -strict $r]} {
		    lappend irefs $r
		}
	    }
	}
	return [lsort -unique -integer $irefs]
    }

    method HtmlToIncludes {text} {
	array set pages {}
	set nml {}
	foreach {match0 match1} [regexp -all -indices -inline {<<include:(.*?)>>} $text] {
	    lassign $match1 idx10 idx11
	    lappend nml [string trim [string range $text $idx10 $idx11]]
	}
	foreach nm $nml {
	    set info [my InfoProc $nm 1]
	    lassign $info id name date
	    if {$id == ""} continue
	    regexp {[0-9]+} $id id
	    set pages($id) ""
	}
	array names pages
    }

    method getIncludes {text} {
	if {[string match "<!DOCTYPE*" $text]} {
	    set incs [my HtmlToIncludes $text]
	} else {
	    set mkup [my GetMkUp -1 1]
	    set incs [$mkup get_includes $text]
	    $mkup destroy
	}
	set iincs {}
	foreach r $incs {
	    if {[string is integer -strict $r]} {
		lappend iincs $r
	    } else {
		lassign [my InfoProc $r 1 1] r
		if {[string is integer -strict $r]} {
		    lappend iincs $r
		}
	    }
	}
	return $iincs
    }

    method InternalLinkCommand {query_only name} {
	lassign [my InfoProc $name $query_only 1] id name data type idlink plink
	if {[string length $type] == 0 || [string match "text/*" $type]} {
	    return [dict create link $plink type text]
	} else {
	    return [dict create link $idlink type image]
	}
    }

    method SectionEditLinkCommand {n s} {
	return edit/$n?S=$s
    }

    method BackrefsLinkCommand {name} {
	lassign [my InfoProc $name 1 1] id name data type idling plink
	if {[string is integer -strict $id]} {
	    return "ref/[$cgi encode $name]"
	}
	return ""
    }

    method CategoryLinkCommand {name} {
	lassign [my InfoProc $name 1 1] id iname
	if {[string is integer -strict $id]} {
	    return [dict create name $iname link "/page/[$cgi encode $name]"]
	}
	lassign [my InfoProc "Category $name" 1 1] id iname
	if {[string is integer -strict $id]} {
	    return [dict create name $iname link "/page/[$cgi encode $name]"]
	}
	return ""
    }

    method GetMkUp {N query_only} {
	return [MkUp new \
		    allow_inline_html $allow_inline_html \
		    backrefs_link_command [mycode BackrefsLinkCommand] \
		    category_link_command [mycode CategoryLinkCommand] \
		    internal_link_command [mycode InternalLinkCommand $query_only] \
		    section_edit_link_command [mycode SectionEditLinkCommand $N]]
    }

    method LookupPage {name {query_only 0}} {
	set lcname [string tolower $name]
	if {[info exists namecache($lcname)]} {
	    return $namecache($lcname)
	}
	set pid [lindex [WDB PageByName $name] 0]
	if {![string is integer -strict $pid]} {
	    if {$query_only} {
		return ""
	    } else {
		if {$writer} {
		    set pid [WDB CreatePage $name]
		} else {
		    set pid [my RPC rpcpagecreator $name]
		}
	    }
	}
	set namecache($lcname) $pid
	return $pid
    }

    method InfoProc {ref {query_only 0} {empty_ok 1}} {
	set id [my LookupPage $ref $query_only]
	if {$query_only && ![string is integer -strict $id]} {
	    return $id
	}
	if {[string is integer -strict $id] && !$empty_ok} {
	    if {[string length [WDB GetContent $id]] <= 1} {
		return ""
	    }
	}
	lassign [WDB GetPage $id name date type] name date type
	if {$name eq ""} {
	    set idlink edit/[$cgi encode $name] ;# enter edit mode for missing links
	    set plink /page/[$cgi encode $name]
	} else {
	    if {$type ne "" && ![string match "text/*" $type]} {
		set idlink /image/[$cgi encode $name]
		set plink /page/[$cgi encode $name]
	    } else {
		set page [WDB GetContent $id]
		if {[string length $page] == 0 || $page eq " "} {
		    set idlink /edit/[$cgi encode $name] ;# enter edit mode for empty pages
		    set plink /page/[$cgi encode $name]
		    set date 0
		} else {
		    set idlink /page/[$cgi encode $name]
		    set plink /page/[$cgi encode $name]
		}
	    }
	}
	return [list $id $name $date $type $idlink $plink]
    }

    method process {rpath} {

	set rpath [file split [string trim $rpath /]]
	lassign $rpath path page
	set page [$cgi decode $page]
	set epath [join [lrange $rpath 1 end] /]
	set rt 1

puts "path $path page $page"

	switch -exact -- $path {
	    / - {} { my home }
	    brokenlinks { my brokenLinks }
	    cleared { my cleared }
	    diff { my diff $page }
	    edit { my edit $page}
	    editarea { my editarea $page}
	    help { my help }
	    history { my history $page }
	    htmlpreview { my htmlpreview }
	    image { my image $page }
	    login { my login }
	    logout { my logout }
	    new { my newPage }
	    nextpage { my incrPage $page 1 }
	    page { my page $page }
	    preview { my preview }
	    previouspage { my incrPage $page -1 }
	    query { my query }
	    random { my randomPage }
	    recent { my recent }
	    ref { my backRefs $page }
	    rename { my renamePage $page}
	    revision { my revision $page}
	    rpcareawriter { my RPCAreaWriter }
	    rpcdeleteruser { my RPCDeleterUser }
	    rpcinserteruser { my RPCInserterUser }
	    rpcpagecreator { my RPCPageCreator }
	    rpcrenamer { my RPCRenamer }
	    rpcupdateruser { my RPCUpdaterUser }
	    rpcupdaterusersid { my RPCUpdaterUserSID }
	    rpcwriter { my RPCWriter }
	    rss { my rss }
	    save { my save }
	    savearea { my saveArea }
	    saveupload { my saveUpload }
	    search { my search }
	    session { my session $epath }
	    sitemap { my sitemap }
	    tclpreview { my tclpreview }
	    upload { my upload $page }
	    users { my users $epath }
	    welcome { my welcome }
	    whoami { my whoAmI }
	    default {
		if {[string is integer -strict $path] && $path < [WDB PageCount]} {
		    $cgi redirect /page/$path 302
		} else {
		    set N [my LookupPage $path 1]
		    if {[string is integer -strict $N]} {
			my showpage $N
		    } elseif {[file extension $path] in [list ".html" ".css" ".js"] && [file readable docroot/$path]} {
			set fd [open docroot/$path]
			set content [read $fd]
			close $fd
			switch -exact -- [file extension $path] {
			    ".html" { my html $content }
			    ".js"   { $cgi asText $content text/javascript }
			    ".css"  { $cgi asText $content text/css }
			}
		    } elseif {[file extension $path] eq ".pdf" && [file readable pdf/$path]} {
			set fd [open pdf/$path]
			chan configure $fd -translation binary
			set content [read $fd]
			close $fd
			$cgi asBinary $content application/pdf
		    } else {
			set rt 0
		    }
		}
	    }
	}
	return $rt
    }
}
