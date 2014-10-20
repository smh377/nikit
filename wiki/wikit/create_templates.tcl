package require tdbc::sqlite3

if {[llength $argv] != 1} {
    puts stderr "Usage: create_templates.tcl <filename>"
    exit 1
}

namespace eval WikiTemplates {

################################################################################

    set content {${content}}

################################################################################

    set cssjs {<!DOCTYPE HTMLPART><meta charset="UTF-8">
<link rel='stylesheet' href='/css/wikit.css' type='text/css'>
<link rel='stylesheet' href='/css/tooltips.css' type='text/css'>
<link rel='stylesheet' href='/css/sorttable.css' type='text/css'>
<script type='text/javascript' src='/scripts/sh_main.js'></script>
<script type='text/javascript' src='/scripts/sh_tcl.js'></script>
<script type='text/javascript' src='/scripts/sh_c.js'></script>
<script type='text/javascript' src='/scripts/sh_cpp.js'></script>
<link rel='stylesheet' href='/css/sh_style.css' type='text/css'>}

################################################################################

    set edit {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>${HeaderTitle}</title>
<<include:TEMPLATE:cssjs>>
</head>
<body onload='sh_highlightDocument();'>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>${PageTitle}</div>
      <div id='updated' class='updated'>${SubTitle}</div>
    </div>
    <div class='editcontents'>
      <form method='post' action='/save' id='edit'>
        <div id='helptext'>
	  <br >
	  <b>Editing quick-reference:</b> <button type='button' id='hidehelpbutton' onclick='hideEditHelp();'>Hide Help</button>
	  <br >
	  <ul>
	  <li><b>LINK</b> to <b>[<a href='../6' target='_blank'>Wiki formatting rules</a>]</b> - or to <b><a href='http://here.com/' target='_blank'>http://here.com/</a></b> - use <b>[http://here.com/]</b> to show as <b>[<a href='http://here.com/' target='_blank'>1</a>]</b>. The string used to display the link can be specified by adding <b><span class='tt'>%|%string%|%</span></b> to the end of the link.</li>
	  <li><b>BULLETS</b> are lines with 3 spaces, an asterisk, a space - the item must be one (wrapped) line</li>
	  <li><b>NUMBERED LISTS</b> are lines with 3 spaces, a one, a dot, a space - the item must be one (wrapped) line</li>
	  <li><b>PARAGRAPHS</b> are split with empty lines</li>
	  <li><b>UNFORMATTED TEXT</b> starts with white space or is enclosed in lines containing <span class='tt'>======</span></li>
	  <li><b>FIXED WIDTH FORMATTED</b> text is enclosed in lines containing <span class='tt'>===</span></li>
	  <li><b>HIGHLIGHTS</b> are indicated by groups of single quotes - use two for <b>''</b> <i>italics</i> <b>''</b>, three for <b>'''bold'''</b>. Back-quotes can be used for <b>`</b><span class='tt'>tele-type</span><b>`</b>.</li>
	  <li><b>SECTIONS</b> can be separated with a horizontal line - insert a line containing just 4 dashes</li>
	  <li><b>HEADERS</b> can be specified with lines containing <b>**Header level 1**</b>, <b>***Header level 2***</b> or <b>****Header level 3****</b></li>
	  <li><b>TABLE</b> rows can be specified as <b><span class='tt'>|data|data|data|</span></b>, a <b>header</b> row as <b><span class='tt'>%|data|data|data|%</span></b> and background of even and odd rows is <b>colored differently</b> when rows are specified as <b><span class='tt'>&amp;|data|data|data|&amp;</span></b></li>
	  <li><b>CENTER</b> an area by enclosing it in lines containing <b><span class='tt'>!!!!!!</span></b></li>
	  <li><b>BACK REFERENCES</b> to the page being edited can be included with a line containing <b><span class='tt'>&lt;&lt;backrefs&gt;&gt;</span></b>, back references to any page can be included with a line containing <b><span class='tt'>&lt;&lt;backrefs:Wiki formatting rules&gt;&gt;</span></b>, a <b>link to back-references</b> to any page can be included as <b><span class='tt'>[backrefs:Wiki formatting rules]</span></b></li>
	  </ul>
        </div>
        <div class='toolbar'>
  	  <button type='submit' class='editbutton' id='savebutton' name='save' value='Save your changes' onmouseout='popUp(event,"tip_save")' onmouseover='popUp(event,"tip_save")'><img alt='' src='/page_save.png'></button><span id='tip_save' class='tip'>Save</span>
          <button type='button' class='editbutton' id='previewbuttonw' onclick='previewPageNewWindow(${N});' onmouseout='popUp(event,"tip_preview_new_window")' onmouseover='popUp(event,"tip_preview_new_window")'><img alt='' src='/page_white_magnify.png'></button><span id='tip_preview_new_window' class='tip'>Preview in new window</span>
	  <button type='submit' class='editbutton' id='cancelbutton' name='cancel' value='Cancel' onmouseout='popUp(event,"tip_cancel")' onmouseover='popUp(event,"tip_cancel")'><img alt='' src='/cancel.png'></button><span id='tip_cancel' class='tip'>Cancel</span>
	  &nbsp; &nbsp; &nbsp;
	  <button type='button' class='editbutton' onClick='bold("editarea");' onmouseout='popUp(event,"tip_bold")' onmouseover='popUp(event,"tip_bold")'><img alt='' src='/text_bold.png'></button><span id='tip_bold' class='tip'>Bold</span>
	  <button type='button' class='editbutton' onClick='italic("editarea");' onmouseout='popUp(event,"tip_italic")' onmouseover='popUp(event,"tip_italic")'><img alt='' src='/text_italic.png'></button><span id='tip_italic' class='tip'>Italic</span>
	  <button type='button' class='editbutton' onClick='teletype("editarea");' onmouseout='popUp(event,"tip_teletype")' onmouseover='popUp(event,"tip_teletype")'><img alt='' src='/text_teletype.png'></button><span id='tip_teletype' class='tip'>TeleType</span>
	  <button type='button' class='editbutton' onClick='heading1("editarea");' onmouseout='popUp(event,"tip_heading1")' onmouseover='popUp(event,"tip_heading1")'><img alt='' src='/text_heading_1.png'></button><span id='tip_heading1' class='tip'>Heading 1</span>
	  <button type='button' class='editbutton' onClick='heading2("editarea");' onmouseout='popUp(event,"tip_heading2")' onmouseover='popUp(event,"tip_heading2")'><img alt='' src='/text_heading_2.png'></button><span id='tip_heading2' class='tip'>Heading 2</span>
	  <button type='button' class='editbutton' onClick='heading3("editarea");' onmouseout='popUp(event,"tip_heading3")' onmouseover='popUp(event,"tip_heading3")'><img alt='' src='/text_heading_3.png'></button><span id='tip_heading3' class='tip'>Heading 3</span>
	  <button type='button' class='editbutton' onClick='hruler("editarea");' onmouseout='popUp(event,"tip_hruler")' onmouseover='popUp(event,"tip_hruler")'><img alt='' src='/text_horizontalrule.png'></button><span id='tip_hruler' class='tip'>Horizontal Rule</span>
	  <button type='button' class='editbutton' onClick='list_bullets("editarea");' onmouseout='popUp(event,"tip_list_bullets")' onmouseover='popUp(event,"tip_list_bullets")'><img alt='' src='/text_list_bullets.png'></button><span id='tip_list_bullets' class='tip'>List with Bullets</span>
	  <button type='button' class='editbutton' onClick='list_numbers("editarea");' onmouseout='popUp(event,"tip_list_numbers")' onmouseover='popUp(event,"tip_list_numbers")'><img alt='' src='/text_list_numbers.png'></button><span id='tip_list_numbers' class='tip'>Numbered list</span>
	  <button type='button' class='editbutton' onClick='align_center("editarea");' onmouseout='popUp(event,"tip_align_center")' onmouseover='popUp(event,"tip_align_center")'><img alt='' src='/text_align_center.png'></button><span id='tip_align_center' class='tip'>Center</span>
	  <button type='button' class='editbutton' onClick='wiki_link("editarea");' onmouseout='popUp(event,"tip_wiki_link")' onmouseover='popUp(event,"tip_wiki_link")'><img alt='' src='/link.png'></button><span id='tip_wiki_link' class='tip'>Wiki link</span>
	  <button type='button' class='editbutton' onClick='url_link("editarea");' onmouseout='popUp(event,"tip_url_link")' onmouseover='popUp(event,"tip_url_link")'><img alt='' src='/world_link.png'></button><span id='tip_url_link' class='tip'>World link</span>
	  <button type='button' class='editbutton' onClick='img_link("editarea");' onmouseout='popUp(event,"tip_img_link")' onmouseover='popUp(event,"tip_img_link")'><img alt='' src='/photo_link.png'></button><span id='tip_img_link' class='tip'>Image link</span>
	  <button type='button' class='editbutton' onClick='code("editarea");' onmouseout='popUp(event,"tip_code")' onmouseover='popUp(event,"tip_code")'><img alt='' src='/script_code.png'></button><span id='tip_code' class='tip'>Script</span>
	  <button type='button' class='editbutton' onClick='table("editarea");' onmouseout='popUp(event,"tip_table")' onmouseover='popUp(event,"tip_table")'><img alt='' src='/table.png'></button><span id='tip_table' class='tip'>Table</span>
	  &nbsp; &nbsp; &nbsp;
	  <button type='button' class='editbutton' id='helpbuttoni' onclick='editHelp();' onmouseout='popUp(event,"tip_help")' onmouseover='popUp(event,"tip_help")'><img alt='' src='/help.png'></button><span id='tip_help' class='tip'>Help</span>
        </div>
	<textarea id='editarea' rows='32' cols='72' style='width:100%' name='C' tabindex='1' autofocus>${C}</textarea>
        <input name='O' type='hidden' value='${date} ${who}' tabindex='2'>
	<input name='_charset_' type='hidden' value='' tabindex='3'>
	<input name='N' type='hidden' value='${N}' tabindex='4'>
	<input name='S' type='hidden' value='${S}' tabindex='5'>
	<input name='V' type='hidden' value='${V}' tabindex='6'>
	<input name='A' type='hidden' value='${A}' tabindex='7'>
	<input name='save' type='submit' value='Save your changes'>
	<button type='button' id='previewbuttonb' onclick='previewPageNewWindow(${N});'>Preview</button>
	<input name='cancel' type='submit' value='Cancel'>
	<button type='button' id='helpbuttonb' onclick='editHelp();'>Help</button>
      </form>
      <hr >
      <form id='previewForm' method='post' target='_blank' action='/preview'>
	<textarea id='previewData' rows='32' cols='72' style='width:100%' name='P' tabindex='1'></textarea>
	<input name='N' type='hidden' value='${N}'>
      </form>
    </div>
  </div>
  <script type='text/javascript' src='/scripts/wiki.js'></script>
</body>
</html>}

################################################################################

    set editarea {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>${HeaderTitle}</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>${PageTitle}</div>
      <div id='updated' class='updated'>${SubTitle}</div>
    </div>
    <div class='editcontents'>
      <form method='post' action='/savearea' id='edit'>
	<textarea id='editarea' rows='32' cols='72' style='width:100%' name='C' tabindex='1' autofocus>${C}</textarea>
	<input name='_charset_' type='hidden' value='' tabindex='3'>
	<input name='N' type='hidden' value='${N}' tabindex='4'>
	<input name='save' type='submit' value='Save your changes'>
	<input name='cancel' type='submit' value='Cancel'>
      </form>
      <hr >
    </div>
  </div>
  <script type='text/javascript' src='/scripts/wiki.js'></script>
</body>
</html>}

################################################################################

    set preview {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>${Title}</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
${Content}
</body>
</html>}

################################################################################

    set error {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>${Title}</title>
</head>
<body>
${Content}
</body>
</html>}

################################################################################

    set login {<!DOCTYPE html>
<!-- saved from url=(0040)http://getbootstrap.com/examples/signin/ -->
<html lang="en"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="">
    <meta name="author" content="">
    <link rel="icon" href="http://getbootstrap.com/favicon.ico">

    <title>Signin Template for Bootstrap</title>

    <!-- Bootstrap core CSS -->
    <link href="/css/bootstrap.min.css" rel="stylesheet">

    <!-- Custom styles for this template -->
    <link href="/css/signin.css" rel="stylesheet">

    <script src="/scripts/ie-emulation-modes-warning.js"></script>

    <!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
  <link rel="stylesheet" type="text/css" href="chrome-extension://cgndfbhngibokieehnjhbjkkhbfmhojo/css/validation.css"></head>

  <body>

    <div class="container">

      <form class="form-signin" role="form" action="/login" id="login">
        <h2 class="form-signin-heading">Please sign in</h2>
        <p>Please choose a nickname to identify yourself on this Wiki.</p>
        <input type="text" class="form-control" placeholder="Nickname" required="" autofocus="" name="nickname">
	<input name='R' type='hidden' value='${url}'>
        <button class="btn btn-lg btn-primary btn-block" type="submit">Sign in</button>
      </form>

    </div> <!-- /container -->


    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/scripts/ie10-viewport-bug-workaround.js"></script>

</body></html>}

################################################################################

    set sessionlogin {<!DOCTYPE html>
<!-- saved from url=(0040)http://getbootstrap.com/examples/signin/ -->
<html lang="en"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="">
    <meta name="author" content="">
    <link rel="icon" href="http://getbootstrap.com/favicon.ico">

    <title>Signin Template for Bootstrap</title>

    <!-- Bootstrap core CSS -->
    <link href="/css/bootstrap.min.css" rel="stylesheet">

    <!-- Custom styles for this template -->
    <link href="/css/signin.css" rel="stylesheet">

    <script src="/scripts/ie-emulation-modes-warning.js"></script>

    <!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
  <link rel="stylesheet" type="text/css" href="chrome-extension://cgndfbhngibokieehnjhbjkkhbfmhojo/css/validation.css"></head>

  <body>

    <div class="container">

      <form class="form-signin" role="form" action="/session/start" id="session">
        <h2 class="form-signin-heading">Please sign in</h2>
        <input type="text" class="form-control" placeholder="Username" required="" autofocus="" name="uname">
        <input type="password" class="form-control" placeholder="Password" required="" name="pword">
        <button class="btn btn-lg btn-primary btn-block" type="submit">Sign in</button>
      </form>

    </div> <!-- /container -->


    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/scripts/ie10-viewport-bug-workaround.js"></script>
  

</body></html>}

################################################################################

    set updateuser {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>Users</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>Update user</div>
    </div>
  </div>
  <h2>Update user &quot;${username}&quot;</h2>
  <form method='post' action='/users/update/user' id='new'>
    <fieldset title='Update' id='update'>
      <table>
      <tr><td>Password</td><td><input title='Password' name='pword' type='text' value='${password}' tabindex='1' size='80' autofocus></td></tr>
      <tr><td>SID</td><td><input title='SID' name='sid' type='text' value='${sid}' tabindex='2' size='80'></td></tr>
      <tr><td>Role</td><td><input title='Role' name='role' type='text' value='${role}' tabindex='3' size='80'></td></tr>
       </table>
     <input name='update' type='submit' value='Update'>
     <input name='cancel' type='submit' value='Cancel'>
    </fieldset>
    <input name='uname' type='hidden' value='${username}'>
  </form>
</body>
</html>}

################################################################################

    set deleteuser {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>Users</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>Delete user</div>
    </div>
  </div>
  <h2>Delete user</h2>
  <form method='post' action='/users/delete/user' id='new'>
    <fieldset title='Delete' id='delete'>
      <table>
      <tr><td>Username</td><td>${username}</td></tr>
      <tr><td>Password</td><td>${password}</td></tr>
      <tr><td>SID</td><td>${sid}</td></tr>
      <tr><td>Role</td><td>${role}</td></tr>
       </table>
     <input name='update' type='submit' value='Delete'>
     <input name='cancel' type='submit' value='Cancel'>
    </fieldset>
    <input name='uname' type='hidden' value='${username}'>
  </form>
</body>
</html>}

################################################################################

    set insertuser {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>Users</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>Insert user</div>
    </div>
  </div>
  <h2>Insert user</h2>
  <form method='post' action='/users/insert/user' id='new'>
    <fieldset title='Insert' id='insert'>
      <table>
      <tr><td>Username</td><td><input title='Username' name='uname' type='text' value='' tabindex='1' size='80' autofocus></td></tr>
      <tr><td>Password</td><td><input title='Password' name='pword' type='text' value='' tabindex='1' size='80'></td></tr>
      <tr><td>SID</td><td><input title='SID' name='sid' type='text' value='' tabindex='2' size='80'></td></tr>
      <tr><td>Role</td><td><input title='Role' name='role' type='text' value='' tabindex='3' size='80'></td></tr>
       </table>
     <input name='update' type='submit' value='Insert'>
     <input name='cancel' type='submit' value='Cancel'>
    </fieldset>
  </form>
</body>
</html>}

################################################################################

    set new {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>New page</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>Create new page</div>
    </div>
  </div>
  <p>Enter a new page name:</p>
  <form method='post' action='/new' id='new'>
    <fieldset title='New' id='login'>
      <input title='Name' name='pagename' type='text' value='' tabindex='1' size='80' autofocus>
      <input name='save' type='submit' value='Create'>
    </fieldset>
  </form>
  <script type='text/javascript' src='/scripts/wiki.js'></script>
</body>
</html>}

################################################################################

    set rename {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>Rename page</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>Rename page</div>
    </div>
  </div>
  <p>Enter a new name for page ${N}.</p>
  <p>Current name is: ${oldname}</p>
  <form method='post' action='/rename' id='rename'>
    <fieldset title='Rename' id='login'>
      <input title='Name' name='pagename' type='text' value='' tabindex='1' size='80' autofocus>
      <input name='save' type='submit' value='Rename'>
      <input name='N' type='hidden' value='${N}'>
    </fieldset>
  </form>
  <script type='text/javascript' src='/scripts/wiki.js'></script>
</body>
</html>}

################################################################################

    set page {<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Tclers wiki">
    <meta name="author" content="">
    <link rel="icon" href="/img/favicon.ico">

    <title>${HeaderTitle}</title>

    <!-- Bootstrap core CSS -->
    <link href="/css/bootstrap.min.css" rel="stylesheet">
    <link rel='stylesheet' href='/css/sh_style.css' type='text/css'>}

    <!-- Custom styles for this template -->
    <link href="/css/dashboard.css" rel="stylesheet">

    <!-- Just for debugging purposes. Don't actually copy these 2 lines! -->
    <!--[if lt IE 9]><script src="../../assets/js/ie8-responsive-file-warning.js"></script><![endif]-->
    <script src="../../assets/js/ie-emulation-modes-warning.js"></script>

    <!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
  </head>

  <body onload='sh_highlightDocument();'>

    <div class="navbar navbar-inverse navbar-fixed-top" role="navigation">
      <div class="container-fluid">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="sr-only">Toggle navigation</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="/">Tclers Wiki</a>
        </div>
        <div class="navbar-collapse collapse">
          <ul class="nav navbar-nav navbar-right">
            <li><a href="/whoami">Who am I?</a></li>
            <li><a href="/login">Login</a></li>
            <li><a href="/logout">Logout</a></li>
            <li><a href="/session">Session</a></li>
            <li><a href="/help">Help</a></li>
          </ul>
          <form class="navbar-form navbar-right" method='get' action='/search' id='searchform'>
            <input name="S" type="text" class="form-control" placeholder="Search...">
          </form>
        </div>
      </div>
    </div>

    <div class="container-fluid">
      <div class="row">
        <div class="col-sm-3 col-md-2 sidebar">
          <ul class="nav nav-sidebar">
${Menu}
         </ul>
        </div>
        <div class="col-sm-9 col-sm-offset-3 col-md-10 col-md-offset-2 main">
          <h1 class="page-header">${PageTitle}</h1>
${Content}
         <hr>
         ${SubTitle}
        </div>
      </div>
    </div>

    <!-- Bootstrap core JavaScript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
    <script type='text/javascript' src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"></script>
    <script type='text/javascript' src="/scripts/bootstrap.min.js"></script>
    <script type='text/javascript' src="/scripts/docs.min.js"></script>
    <script type='text/javascript' src='/scripts/sh_main.js'></script>
    <script type='text/javascript' src='/scripts/sh_tcl.js'></script>
    <script type='text/javascript' src='/scripts/sh_c.js'></script>
    <script type='text/javascript' src='/scripts/sh_cpp.js'></script>
    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="../../assets/js/ie10-viewport-bug-workaround.js"></script>
  </body>
</html>}

################################################################################

    set query {<!DOCTYPE HTML>
<html lang='en'>
<head>
<title>Query</title>
<<include:TEMPLATE:cssjs>>
</head>
<body>
  <div class='edit'>
    <div class='header'>
      <div class='logo'><a href='http://wiki.tcl.tk' class='logo'>wiki.tcl.tk</a><img class='logo' alt='' src='/plume.png'></div>
      <div class='title'>Query</div>
      <div id='updated' class='updated'>Enter a query, then press run below</div>
    </div>
  </div>
  <div class='edittitle'>
    <form method='post' action='/query' id='edit'><input name='_charset_' type='hidden' value='' tabindex='1'>
      <textarea rows='8' cols='72' style='width:100%' name='Q' tabindex='2' id='Q' autofocus>${Q}</textarea>
      <input name='create' type='submit' value='Run the query'>
    </form>
  </div>
  <div class='queryresult'>${R}</div>
  <script type='text/javascript' src='/scripts/wiki.js'></script>
</body>
</html>}

################################################################################

    set upload {<!DOCTYPE html>
<!-- saved from url=(0040)http://getbootstrap.com/examples/signin/ -->
<html lang="en"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="">
    <meta name="author" content="">
    <link rel="icon" href="http://getbootstrap.com/favicon.ico">

    <title>Signin Template for Bootstrap</title>

    <!-- Bootstrap core CSS -->
    <link href="/css/bootstrap.min.css" rel="stylesheet">

    <!-- Custom styles for this template -->
    <link href="/css/signin.css" rel="stylesheet">

    <script src="/scripts/ie-emulation-modes-warning.js"></script>

    <!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
  <link rel="stylesheet" type="text/css" href="chrome-extension://cgndfbhngibokieehnjhbjkkhbfmhojo/css/validation.css"></head>

  <body>

    <div class="container">

      <form class="form-signin" role="form" action="/saveupload" id="uploadform">
        <h2 class="form-signin-heading">Upload from file</h2>
	<input title='Upload Content' name='C' type='file' tabindex='2'>
	<input name='N' type='hidden' value='${N}' tabindex='4'>
	<input name='O' type='hidden' value='${date} ${who}' tabindex='2'>
        <button class="btn btn-lg btn-primary btn-block" type="submit">Upload</button>
      </form>

    </div> <!-- /container -->


    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/scripts/ie10-viewport-bug-workaround.js"></script>

</body></html>}

################################################################################

    proc get {args} {
	set t ""
	foreach k $args {
	    append t [set WikiTemplates::$k]
	}
	return $t
    }
}

tdbc::sqlite3::connection create db [lindex $argv 0]

set stmnt1 [db prepare {INSERT INTO pages (id, name, date, who, type, area) VALUES (:pid, :name, :date, :who, :type, :area)}]
set stmnt2 [db prepare {INSERT INTO pages_content (id, content) VALUES (:pid, :text)}]
set stmnt3 [db prepare {UPDATE pages_content SET content = :text WHERE id = :pid}]
set stmnt4 [db prepare {INSERT INTO pages_content_fts (id, name, content) VALUES (:pid, :name, :text)}]
set stmnt5 [db prepare {UPDATE pages_content_fts SET content = :text WHERE id = :pid}]
set stmnt6 [db prepare {SELECT COUNT(*) FROM pages WHERE name = :name}]
set stmnt7 [db prepare {SELECT id FROM pages WHERE name = :name}]
set stmnt8 [db prepare {SELECT COUNT(*) FROM pages}]

foreach n {conflict content cssjs edit preview error login sessionlogin updateuser deleteuser insertuser new rename notloggedin page query upload uploadconflict readonly editarea noaccess} {
    set name TEMPLATE:$n
    set date [clock seconds]
    set who "init"
    set type ""
    set text [WikiTemplates::get $n]
    set area "admin"

    set rs [$stmnt6 execute]
    $rs nextdict d
    $rs close

    if {[dict get $d "COUNT(*)"]} {
	set rs [$stmnt7 execute]
	$rs nextdict d
	$rs close
	set pid [dict get $d id]
	$stmnt3 allrows
	$stmnt5 allrows
    } else {
	set rs [$stmnt8 execute]
	$rs nextdict d
	$rs close
	set pid [dict get $d "COUNT(*)"]
	puts "$name pid=$pid"
	$stmnt1 allrows
	$stmnt2 allrows
	$stmnt4 allrows
    }
    incr pid
}

db close
