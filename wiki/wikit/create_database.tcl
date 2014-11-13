package require tdbc::sqlite3

# Compile sqlite with the following defines:
#
# -DSQLITE_ENABLE_FTS4
# -DSQLITE_ENABLE_FTS3_PARENTHESIS

if {[llength $argv] != 1} {
    puts stderr "Usage: create_database.tcl <filename>"
    exit 1
}

tdbc::sqlite3::connection create db [lindex $argv 0]
db allrows {PRAGMA foreign_keys = ON}
db allrows {PRAGMA journal_mode = WAL}
db allrows {
    CREATE TABLE pages (id INT NOT NULL,
			name TEXT NOT NULL,
			date INT NOT NULL,
			who TEXT NOT NULL,
			type TEXT,
			area TEXT,
			PRIMARY KEY (id))
}
db allrows {
    CREATE TABLE pages_content (id INT NOT NULL,
				content TEXT NOT NULL,
				PRIMARY KEY (id),
				FOREIGN KEY (id) REFERENCES pages(id))
}
db allrows {
    CREATE TABLE changes (id INT NOT NULL,
			  cid INT NOT NULL,
			  date INT NOT NULL,
			  who TEXT NOT NULL,
			  delta TEXT NOT NULL,
			  PRIMARY KEY (id, cid),
			  FOREIGN KEY (id) REFERENCES pages(id))
}
db allrows {
    CREATE TABLE pages_binary (id INT NOT NULL,
			       content BLOB NOT NULL,
			       PRIMARY KEY (id),
			       FOREIGN KEY (id) REFERENCES pages(id))
}
db allrows {
    CREATE TABLE diffs (id INT NOT NULL,
			cid INT NOT NULL,
			did INT NOT NULL,
			fromline INT NOT NULL,
			toline INT NOT NULL,
			old TEXT NOT NULL,
			PRIMARY KEY (id, cid, did),
			FOREIGN KEY (id, cid) REFERENCES changes(id, cid))
}
db allrows {
    CREATE TABLE changes_binary (id INT NOT NULL,
				 cid INT NOT NULL,
				 date INT NOT NULL,
				 who TEXT NOT NULL,
				 type TEXT,
				 content BLOB NOT NULL,
				 PRIMARY KEY (id, cid),
				 FOREIGN KEY (id) REFERENCES pages(id))
}
db allrows {
    CREATE TABLE refs (fromid INT NOT NULL,
		       toid INT NOT NULL,
		       PRIMARY KEY (fromid, toid),
		       FOREIGN KEY (fromid) references pages(id),
		       FOREIGN KEY (toid) references pages(id))
}
db allrows {CREATE INDEX refs_toid_index ON refs (toid)}
db allrows {
    CREATE TABLE includes (id INT NOT NULL,
			   incid INT NOT NULL,
			   PRIMARY KEY (id, incid),
			   FOREIGN KEY (id) references pages(id),
			   FOREIGN KEY (incid) references pages(id))
}
db allrows {CREATE INDEX includes_incid_index ON includes (incid)}
db allrows {CREATE INDEX idx_pages_date ON pages(date)}
db allrows {
    CREATE TABLE users (username TEXT NOT NULL,
			password TEXT NOT NULL,
			sid TEXT NOT NULL,
			role TEXT NOT NULL,
			PRIMARY KEY (username))
}
db allrows {CREATE INDEX idx_users_sid ON users(sid)}
db allrows {CREATE VIRTUAL TABLE pages_content_fts USING fts4(id,name,content)}

set wikitoc "<div class='toc1'>M1
<div class='toc2'><a class='toc' href='/'>M2</a></div>
<div class='toc2'><a class='toc' href='/'>M2</a></div>
<div class='toc3'><a class='toc' href='/'>M2 (last)</a></div>
</div>
<div class='toc1'>M1
<div class='toc2'><a class='toc' href='/'>M2</a></div>
<div class='toc2'><a class='toc' href='/'>M2</a></div>
<div class='toc3'><a class='toc' href='/'>M2 (last)</a></div>
</div>"

set date [clock seconds]
set who "init"
set ids   [list 0                     1                           2]
set names [list "ADMIN:Welcome"       "ADMIN:MOTD"                "ACCESSRULES"]
set pages [list "Welcome page (html)" "Message of the day (html)" {* {all {read write}} admin {}}]
set areas [list "admin"               "admin"                     "admin"]
foreach id $ids name $names page $pages area $areas {
    db allrows {INSERT INTO pages (id, name, date, who, area) VALUES (:id, :name, :date, :who, :area)}
    db allrows {INSERT INTO pages_content (id, content) VALUES (:id, :page)}
    db allrows {INSERT INTO pages_content_fts (id, name, content) VALUES (:id, :name, :page)}
}

db allrows {INSERT INTO users (username, password, sid, role) VALUES ("admin", "admin", "", "admin")}

db close

