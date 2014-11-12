
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
