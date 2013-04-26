#!/usr/bin/perl -w

use strict;
use warnings;
use Carp qw(croak cluck);
use CGI qw(:standard escape start_table end_table);

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
 my $gblink  = &get_gb_link($id,$data->{ids}->{$id}->{lab},$data->{ids}->{$id}->{org});
 my $sub = TR(td({-width=>100},$id),
              td({-width=>300},&get_description($id)),
              td((a{-href=>"#",
                    -onClick=>"toggleMenu($id,'f','$icondir','http://submit.modencode.org/submit/public/download/$id?root=tracks')",
	            -width=>300},
                   img({src=>&get_image('tracks',$data->{status}->{$id}->{'tracks'}),width=>20,height=>20,border=>0,alt=>'Tracks',id=>'f_icon'.$id})),
                  a({-href=>"#",-onClick=>"toggleMenu($id,'c','$icondir','http://submit.modencode.org/submit/public/citation/$id')"},
                   img({src=>&get_image('citation',$data->{status}->{$id}->{'citation'}),width=>20,height=>20,border=>0,alt=>'Citation',id=>'c_icon'.$id})),
		  a({-href=>"#",-onClick=>"toggleMenu($id,'g','$icondir','$gblink')"},
                   img({src=>&get_image('gbrowse',$data->{status}->{$id}->{'gbrowse'}),width=>20,height=>20,border=>0,alt=>'GBrowse',id=>'g_icon'.$id})),
                  a({-href=>"#",-onClick=>"toggleMenu($id,'m','$icondir','http://intermine.modencode.org/query/portal.do?externalid=modENCODE_$id&class=Submission')"},
                   img({src=>&get_image('modmine',$data->{status}->{$id}->{'modmine'}),width=>20,height=>20,border=>0,alt=>'modMINE',id=>'m_icon'.$id})),
                  a({-href=>"#"},
                   img({src=>&get_image('machine',$data->{status}->{$id}->{'machine'}),width=>20,height=>20,border=>0,alt=>'Machine',id=>'pc_icon'})),
                 &vetting_div("VetMenu",$id),
                 img({src=>&connector_image('empty'),
                      width=>140,
                      height=>5,
                      border=>0,
                      alt=>'Connector',
                      name=>"connector.".$id,
                      id=>"connector.".$id,
                      align=>'left'})
                 
                ),
                td({-width=>150},
                    button({-id=>'report'.$id,
                            -name=>'Report',
                            -onCLick=>"open_report($id)"})
                            )
                );
 return $sub."\n";
}

# GBrowse link formatting:

sub get_gb_link {
 my($sub_id,$lab,$org) = @_;
 if (!$data->{ids}->{$sub_id}->{stanza}){$lab = undef;} # No link if there's no stanza (Block GBrowse link if a submission isn't posted yet)
 return $lab ? "http://modencode.oicr.on.ca/fgb2/gbrowse/$org/?start=123000;stop=180000;ref=2L;l=$lab" : "#";
}

# A drop down menu for updating submission's status

sub vetting_div {
 my($name,$id) = @_;
 my $div_id = join(".",($name,$id));
 return div({-id=>$div_id,
             -style=>"position:relative;top:-24px;left:130px;width:190px;height:0px;z-index:auto;background-color:#F9C36E;visibility:hidden"},
             qq(<radio_group name='vet_group'>
              <input type="radio" name="vet_group" id="okradio"  value="OK" onClick  = "open_popup('$div_id',$id,'OK')">OK
              <input type="radio" name="vet_group" id="badradio" value="BAD" onClick = "open_popup('$div_id',$id,'BAD')">BAD
             </radio_group>),
             "&nbsp;",
             a({-href=>"http://submit.modencode.org/submit/public/download/$id?root=tracks",
                -id=>"checklink.".$id},
                "Check the link").br)."\n";
}

# Get an image for a test according to the test's status

sub get_image {
 my($type,$stat) = @_;
 $stat ||=0;
 return ($type) ? $icondir.$images{$type}->[$stat] : $icondir.$images{'error'}->[0];
}

# Get the right connector image

sub connector_image {
 my $type = shift @_;
 return $con_images{$type} ? join("/",($icondir,$con_images{$type})) : join("/",($icondir,$con_images{'empty'}));
}

# Format html code for table entries with submissions for a given PI

sub format_subs () {
 my $pi = shift;
 my @list;
 map{push(@list,&add_submission($_))} (sort {$a<=>$b} @{$data->subs($pi)});
 return @list;
}

## Main code:

if (my $form = param('form')) {
 my $id = param('id') ;
 my $type = param('type');
 $form eq 'markbad' ? &render_ReportForm($id,$type) : &render_OkForm($id,$type);
 exit;
} elsif (my $update = param('update')) {
 my $id = param('id');
 my $type = param('type');
 my $report = param('report');
 my $icon_id = join('_icon',($type,$id));
 my $newsrc = $update eq 'bad' ? $icondir.$images{$db_fields{$type}}->[2] : $icondir.$images{$db_fields{$type}}->[1];
 print header,
       start_html;
 print br,br if ($report);
 print h3("Update Submitted"),
       br,
       button({-name=>'Close',
               -onClick=>"icon_swap('$icon_id','$newsrc')"}),
       q(<script src="../../html/clinic/js/toggle.js" type="text/javascript"></script>), 
       end_html;

 $update eq 'bad'&& $report ? &update_field($id,$type,$report) : &update_field($id,$type,'OK');
 exit;
} elsif (my $report = param('report')) {
 my $text = DbLoader::get_reports($report);
 print header,
       start_html,
       h3("Report Page for submission $report"),
       br,
       $text,
       end_html; 
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
<h1>Data clinic Prototype #1</h1>
<div align="center"><a href = "../../html/clinic/clinic_help.html" >Help</a></div>
<a href="https://wikimediafoundation.org/wiki/Support_Wikipedia/en"><img border="0" alt="Support Wikipedia" src="//upload.wikimedia.org/wikipedia/commons/4/40/Fundraising_2009-micro-thanks-en.png" /></a>
<div align ="right">
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
              table({-width=>'90%',-border=>0},
                    TR(th({-scope=>"col"},["Submission id","GBrowse Label","Submission Checkpoints","Submission Report"])),
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


# Updating fields
sub update_field {
 my($sub_id,$field,$record) = @_;
 my $dbstring = join(':','DBI:mysql',$database,$host,'3306');

 my $dbh = DBI->connect($dbstring,$user,$password,{RaiseError=>1, AutoCommit=>1});
 my $sth;

 # The $record is OK, just erase the report and mark sub as ok
 if ($record =~/^OK$/i) {
  $sth = "UPDATE Submissions SET $db_fields{$field} = 'OK' WHERE id = $sub_id";
  $sth = $dbh->prepare($sth);

  $sth->execute or warn "Failed to update $db_fields{$field} for submission $sub_id";

  $sth->finish;
  $dbh->disconnect;
  #exit;
 } else {
 # The $record is an actual report, first check if there's a report already and if there is, append the text
  $sth = "SELECT $db_fields{$field} FROM Submissions WHERE id = $sub_id";
  #warn "Query string is $sth";
  $sth = $dbh->prepare($sth);
  $sth->execute or warn "Couldn't retrieve the records for $db_fields{$field}, submission $sub_id";
   ROW:
   while (my @row = $sth->fetchrow) {
    #print STDERR "Loading tag $row[0]\n";
    if ($row[0] ne 'NULL') {
     $sth = $row[0] eq 'OK' ? "UPDATE Submissions SET $db_fields{$field} = '$record' WHERE id = $sub_id" : "UPDATE Submissions SET $db_fields{$field} = 'join(';',($row[0],$record))' WHERE id = $sub_id";
   } elsif (!$row[0] || $row[0] eq 'NULL') {
     $sth = "UPDATE Submissions SET $db_fields{$field} = '$record' WHERE id = $sub_id";
   }
    last ROW;
   }
   #warn "Query string is $sth";
   $sth = $dbh->prepare($sth);
   $sth->execute or warn "Couldn't update the record for $db_fields{$field}, submission $sub_id";

   $sth->finish;

   $dbh->disconnect;
 }
}
