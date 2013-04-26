#!/usr/bin/perl -w

use strict;
use warnings;
use Carp qw(croak cluck);
use CGI qw(:standard escape start_table end_table);
use XML::Simple;
use lib '/u/pruzanov/public_html/cgi-bin/clinic/';
use DbLoader;

my $database = "data_clinic";
my $host     = "localhost";
my $user     = "modencode";
my $password = "modencode+++";

my %db_fields     = (f=>"tracks",c=>"citation",g=>"gbrowse",m=>"modmine",pc=>"machine");
#=========================================THIS SHOULD GO TO SOME SETTING-READING MODULE=================
my $icondir = "../../html/clinic/icons/";
my %images = (tracks  => ["f_NA_icon.jpg","f_OK_icon.jpg","f_BAD_icon.jpg"],
              gbrowse => ["g_NA_icon.jpg","g_OK_icon.jpg","g_BAD_icon.jpg"],
              citation=> ["c_NA_icon.jpg","c_OK_icon.jpg","c_BAD_icon.jpg"],
              modmine => ["m_NA_icon.jpg","m_OK_icon.jpg","m_BAD_icon.jpg"],
              machine => ["pc_NA_icon.jpg","pc_OK_icon.jpg","pc_BAD_icon.jpg"],
              status  => ["generic_NA_icon.jpg","generic_pcOK_icon.jpg","generic_OK_icon.jpg","generic_pcBAD_icon.jpg","generic_BAD_icon.jpg"],
              error   => ["icon_template.jpg"]);
my %con_images = ('tracks'=>"f_conn.gif",'citation'=>"c_conn.gif",'gbrowse'=>"g_conn.gif",'mine'=>"m_conn.gif",'machine'=>"pc_conn.gif",'empty'=>"empty_conn.gif");

#=======================================================================================================

my $data;

sub render_legend {
 my $ims = "";
 map {if ($_ ne'error'){$ims.= img({src=>"$icondir$images{$_}->[0]",
                                    width=>15,
                                    height=>15,
                                    alt=>"icon_$_"},)." => $_&nbsp;"}} (sort keys %images);
 
 print table({-width=>450,
              -height=>20},
              TR(td({-valign=>'top'},
                    $ims)
                ));

}

sub get_description {
 my $id = shift @_;
 return ($data->{ids}->{$id}->{desc} && $data->{ids}->{$id}->{desc} ne 'NA') ? $data->{ids}->{$id}->{desc} : "Not posted to GBrowse yet";
}


sub add_submission {
 my $id = shift @_;
 if ($id !~/^\d+$/){return;}
 my $img_dir = "";
 my $sub = TR(td({-width=>100},$id),
              td({-width=>300},&get_description($id)),
              td(
		 #a{-href=>"#",
                  #  -onClick=>"toggleMenu($id,'f','$icondir','http://submit.modencode.org/submit/public/download/$id?root=tracks')",
	          #  -width=>300},
                  # img({src=>&get_image('tracks',$data->{status}->{$id}->{'tracks'}),width=>20,height=>20,border=>0,alt=>'Tracks',id=>'f_icon'.$id})),
                 # a({-href=>"#",-onClick=>"toggleMenu($id,'c','$icondir','http://submit.modencode.org/submit/public/citation/$id')"},
                 #  img({src=>&get_image('citation',$data->{status}->{$id}->{'citation'}),width=>20,height=>20,border=>0,alt=>'Citation',id=>'c_icon'.$id})),
		 # a({-href=>"#",-onClick=>"toggleMenu($id,'g','$icondir','$gblink')"},
                 #  img({src=>&get_image('gbrowse',$data->{status}->{$id}->{'gbrowse'}),width=>20,height=>20,border=>0,alt=>'GBrowse',id=>'g_icon'.$id})),
                 # a({-href=>"#",-onClick=>"toggleMenu($id,'m','$icondir','http://intermine.modencode.org/query/portal.do?externalid=modENCODE_$id&class=Submission')"},
                 #  img({src=>&get_image('modmine',$data->{status}->{$id}->{'modmine'}),width=>20,height=>20,border=>0,alt=>'modMINE',id=>'m_icon'.$id})),
                  a({-name=>"subICON_".$id,-onClick=>"dc_update_id($id)"},
                   img({src=>$icondir.$images{'status'}->[0],width=>20,height=>20,border=>0,alt=>'Status Icon',id=>"modENCODE_".$id}))
		 )
                 #&vetting_div("VetMenu",$id)
                 #img({src=>&connector_image('empty'),
                 #     width=>140,
                 #     height=>5,
                 #     border=>0,
                 #     alt=>'Connector',
                 #     name=>"connector.".$id,
                 #     id=>"connector.".$id,
                 #     align=>'left'})
                 
                #)
                #td({-width=>150},
                #    button({-id=>'report'.$id,
                #            -name=>'Report',
                #            -onCLick=>"open_report($id)"})
                #            )
                );
 return $sub."\n";
}

# GBrowse link formatting:

#sub get_gb_link {
# my($sub_id,$lab,$org) = @_;
# if (!$data->{ids}->{$sub_id}->{stanza}){$lab = undef;} # No link if there's no stanza (Block GBrowse link if a submission isn't posted yet)
# return $lab ? "http://modencode.oicr.on.ca/fgb2/gbrowse/$org/?start=123000;stop=180000;ref=2L;l=$lab" : "#";
#}

# A drop down menu for updating submission's status

#sub vetting_div {
# my($name,$id) = @_;
# my $div_id = join(".",($name,$id));
# return div({-id=>$div_id,
#             -style=>"position:relative;top:-24px;left:130px;width:190px;height:0px;z-index:auto;background-color:#F9C36E;visibility:hidden"},
#             qq(<radio_group name='vet_group'>
#              <input type="radio" name="vet_group" id="okradio"  value="OK" onClick  = "open_popup('$div_id',$id,'OK')">OK
#              <input type="radio" name="vet_group" id="badradio" value="BAD" onClick = "open_popup('$div_id',$id,'BAD')">BAD
#             </radio_group>),
#             "&nbsp;",
#             a({-href=>"http://submit.modencode.org/submit/public/download/$id?root=tracks",
#                -id=>"checklink.".$id},
#                "Check the link").br)."\n";
#}

# Get an image for a test according to the test's status

#sub get_image {
# my($type,$stat) = @_;
# $stat ||=0;
# return ($type) ? $icondir.$images{$type}->[$stat] : $icondir.$images{'error'}->[0];
#}

# Get the right connector image

#sub connector_image {
# my $type = shift @_;
# return $con_images{$type} ? join("/",($icondir,$con_images{$type})) : join("/",($icondir,$con_images{'empty'}));
#}

# Format html code for table entries with submissions for a given PI

sub format_subs () {
 my $pi = shift;
 my @list;
 map{push(@list,&add_submission($_,$pi))} (sort {$a<=>$b} @{$data->subs($pi)});
 return @list;
}

## Main code:

if (my $q = param('query')) {
 my $id = param('id');
 my $type = param('type');
 my $report = param('report');
 $data = new DbLoader();
 print "Content-Type: text/plain", "\n\n";
 if (!$id) {
  print XMLout($data->query($q),RootName => 'nodes',  AttrIndent => 1);
 } else {
  warn "Submitting query with $q,$id,$type,$report";
  $data->query($q,$id,$type,$report);
 }
 exit;
}

# Got no parameters (usually, initial load) :

$data = new DbLoader();
$data->get_data;
print header;
print start_html(-title=>'modENCODE Data clinic',
                 -head=>[Link({-href=>"../../html/clinic/css/bluedream.css",
                              -type=>"text/css",
                              -rel =>"stylesheet"}),
                         Link({-href=>"../../html/clinic/css/status.css",
                               -type=>"text/css",
                               -rel =>"stylesheet"}),
                         Link({-href=>"../../html/clinic/css/tabbed.css",
                 	       -type=>"text/css",
                 	       -rel =>"stylesheet"})]);

print << 'END';
<h1>Data clinic Prototype #2</h1>
<div align="center"><a href = "../../html/clinic/clinic_help.html" >Help</a></div>
<a href="https://wikimediafoundation.org/wiki/Support_Wikipedia/en"><img border="0" alt="Support Wikipedia" src="//upload.wikimedia.org/wikipedia/commons/4/40/Fundraising_2009-micro-thanks-en.png" /></a>
<div align ="right">
</div>
<div id="dataclinic" align="left" style="position:fixed;top:250px;right:-510px;width:540px;height:200px;display:block;">
  <div id="flashContent" style="z-index:0;">
  <p>
  To view this page ensure that Adobe Flash Player version 
  1.0.0 or greater is installed. 
  </p>
  <script type="text/javascript"> 
   var pageHost = ((document.location.protocol == "https:") ? "https://" :	"http://"); 
   document.write("<a href='http://www.adobe.com/go/getflashplayer'><img src='" + pageHost + "www.adobe.com/images/shared/download_buttons/get_flash_player.gif' alt='Get Adobe Flash player' /></a>" ); 
  </script>
  <script type="text/javascript">
   function dc_update_id(new_id) { 
   var swf = "FlexPopup";
   if (navigator.appName.indexOf("Microsoft") >= 0) {
    document.swfobject.getObjectById(swf).updateSubId(new_id);
    }
   else {
    window.swfobject.getObjectById(swf).updateSubId(new_id);
    }  			
   }
   function toggle_display(element_id) {
    var item = document.getElementById(element_id);
    if (item) {
     item.style.display=(item.style.display=='none')?'block':'none';
    }
   }
  function toggle_dwidth(min_offset,max_offset) {
   var div = document.getElementById("dataclinic");
   if(div) {
    div.style.right=(div.style.right!=max_offset)?max_offset:min_offset;
   }	
  } 
  function toggle_staticon(icon_id,status) {
   if(document.images) {
   switch(status) {
   case 0:
   document.images[icon_id].src = "../../html/clinic/icons/generic_NA_icon.jpg";
   break;
   case 1:
   document.images[icon_id].src = "../../html/clinic/icons/generic_pcOK_icon.jpg";
   break;
   case 2:
   document.images[icon_id].src = "../../html/clinic/icons/generic_OK_icon.jpg";
   break;
   case 3:
   document.images[icon_id].src = "../../html/clinic/icons/generic_pcBAD_icon.jpg";
   break;
   case 4:
   document.images[icon_id].src = "../../html/clinic/icons/generic_BAD_icon.jpg";
   break;
   default:
   break;
   }
   }
  }
 </script>
 <noscript>
   <object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" width="100%" height="10%" id="FlexPopup">
     <param name="movie" value="../../html/clinic/swf/flexpopup.swf" />
     <param name="quality" value="high" />
     <param name="bgcolor" value="white" />
     <param name="allowScriptAccess" value="sameDomain" />
     <param name="allowFullScreen" value="true" />
     <param name="wmode" value="transparent" />
     <!--[if !IE]>-->
       <object type="application/x-shockwave-flash" data="../../html/clinic/swf/flexpopup.swf" width="100%" height="100%">
       <param name="quality" value="high" />
       <param name="bgcolor" value="white" />
       <param name="allowScriptAccess" value="sameDomain" />
       <param name="allowFullScreen" value="true" />
       <param name="wmode" value="transparent" />
     <!--<![endif]-->
     <!--[if gte IE 6]>-->
       <p> 
        Either scripts and active content are not permitted to run or Adobe Flash Player version
        1.0.0 or greater is not installed.
       </p>
     <!--<![endif]-->
       <a href="http://www.adobe.com/go/getflashplayer">
         <img src="http://www.adobe.com/images/shared/download_buttons/get_flash_player.gif" alt="Get Adobe Flash Player" />
       </a>
     <!--[if !IE]>-->
     </object>
     <!--<![endif]-->
     </object>
     </noscript>	
   </div>
</div>
<br/>
END
&render_legend;

my $html;
my $tablist;
my $divlist;

# Organize tabs (list should be loaded from an external source)
foreach my $pi (sort @{$data->groups}) {
    my $capname = ucfirst $pi;
    
    $tablist.=li(a({-href=>"#$pi",
                    -class=>"tab_inactive",
                    -title=>"$capname"},
                    span($capname)))."\n";
}

$html.=div({-id=>"tabs10"},
            ul($tablist));

# Populate pages with submissions
my $first_pi = 0;
foreach my $pi (sort @{$data->groups}) {

$divlist.=div({-id=>"$pi",
               -class=>$first_pi++ ? "inactive" : "active"},
              '&nbsp;',
              table({-width=>'80%',-border=>0},
                    TR(th({-scope=>"col"},["Submission id","GBrowse Label","Submission Status"])),
                    &format_subs($pi)
                   )
             )."\n";
}

$html.=$divlist;
print $html;

my @active_subs;
map{push @active_subs, "\'$_\'"} (sort @{$data->groups});

print << 'END';
<br/><br/>
<script src="../../html/clinic/js/activatables.js" type="text/javascript"></script>
<script src="../../html/clinic/js/toggle.js" type="text/javascript"></script>
<script src="../../html/clinic/js/swfobject.js" type="text/javascript"></script>
<script type="text/javascript">
  <!-- For version detection, set to min. required Flash Player version, or 0 (or 0.0.0), for no version detection. --> 
  var swfVersionStr = "1.0.0";
  <!-- To use express install, set to playerProductInstall.swf, otherwise the empty string. -->
  var xiSwfUrlStr = "";
  var flashvars = {};
  var params = {};
  params.quality = "high";
  params.bgcolor = "white";
  params.allowscriptaccess = "sameDomain";
  params.allowfullscreen = "true";
  params.wmode = "transparent";
  var attributes = {};
  attributes.id = "FlexPopup";
  attributes.name = "FlexPopup";
  attributes.align = "middle";
  swfobject.embedSWF(
    "../../html/clinic/swf/flexpopup.swf", "flashContent", 
    "540", "200", 
    swfVersionStr, xiSwfUrlStr, 
    flashvars, params, attributes);
  <!-- JavaScript enabled so display the flashContent div in case it is not replaced with a swf object. -->
  swfobject.createCSS("#flashContent", "display:block;text-align:left;");
</script>
END
print "<script type=\"text/javascript\">activatables('page', [".join(",",@active_subs)."])</script>\n";
print end_html;

# Sub for making a form for report update
sub render_ReportForm {
 my($id,$type) = @_;
 my $icon_id = join('_icon',($type,$id));
 my $newsrc = $icondir.$images{$data->{db_fields}->{$type}}->[2];
 print header,
       start_html("Update Report (Problematic submission)");
 print start_form,
       "Edit Report for $db_fields{$type}, Submission $id:",br
       textarea(-name=>'report',
                -default=>'',
                -rows=>4,
                -columns=>50),
       hidden('id',$id),
       hidden('type',$type),
       hidden('update','bad'),
       br,
       submit(-name=>'Update Report'),
       reset(-name=>'Cancel',
             -onClick=>"self.close()"),
       end_form,
       end_html;
}

# Sub for making a dialog for marking sub as ok
sub render_OkForm {
 my($id,$type) = @_;
 my $icon_id = join('_icon',($type,$id));
 my $newsrc = $icondir.$images{$db_fields{$type}}->[1];
 print header,
       start_html("Mark as OK"),
       start_form,
       "Confirm sub ".b($id)." $db_fields{$type} data are OK?",
       hidden(id=>$id),
       hidden(type=>$type),
       hidden(update=>'ok'),
       br,
       br,
       submit(-name=>'Mark as OK'),
       reset(-name=>'Cancel',
             -onClick=>"self.close()"),
       end_form,
       end_html;
}



