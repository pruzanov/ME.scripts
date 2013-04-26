/* This functions are to be used with Data Clinic interface*/

function getElementsByTagAndClassName(tag,cname) {
 var tags=document.getElementsByTagName(tag);
 var cEls=new Array();
 for (i=0; i<tags.length; i++) {
  var rE = new RegExp("(^|\\s)" + cname + "(\\s|$)");
   if (rE.test(tags[i].className)) {
   cEls.push(tags[i]);
   }
  }
 return cEls;
}

function toggleMenu(subid,type,icondir,link) {
 var menuid = "VetMenu." + subid;
 var layer = document.getElementById(menuid);
 var img   = document.getElementById('connector.' + subid);
 var clink = document.getElementById('checklink.' + subid);
  if(layer.style.visibility == "hidden"){
  layer.style.visibility = "visible";
  img.src = icondir + type + "_conn.gif";
  clink.href = link;
  layer.class = type;
 }else{
  layer.style.visibility = "hidden";
  img.src = icondir + "empty_conn.gif";
  layer.class = 'empty';
 }
}

function open_popup (elem,id,mark) {
 var menu =  window.parent.document.getElementById(elem);
 var type = menu.class;
 if (mark == 'BAD') {
  window.open('clinic.cgi?form=markbad&id='+id+'&type='+type,'Mark as '+mark,'width=380,height=180,top=200,location=0,left=300');
 } else {
  window.open('clinic.cgi?form=markok&id='+id+'&type='+type,'Mark as '+mark,'width=380,height=90,top=200,location=0,left=300');
 }
}

function open_report (id) {
 window.open('clinic.cgi?report='+id,'Report','width=380,height=180,top=200,location=0,left=300');
}

function icon_swap (id,newsrc) {
 var img = window.opener.document.getElementById(id);
 img.src = newsrc;
 self.close();
}

function toggle_display(element_id){
 var item = document.getElementById(element_id);
 if (item) {
  item.className=(item.className=='hidden')?'unhidden':'hidden';
 }
}
