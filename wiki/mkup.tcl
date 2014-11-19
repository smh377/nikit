package require sha256
package require html
package require TclOO

package provide MkUp 1.0

oo::class create MkUp {

    variable allow_include allow_inline_html backrefs backrefs_link_command category_link_command center code_block \
	discussion discussion_count fixed_block html html_block include_id includes insdelcnt \
	internal_link_command link_id lstack ltype options_block references row_count state \
	table toc line_render_loop_limit

    constructor {args} {
	set allow_include 1
	set allow_inline_html 1
	set line_render_loop_limit 16
#	set backrefs_link_command {}
#	set category_link_command {}
#	set internal_link_command {}
	my configure {*}$args
    }

    destructor {
    }

    method configure {args} { foreach {k v} $args { set $k $v } }

    method cget {k} { return [set $k] }

    method init {data} {
	set data [string map {\r ""} $data]
	set backrefs {}
	set center 0
	set code_block 0
	set discussion_count 0
	set discussion 0
	set fixed_block 0
	set html ""
	set html_block 0
	set include_id 0
	set includes {}
	set link_id 0
	set lstack {}
	set ltype {type EMPTY data ""}
	set options_block 0
	set references {}
	set row_count 0
	set state EMPTY
	set table 0
	set toc {}
	return $data
    }

    method render {data} {
	set data [my init $data]
	foreach line [split $data \n] {
	    foreach ltype [my LineType $line] {
		set ctype [dict get $ltype type]
		if {$ctype ne "COMMENT"} {
		    my NextState $ctype
		    if {$code_block || $ctype eq "PRE"} {
			append html [html::html_entities [dict get $ltype data]]
		    } elseif {$html_block} {
			append html [dict get $ltype data]
		    } else {
			append html [my RenderLine [dict get $ltype data]]
		    }
		}
	    }
	}
	my NextState END
	if {[llength $toc]} {
	    my InsertToc allow_inline_html $allow_inline_html \
		backrefs_link_command $backrefs_link_command \
		category_link_command $category_link_command \
		internal_link_command $internal_link_command
	}
	return $html
    }

    method render_diff {data} {
	set insdelcnt -1
	set ctxt ""
	set result "<pre class='mkup_pre'>"
	foreach l [split $data "\n"] {
	    if { [string match ">>>>>>*" $l] } {
		append result [my RenderDiffLine $ctxt]
		set ctxt ""
		lassign [split [string range $l 6 end] ";"] bltype
		switch -exact -- $bltype {
		    "n" { append result "<div class='mkup_diffnew' id='diff[incr insdelcnt]'>" }
		    "o" { append result "<div class='mkup_diffold' id='diff[incr insdelcnt]'>" }
		    "w" { append result "<div class='mkup_diffwhitespace' id='diff[incr insdelcnt]'>" }
		}
	    } elseif { $l eq "<<<<<<" } {
		append result [my RenderDiffLine $ctxt] "</div>"
		set ctxt ""
	    } else {
		append ctxt $l\n
	    }
	}
	append result [my RenderDiffLine $ctxt]
	append result "</pre>"
	return $result
    }

    method get_includes {data} {
	my render $data
	return $includes
    }

    method get_references {data} {
	my render $data
	return [lsort -unique $references]
    }

    # Missing Wikit line types
    # - Discussions

    method LineType {line} {
	if {[regexp {^###(.*)$} $line -> data]} { return [list {type COMMENT data "" code $data}] }
	if {$code_block} {
	    if {[regexp {^======(tcl|c|cpp|none|)\s*$} $line]} { return [list {type CODE data ""}] }
	    return [list [dict create type LINE data $line]]
	} elseif {$fixed_block} {
	    if {[regexp {^===(tcl|c|cpp|none|)\s*$} $line]} { return [list {type FIXED data ""}] }
	    return [list [dict create type LINE data $line]]
	} elseif {$html_block} {
	    if {[regexp {^<<inlinehtml>>$} $line]} { return [list {type HTML data ""}] }
	    return [list [dict create type LINE data $line]]
	} elseif {$options_block} {
	    if {[regexp {^\+\+\+\s*$} $line]} { return [list {type OPTS data ""}] }
	    if {[regexp {^\s*(.+?)\t\s*(.*)$} $line -> key value]} { return [list [dict create type KEY data $key] [dict create type VALUE data $value]] }
	    if {[regexp {^\s*(.+?)\s{2,}(.*)$} $line -> key value]} { return [list [dict create type KEY data $key] [dict create type VALUE data $value]] }
	    if {[regexp {^\s*(.+?)\s+(.*)$} $line -> key value]} { return [list [dict create type KEY data $key] [dict create type VALUE data $value]] }
	    error "Unexpected line in option-value block: $line"
	} else {
	    if {[string length $line] == 0} { return [list {type EMPTY data ""}] }
	    if {[regexp {^\-\-\-\-[\-]*$} $line]} { return [list {type HR data ""}] }
	    if {[regexp {^======((tcl|c|cpp|none|))\s*$} $line -> data]} {
		if {[string length $data] == 0} {
		    set data sh_tcl
		} elseif {$data in {c tcl}} {
		    set data "sh_$data"
		} else {
		    set data "mkup_pre"
		}
		return [list [dict create type CODE data "" code $data]]
	    }
	    if {[regexp {^\!\!\!\!\!\!$} $line]} { return [list [dict create type CENTER data ""]] }
	    if {[regexp {^===((tcl|c|cpp|none|))\s*$} $line -> data]} { return [list {type FIXED data "" code $data}] }
	    if {$allow_inline_html && [regexp {^<<inlinehtml>>$} $line]} { return [list [dict create type HTML data ""]] }
	    if {[regexp {^<<toc>>$} $line]} { return [list [dict create type TOC data ""]] }
	    if {[regexp {^<<categories>>(.*)$} $line -> links]} { return [list [dict create type CAT links $links data ""]] }
	    if {[regexp {^<<backrefs>>$} $line]} { return [list [dict create type BREF link "" data ""]] }
	    if {[regexp {^<<backrefs:(.*)>>$} $line -> link]} { return [list [dict create type BREF link $link data ""]] }
	    if {[regexp {^<<discussion>>(.*)$} $line -> name]} { return [list [dict create type DISC data $name]] }
	    if {$allow_include && [regexp {^<<include:(.*)>>$} $line -> link]} { return [list [dict create type INC link $link data ""]] }
	    if {[regexp {^\+\+\+\s*$} $line]} { return [list {type OPTS data ""}] }
	    if {[regexp {^[ \t]{3}([\*]+)[ \t](.*)$} $line -> ul data]} { return [list [dict create type UL lvl [string length $ul] data $data]] }
	    if {[regexp {^[ \t]{3}([\d]+)\.[ \t](.*)$} $line -> ol data]} { return [list [dict create type OL lvl [string length $ol] data $data]] }
	    if {[regexp {^[ \t]{3}(.*):[ \t]{3}(.*)} $line -> tag data]} { return [list [dict create type DL data ""] [dict create type DT data $tag] [dict create type DD data $data]] }
	    if {[regexp {^[ \t](.*)$} $line -> data]} { return [list [dict create type PRE data $data]] }
	    if {[regexp {^\*\*\*\*(.+)\*\*\*\*$} $line -> data]} { return [list [dict create type H3 data $data]] }
	    if {[regexp {^\*\*\*(.+)\*\*\*$} $line -> data]} { return [list [dict create type H2 data $data]] }
	    if {[regexp {^\*\*(.+)\*\*$} $line -> data]} { return [list [dict create type H1 data $data]] }
	    if {[regexp {^%\|(.*)\|%$} $line -> data]} {
		set rt {}
		lappend rt [dict create type TR data ""]
		foreach td [split $data |] {
		    lappend rt [dict create type TH data $td]
		}
		return $rt
	    }
	    if {[regexp {^\|(.*)\|$} $line -> data]} {
		set rt {}
		lappend rt [dict create type TR data ""]
		foreach td [split $data |] {
		    lappend rt [dict create type TD data $td]
		}
		return $rt
	    }
	    if {[regexp {^&\|(.*)\|&$} $line -> data]} {
		set rt {}
		lappend rt [dict create type TROE data ""]
		foreach td [split $data |] {
		    lappend rt [dict create type TD data $td]
		}
		return $rt
	    }
	    return [list [dict create type LINE data $line]]
	}
    }

    method SplitUrlLink {text} {
	if { [string match "*%|%*" $text] } { return [split [string map [list "%|%" \1] $text] \1] }
	return [list $text $text]
    }

    method RenderLine {line} {
	# Detect markup
	regsub -all {\\\[} $line "\uFDE0" line
	regsub -all {\[\[} $line "\uFDDF" line
	set linkre1 {\[(https?|ftp|news|mailto|file|irc):([^\s:]\S*[^\]\)\s\.,!\?;:'>"])\]} ; # "
	set linkre2 {(https?|ftp|news|mailto|file|irc):([^\s:][^\s]*[^\]\)\s\.,!\?;:'>"])%\|%([^%]+)%\|%} ; # "
	set linkre3 {(https?|ftp|news|mailto|file|irc):([^\s:]\S*[^\]\)\s\.,!\?;:'>"])} ; # "
	set linkre4 {toc:(#[^\s:][^\s]*[^\]\)\s\.,!\?;:'>"])%\|%([^%]+)%\|%} ; # "
	regsub -all $linkre1 $line "\uFDD5\\1\uFDD8\\2\uFDD5" line
        set r 0
        while {[regexp {\[backrefs:([^\]]+)\]} $line -> name]} {
	    set brefs($r) $name
	    regsub {\[backrefs:([^\]]+)\]} $line "\uFDDD$r\uFDD8\\1\uFDDD" line
	    incr r
	    if {$r > $line_render_loop_limit} break
	}
        set r 0
        while {[regexp {\[([^\]]+)\]} $line -> lname]} {
	    lassign [my SplitUrlLink $lname] rname dname
	    # Check if $rname is existing page here?
	    lappend references $rname
	    set refs($r) $rname
	    set dname [string map [list & \uFDDB] $dname]
	    regsub {\[([^\]]+)\]} $line "\uFDDA$r\uFDD8$dname\uFDDA" line
	    set line [string map [list \uFDDB &] $line]
	    incr r
	    if {$r > $line_render_loop_limit} break
	}
	regsub -all $linkre2 $line "\uFDD6\\1\uFDD8\\2\uFDD8\\3\uFDD6" line
	regsub -all $linkre3 $line "\uFDD7\\1\uFDD8\\2\uFDD8\\1\uFDD8\\2\uFDD7" line
	regsub -all $linkre4 $line "\uFDDC\\1\uFDD8\\2\uFDDC" line
	regsub -all {'''([^']+)'''} $line "\uFDD0\\1\uFDD0" line
	regsub -all {''([^']+)''} $line "\uFDD1\\1\uFDD1" line
	regsub -all {`([^`]+)`} $line "\uFDD2\\1\uFDD2" line
	regsub -all {<<br>>} $line "\uFDD3" line
	regsub -all {<<pipe>>} $line "|" line
	regsub -all {<<nbsp>>} $line "\uFDD4" line
	# Armour data
	set line [html::html_entities $line]
	# Insert rendering
	regsub -all {\uFDD0([^\uFDD0]+)\uFDD0} $line "<b class='mkup_b'>\\1</b>" line
	regsub -all {\uFDD1([^\uFDD1]+)\uFDD1} $line "<i class='mkup_i'>\\1</i>" line
	regsub -all {\uFDD2([^\uFDD2]+)\uFDD2} $line "<span class='mkup_tt'>\\1</span>" line
	regsub -all {\uFDD3} $line "<br class='mkup_br'>" line
	regsub -all {\uFDD4} $line "&nbsp;" line
	set r 0
        while {[regexp {\uFDD5([^\uFDD5\uFDD8]+)\uFDD8([^\uFDD5\uFDD8]+)\uFDD5} $line]} {
	    regsub {\uFDD5([^\uFDD5\uFDD8]+)\uFDD8([^\uFDD5\uFDD8]+)\uFDD5} $line "\[<a class='mkup_a' href='\\1:\\2'>[incr link_id]</a>\]" line
	    incr r
	    if {$r > $line_render_loop_limit} break
	}
	regsub -all {\uFDD6([^\uFDD6\uFDD8]+)\uFDD8([^\uFDD6\uFDD8]+)\uFDD8([^\uFDD6\uFDD8]+)\uFDD6} $line "<a class='mkup_a' href='\\1:\\2'>\\3</a>" line
	regsub -all {\uFDD7([^\uFDD7\uFDD8]+)\uFDD8([^\uFDD7\uFDD8]+)\uFDD8([^\uFDD7\uFDD8]+)\uFDD8([^\uFDD7\uFDD8]+)\uFDD7} $line "<a class='mkup_a' href='\\1:\\2'>\\3:\\4</a>" line
	regsub -all {\uFDDC([^\uFDDC\uFDD8]+)\uFDD8([^\uFDDC\uFDD8]+)\uFDDC} $line "<a class='mkup_a' href='\\1'>\\2</a>" line
	set r 0
        while {[regexp {\uFDDA([^\uFDDA\uFDD8]+)\uFDD8([^\uFDDA\uFDD8]+)\uFDDA} $line -> r name]} {
	    set lnkd [{*}$internal_link_command $refs($r)]
	    if {[string length [dict get $lnkd link]]} {
		switch -exact -- [dict get $lnkd type] {
		    image {
			set iopts ""
			if {[regexp {width\s*=\s*(\d+)} $name -> width]} { lappend iopts " width='$width'" }
			if {[regexp {height\s*=\s*(\d+)} $name -> height]} { lappend iopts " height='$height'" }
			regsub {\uFDDA([^\uFDDA\uFDD8]+)\uFDD8([^\uFDDA\uFDD8]+)\uFDDA} $line "<img class='mkup_img' alt='' src='[dict get $lnkd link]'$iopts>" line
		    }
		    default { regsub {\uFDDA([^\uFDDA\uFDD8]+)\uFDD8([^\uFDDA\uFDD8]+)\uFDDA} $line "<a class='mkup_a' href='[dict get $lnkd link]'>\\2</a>" line }
		}
	    } else {
		regsub {\uFDDA([^\uFDDA\uFDD8]+)\uFDD8([^\uFDDA\uFDD8]+)\uFDDA} $line "\\2" line
	    }
	    incr r
	    if {$r > $line_render_loop_limit} break
	}
	set r 0
        while {[regexp {\uFDDD([^\uFDDD\uFDD8]+)\uFDD8([^\uFDDD\uFDD8]+)\uFDDD} $line -> r name]} {
	    set lnk [{*}$backrefs_link_command $brefs($r)]
	    if {[string length $lnk]} {
		regsub {\uFDDD([^\uFDDD\uFDD8]+)\uFDD8([^\uFDDD\uFDD8]+)\uFDDD} $line "<a class='mkup_a' href='$lnk'>\\2</a>" line
	    } else {
		regsub {\uFDDD([^\uFDDD\uFDD8]+)\uFDD8([^\uFDDD\uFDD8]+)\uFDDD} $line "\\2" line
	    }
	    incr r
	    if {$r > $line_render_loop_limit} break
	}
	regsub -all {\uFDD8} $line ":" line
        regsub -all {\uFDDF} $line "\[" line
        regsub -all {\]\]} $line "\]" line
        regsub -all {\uFDE0} $line "\\\[" line
	return $line
    }

    method RenderDiffLine {line} {
	# Detect markup
	regsub -all {~~~~([^~]+?)~~~~} $line "\uFDD0\\1\uFDD0" line
	regsub -all {\^\^\^\^([^\^]+?)\^\^\^\^} $line "\uFDD1\\1\uFDD1" line
	# Armour data
	set line [html::html_entities $line]
	# Insert rendering
	set r 0
	while {[regexp {\uFDD0([^\uFDD0]+)\uFDD0} $line]} {
	    regsub {\uFDD0([^\uFDD0]+)\uFDD0} $line "<ins class='mkup_diffnew' id='diff[incr insdelcnt]'>\\1</ins>" line
	    incr r
	    if {$r > $line_render_loop_limit} break
	}
	set r 0
	while {[regexp {\uFDD1([^\uFDD1]+)\uFDD1} $line]} {
	    regsub {\uFDD1([^\uFDD1]+)\uFDD1} $line "<del class='mkup_diffold' id='diff[incr insdelcnt]'>\\1</del>" line
	    incr r
	    if {$r > $line_render_loop_limit} break
	}
	return $line
    }

    method TocId {lvl} {
	set id [dict get $ltype data]
	while {$lvl > 1} {
	    foreach d [lreverse $toc] {
		if {[dict get $d type] == $lvl} {
		    append id [dict get $d data]
		    break
		}
	    }
	    incr lvl -1
	}
	return [sha2::sha256 $id]
    }

    method InsertToc {args} {
	if {[llength $toc]} {
	    set txt ""
	    foreach d $toc {
		append txt "   " [string repeat "*" [dict get $d type]] " " toc:\#[dict get $d id]%|%[dict get $d data]%|% \n
	    }
	    set m [MkUp new {*}$args]
	    set html_toc [$m render $txt]
	    $m destroy
	} else {
	    set html_toc ""
	}
	regsub -all "<<toc>>" $html $html_toc html
    }

    method InsertCategories {} {
	append html "<hr><div class='mkup_centered'><table class='mkup_categories'><tr>"
	regsub -all {%\|%} [dict get $ltype links] \uFDD0 links
	foreach link [split $links |] {
	    lassign [split $link \uFDD0] pname lname
	    set pname [string trim $pname]
	    set lname [string trim $lname]
	    if {[string length $lname] == 0} { set lname $pname }
	    set lnkd [{*}$category_link_command $pname]
	    if {[dict size $lnkd]} {
		append html "<td class='mkup_td'><a class='mkup_a' href='[dict get $lnkd link]'>[html::html_entities [dict get $lnkd name]]</a></td>"
		lappend references [dict get $lnkd name]
	    } else {
		append html "<td class='mkup_td'>[html::html_entities $lname]</td>"
	    }
	}
	append html "</tr></table></div>"
    }

    method OpenL {} {
	if {[llength $lstack] < [dict get $ltype lvl]} {
	    while {[llength $lstack] < [dict get $ltype lvl]} {
		append html "<[dict get $ltype type] class='mkup_[dict get $ltype type]'><li class='mkup_li'>"
		lappend lstack [dict get $ltype type]
	    }
	} else {
	    while {[llength $lstack] > [dict get $ltype lvl]} {
		append html "</li></[lindex $lstack end]>"
		set lstack [lrange $lstack 0 end-1]
	    }
	    if {[lindex $lstack end] eq [dict get $ltype type]} {
		append html "</li><li class='mkup_li'>"
	    } else {
		append html "</li></[lindex $lstack end]><[dict get $ltype type] class='mkup_[dict get $ltype type]'><li class='mkup_li'>"
		lset lstack end [dict get $ltype type]
	    }
	}
    }

    method OpenState {cstate} {
	switch -exact -- $cstate {
	    BREF    { append html "<div class='mkup_div_brefs' id='mkupbackref[llength $backrefs]'>Fetching backrefs...</div>" ; lappend backrefs [dict get $ltype link] }
	    CAT     { if {$discussion} { append html "</div>"; set discussion 0 } ; my InsertCategories }
	    CENTER  { if {$center} { append html "</div>" ; set center 0 } else { append html "<div class='mkup_centered'>" ; set center 1 } }
	    CODE    { append html "<pre class='[dict get $ltype code]'>" ; set code_block 1 }
	    DD      { append html "<dd class='mkup_dd'>" }
	    DISC    {
		if {$discussion} { append html "</div>" }
		if {!$discussion || [string length [dict get $ltype data]]} {
		    append html "<p></p><button class='mkup_button' type='button' id='togglediscussionbutton$discussion_count' onclick='toggleDiscussion($discussion_count);'>"
		    if {[string length [dict get $ltype data]]} {
			append html "Show</button>&nbsp;<b class='mkup_b'>[html::html_entities [dict get $ltype data]]</b>"
		    } else {
			append html "Show discussion</button>"
		    }
		    append html "<div class='mkup_discussion' id='discussion$discussion_count'>"
		    set discussion 1
		    incr discussion_count
		} else {
		    set discussion 0
		}
	    }
	    DL      { append html "<dl class='mkup_dl'>" }
	    DT      { append html "<dt class='mkup_dt'>" }
	    EMPTY   { }
	    END     { if {$discussion} { append html "</div>" } }
	    FIXED   { append html "<pre class='mkup_pre'>" ; set fixed_block 1 }
	    H1      { set id [my TocId 1] ; append html "<a class='mkup_a' id='$id'><h1 class='mkup_h1'>" ; lappend toc [dict create type 1 id $id data [dict get $ltype data]] }
	    H2      { set id [my TocId 2] ; append html "<a class='mkup_a' id='$id'><h2 class='mkup_h2'>" ; lappend toc [dict create type 2 id $id data [dict get $ltype data]] }
	    H3      { set id [my TocId 3] ; append html "<a class='mkup_a' id='$id'><h3 class='mkup_h3'>" ; lappend toc [dict create type 3 id $id data [dict get $ltype data]] }
	    HR      { append html "<hr class='mkup_hr'>" }
	    HTML    { set html_block 1 }
	    INC     {
		set iid [incr include_id]
		lappend includes $iid [dict get $ltype link]
		append html "<div class='mkup_include'>@@@@@@@@@@${iid}@@@@@@@@@@</div>"
	    }
	    KEY     { append html "<tr class='mkup_tr_key'><td class='mkup_td_key'>" }
	    LI      { append html "<li class='mkup_li'>" }
	    LINE    { append html "<p class='mkup_p'>" }
	    OL - UL { my OpenL }
	    OPTS    { append html "<table class='mkup_options'>" ; set options_block 1 }
	    PRE     { append html "<pre class='mkup_pre'>" }
	    TD      { append html "<td class='mkup_td'>" }
	    TH      { append html "<th class='mkup_th'>" }
	    TOC     { append html "<<toc>>" }
	    TR      { if {!$table} { append html "<table class='mkup_data'>" } ; append html "<tr class='mkup_tr'>" ; incr table }
	    TROE    { if {!$table} { append html "<table class='mkup_data'>" } ; append html "<tr class='mkup_tr" [expr {$table%2?"odd":"even"}] "'>" ; incr table }
	    VALUE   { append html "<td class='mkup_td'>" }
	    default { error "Unknow state: $cstate" }
	}
    }

    method CloseState {cstate} {
	switch -exact -- $cstate {
	    BREF    { }
	    CAT     { }
	    CENTER  { }
	    CODE    { append html "</pre>" ; set code_block 0 }
	    DD      { append html "</dd>" }
	    DISC    { }
	    DL      { append html "</dl>" }
	    DT      { append html "</dt>" }
	    EMPTY   { append html "" }
	    FIXED   { append html "</pre>" ; set fixed_block 0 }
	    H1      { append html "</h1></a>" }
	    H2      { append html "</h2></a>" }
	    H3      { append html "</h3></a>" }
	    HR      { append html "" }
	    HTML    { set html_block 0 }
	    INC     { }
	    KEY     { append html "</td>" }
	    LI      { append html "</li>" }
	    LINE    { append html "</p>" }
	    OL - UL { foreach l [lreverse $lstack] { append html "</li></$l>" } ; set lstack {} }
	    OPTS    { append html "</table>" ; set options_block 0 }
	    PRE     { append html "</pre>" }
	    TABLE   { append html "</table>" ; set table 0 }
	    TD      { append html "</td>" }
	    TH      { append html "</th>" }
	    TOC     { }
	    TR - TROE { append html "</tr>" }
	    VALUE   { append html "</td></tr>" }
	    default { error "Unknow state: $cstate" }
	}
    }

    method State2State { ostate nstate } {
	switch -glob -- $ostate-$nstate {
	    OL-OL - OL-UL - UL-OL - UL-UL { my OpenState $nstate }
	    PRE-PRE - LINE-LINE { append html "\n" }
	    DL-DT   { my OpenState DT }
	    DD-DL   { my CloseState DD }
	    DD-*    { my CloseState DD ; my CloseState DL ; my OpenState $nstate }
	    default { my CloseState $ostate ; my OpenState $nstate }
	}
    }

    method NextState {nstate} {
	if {$code_block || $html_block || $fixed_block} {
	    switch -exact -- $state {
		CODE - FIXED - HTML {
		    switch -exact -- $nstate {
			LINE { }
			CODE - FIXED { my CloseState $nstate }
			default { error "Unknow state transition: $state -> $nstate" }
		    }
		}
		LINE {
		    switch -exact -- $nstate {
			CODE - FIXED - HTML { my CloseState $nstate }
			LINE { my State2State LINE LINE }
			default { error "Unknow state transition: $state -> $nstate" }
		    }
		}
		default { error "Unknow state transition: $state -> $nstate" }
	    }
	} elseif {$options_block} {
	    switch -exact -- $state {
		OPTS {
		    switch -exact -- $nstate {
			KEY { my OpenState $nstate }
			default { error "Unknow state transition: $state -> $nstate" }
		    }
		}
		KEY {
		    switch -exact -- $nstate {
			VALUE { my State2State $state $nstate }
			default { error "Unknow state transition: $state -> $nstate" }
		    }
		}
		VALUE {
		    switch -exact -- $nstate {
			KEY  { my State2State $state $nstate }
			OPTS { my CloseState $state ; my CloseState $nstate }
			default { error "Unknow state transition: $state -> $nstate" }
		    }
		}
		default { error "Unknow state transition: $state -> $nstate" }
	    }
	} elseif {$table} {
	    switch -exact -- $state {
		TR - TROE {
		    switch -exact -- $nstate {
			TH - TD { my OpenState $nstate }
			default { error "Unknow state transition: $state -> $nstate" }
		    }
		}
		TH {
		    switch -exact -- $nstate {
			TH { my State2State $state $nstate }
			TR - TROE { my CloseState $state ; my CloseState $nstate ; my OpenState $nstate }
			default { my CloseState $state ; my CloseState TR ; my CloseState TABLE ; my OpenState $nstate }
		    }
		}
		TD {
		    switch -exact -- $nstate {
			TD { my State2State $state $nstate }
			TR - TROE { my CloseState $state ; my CloseState $nstate ; my OpenState $nstate }
			default { my CloseState $state ; my CloseState TR ; my CloseState TABLE ; my OpenState $nstate }
		    }
		}
		default { error "Unknow state transition: $state -> $nstate" }
	    }
	} else {
	    switch -exact -- $state {
		BREF - CAT - CENTER - DD - DISC - DL - DT - EMPTY - H1 - H2 - H3 - HR - INC - LINE - OL - PRE - TOC - UL {
		    my State2State $state $nstate
		}
		CODE - FIXED - HTML - OPTS - TD - TH { my OpenState $nstate }
		default { error "Unknow state transition: $state -> $nstate" }
	    }
	}
	set state $nstate
    }
}
