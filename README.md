#Nikit: a Wikit compatible SCGI based Wiki

##Requirements

- Tcl 8.6 (with TclOO, tdbc, sqlite3)
- nginx 1.7 with https support
- Tcllib 1.15

##Database

Create new database:

    % tclsh wiki/wikit/create_database.tcl <database_filename>
    % tclsh wiki/wikit/create_templates.tcl <database_filename>

Convert Wikit database:

    % tclsh wiki/wikit/update_database.tcl <database_filename>
    % tclsh wiki/wikit/create_templates.tcl <database_filename>

##Start and stop

The scripts to start and stop the server expect nginx to be in the PATH, at
/usr/local/sbin/nginx, or specified with the NGINXPATH environment variable:

    % export NGINXPATH=<path_to_nginx_executable>

Start the server:

    % ./START.nginx

Stop the server:

    % ./STOP.nginx

##Pages

page name | description
----------|------------
blame | show by who and when lines were added
brokenlinks | show list of broken links
cleared | show cleared pages



diff            : show differences between version of a page.
			N   page number
			?V? page version 1, default is latest version
			?D? page version 2, default is version preceding version 1
edit		: edit a page
			N   page number
			?A? add comment, 0 or 1, default is 0
			?V? version to edit, used when reverting
editarea	: edit page privilege area
			N   page number
help		: show help page
history		: show page history
			N   page number
			?S? start version in history
			?L? number of versions to show
htmlpreview	: preview HTML page, called by preview
			N   page number
image		: show image
			N   page number
			?V? page version, default is latest version
login		: edit-login
logout		: edit-logout
new		: create new page
nextpage	: show next page
			N   page number
page		: show page
			N   page number
			?T? 1 = textual, 0 = rendered, default is 0
			?R? 1 = allow redirect, 0 = no redirect, default is 1
preview		: preview wiki, html or Tcl page
			N   page number
			O   text of page to preview
previouspage	: show previous page
			N   page number
query		: query the SQLite database
			?Q? SQL query
random		: show random page
recent		: show recent edits
			?A? 1 = show gone edits, 0 = don't show gnome edits
ref		: show references to a page
			N   page number
			?A? 1 = return HTML <ul> for inclusion, 0 = return as
			page, default is 0
rename		: rename a page
			N   page number
			?pagename? new page name
revision	: show specific revision of a page
			N   page number
			V   page version
			?T? 1 = textual, 0 = rendered, default is 0
rss		: return RSS change history
save		: save a page
			N   page number
			C   content to save
			O   name of person editing the page
			A   1 = comment, 0 = page
			cancel    cancel = cancel the edit
savearea	: save page area
			N   page number
			C   page area
saveupload	: upload a page
			N   page number
			C   content to save
search		: search the wiki
			?S? search string
session		: session management
sitemap		: show a sitemap
tclpreview	: preview Tcl page, called by preview
			N page number
upload		: upload a page
			N   page number
users		: user management
welcome		: show welcome page
whoami		: show edit and session login information

##Access control

There are 3 ways to be logged in:

- not
- edit logged in
- session logged in (user is given username+password to login)

The way one is logged in is used by the predefined roles:

- all    : each user of the site gets this role
- known  : edit logged in
- trusted: session logged in

Two additional roles exist for trusted users:

- gnome  : edits by this user are not shown in the recent changes list
- admin  : full access to pages and users

These roles can be given to users by an admin user.

Known privileges are none, read, write and admin. These priveleges give access
to the following pages:

- none  : login, logout, session, users, whoami

- read  : blame, brokenlinks, cleared, diff, help, history, htmlpreview, image,
          nextpage, page, preview, previouspage, random, recent, ref, revision,
          rss, search, sitemap, tclpreview, welcome

- write : edit, new, rename, save, saveupload, upload

- area  : editarea, savearea

- admin : read, write, editarea, query, savearea

To check if a page can be accessed by a user, the following steps are taken:

- Get the page 'area' field

- Use the area to look through the ACCESSRULES page for a matching role an list
  of required privilege.

    <area match string> {<role> { ?<privilege> ...? } ...}

- Use the user's list or roles to check if he/she has the proper privilege

Example: Wiki style roles specified in page ACCESSRULES:

    * {all {read write}}
    admin {}

Some users can be given the 'gnome' role to keep the recent changes and RSS
clean.

Example: CMS style roles specified in page ACCESSRULES:

    * {all {read} trusted {write}}
    admin {}

Example: Area of responsability style roles specified in page ACCESSRULES:

    * {all {read}}
    tcl {all {read} tcl {write}}
    tk {all {read} tk {write}}
    admin {}

Create users with roles for the different areas: tcl, tk, ...
