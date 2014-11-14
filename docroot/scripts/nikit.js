
function hideDiscussions()
{
    aryClassElements.length = 0;
    getElementsByClassName('discussion', document.body);
    for (var i = 0; i < aryClassElements.length; i++) {
        aryClassElements[i].style.display = 'none';
    }
}

function toggleDiscussion(n)
{
    try {
	if (document.getElementById('discussion'+n).style.display =='inline') {
	    document.getElementById('discussion'+n).style.display = 'none';
	    document.getElementById('togglediscussionbutton'+n).innerHTML = 'Show' + document.getElementById('togglediscussionbutton'+n).innerHTML.substring(4);
	}
	else {
	    document.getElementById('discussion'+n).style.display = 'inline';
	    document.getElementById('togglediscussionbutton'+n).innerHTML = 'Hide' +  document.getElementById('togglediscussionbutton'+n).innerHTML.substring(4);
	}
    } catch (e) {}
	return false;
}

/***********************************************
 * Dynamic Ajax Content- © Dynamic Drive DHTML code library (www.dynamicdrive.com)
 * This notice MUST stay intact for legal use
 * Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code
 * Based on functions taken from Dynamic Ajax Content:
 *    ajaxpage
 *    loadpage
 ***********************************************/

function ajaxpage(url, postData, containerid){
    ajaxpage(url, postData, containerid, 0);
}

function ajaxpage(url, postData, containerid){
    var page_request = false
    if (window.XMLHttpRequest) // if Mozilla, Safari etc
        page_request = new XMLHttpRequest()
    else if (window.ActiveXObject){ // if IE
	try {
	    page_request = new ActiveXObject("Msxml2.XMLHTTP")
	}
	catch (e){
	    try{
		page_request = new ActiveXObject("Microsoft.XMLHTTP")
	    }
	    catch (e){}
	}
    }
    else
        return false

    page_request.onreadystatechange=function(){
	    loadpage(page_request, containerid)
    }
    if (postData.length) {
	page_request.open('POST', url, true);
	page_request.setRequestHeader('Content-type', "text/xml");
	page_request.setRequestHeader('Content-length', postData.length);
	page_request.send(postData);
    }
    else {
	page_request.open('GET', url, true);
	page_request.send(null);
    }
}

function loadpage(page_request, containerid) {
    if (page_request.readyState == 4 && (page_request.status==200 || window.location.href.indexOf("http")==-1)) {
	if (page_request.responseText.length) {
	    document.getElementById(containerid).innerHTML = page_request.responseText;
	}
    }
}

function getBackRefs(page,containerid)
{
    ajaxpage("/ref", "N=" + page + "&A=1", containerid)
}
