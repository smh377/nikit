package require nscgi 2.0.0

package provide SCGIWiki 1.0.0

oo::class create SCGIWiki {

    variable server headers body sock cgi deleted_cookies init_cgi buffer

    constructor {args} {
	set buffer ""
	set init_cgi 0
	set deleted_cookies {}
	if {![info exists headers]} {set headers {}}
	if {![info exists body]} {set body {}}
	my configure {*}$args
	set cgi [nscgi new headers $headers body $body init_cgi $init_cgi]
	$cgi input
	fconfigure $sock -translation binary
    }

    destructor {
	$cgi destroy
    }

    method configure {args} {
	if {[llength $args] == 1} {
	    return [set [lindex $args 0]]
	} elseif {([llength $args] % 2) == 0} {
	    foreach {k v} $args {
		set $k $v
	    }
	}
    }

    method send {} {
	puts $sock $buffer
    }

    method process {} {
	if {[catch {
	    set uri [lindex [split [my getRequestParam REQUEST_URI] ?] 0]
	    set rt [$server process [string trim $uri /]]
	} msg errord]} {
	    set C "<h1>Error processing request</h1>"
	    append C "<h2>Parameters</h2>\n"
	    append C "<table>\n"
	    dict for {k v} $headers {
		append C "<tr><td>[armour $k]</td><td>[armour $v]</td></tr>\n"
	    }
	    append C "</table>\n"
	    append C "<h2>Body</h2>\n"
	    append C "<pre>"
	    append C [armour $body]
	    append C "</pre>\n"
	    append C "<h2>Error</h2>\n"
	    append C "<pre>"
	    append C $msg
	    append C "</pre>\n"
	    dict for {k v} $errord {
		append C "<h3>[armour $k]</h3>\n<pre>[armour $v]</pre>\n"
	    }
	    my asText "<!DOCTYPE HTML><html lang='en'><head><title>Error processing request</title></head><body>$C</body></html>" "text/html"
	} elseif {!$rt} {
	    set C "<h1>Unsupported request</h1>"
	    append C "<h2>Parameters</h2>\n"
	    append C "<table>\n"
	    dict for {k v} $headers {
		append C "<tr><td>[armour $k]</td><td>[armour $v]</td></tr>\n"
	    }
	    append C "</table>\n"
	    append C "<h2>Body</h2>\n"
	    append C "<pre>"
	    append C [armour $body]
	    append C "</pre>\n"
	    my asText "<!DOCTYPE HTML><html lang='en'><head><title>Unsupported request</title></head><body>$C</body></html>" "text/html"
	}
	my send
    }

    method asText {content {type {text/plain; charset="utf-8"}} {Headers {}}} {
	set header [$cgi header $type {*}$Headers]
	set buffer [encoding convertto utf-8 "Status: 200 OK\n$header\n$content"]
    }

    method asBinary {content type {Headers {}}} {
	set header [$cgi header $type {*}$Headers]
	set buffer [encoding convertto utf-8 "Status: 200 OK\n$header"]$content
    }

    method redirect {url {status 301}} {
	set header [$cgi redirect $url]
	set buffer [encoding convertto utf-8 "Status: $status\n$header"]
    }

    method notModified {args} {
	set Headers {}
	set type "text/html"
	foreach {k v} $args { set $k $v }
	set header [$cgi header $type {*}$Headers]
	set buffer [encoding convertto utf-8 "Status: 304 Not Modified\n$header"]
    }

    method htmlTimestamp {t} {
	return [clock format $t -gmt 1 -format {%a, %d-%b-%Y %H:%M:%S GMT} -gmt 1]
    }

    method cookie {cmd args} {
	switch -exact -- $cmd {
	    get {
		set nm [lindex $args 0]
		if {$nm in $deleted_cookies} {
		    return ""
		}
		return [$cgi cookie $nm]
	    }
	    set {
		lassign $args k v exp domain
		if {[string length $domain]} {
		    $cgi setCookie -name $k -value $v -expires $exp -path $domain
		} else {
		    $cgi setCookie -name $k -value $v -expires $exp
		}
	    }
	    delete {
		set nm [lindex $args 0]
		$cgi setCookie -name $nm -value deleted -expires [clock scan "now - 1 day"]
		lappend deleted_cookies $nm
	    }
	    default {
		error "Unknown Cookie subcommand: $cmd"
	    }
	}
    }

    method getRequestParam {nm} {
	return [$cgi getRequestParam $nm]
    }

    method existsRequestParam {nm} {
	return [$cgi existsRequestParam $nm]
    }

    method getUpload {nm} {
	if {[$cgi exists $nm]} {
	    set type [$cgi importFile -type $nm]
	    set data [$cgi importFile -data $nm]
	    return [list exists 1 data $data type $type]
	}
	return [list exists 0]
    }

    method getParam {name default {int 0}} {
	if {[$cgi exists $name]} {
	    set val [$cgi value $name]
	    if {$int && ![string is integer -strict $val]} {
		return $default
	    }
	    return $val
	}
	return $default
    }

    method decode {str} { return [$cgi decode $str] }

    method encode {str} { return [$cgi encode $str] }
}
