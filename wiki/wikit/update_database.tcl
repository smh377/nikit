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

if 0 {

db allrows {
    ALTER TABLE pages ADD COLUMN area TEXT
}

db allrows {
    CREATE TABLE includes (id INT NOT NULL,
			   incid INT NOT NULL,
			   PRIMARY KEY (id, incid),
			   FOREIGN KEY (id) references pages(id),
			   FOREIGN KEY (incid) references pages(id))
}
db allrows {CREATE INDEX includes_incid_index ON includes (incid)}

db allrows {
    CREATE TABLE users (username TEXT NOT NULL,
			password TEXT NOT NULL,
			sid TEXT NOT NULL,
			role TEXT NOT NULL,
			PRIMARY KEY (username))
}
}


set date [clock seconds]
set who "init"
set ids   [list 37562]
set names [list "ACCESSRULES"]
set pages [list {* {all {read write}} admin {}}]
set areas [list "admin"]
foreach id $ids name $names page $pages area $areas {
    db allrows {INSERT INTO pages (id, name, date, who, area) VALUES (:id, :name, :date, :who, :area)}
    db allrows {INSERT INTO pages_content (id, content) VALUES (:id, :page)}
    db allrows {INSERT INTO pages_content_fts (id, name, content) VALUES (:id, :name, :page)}
}

db allrows {INSERT INTO users (username, password, sid, role) VALUES ("admin", "admin", "", "admin")}

#db allrows {CREATE INDEX idx_users_sid ON users(sid)}


db close

