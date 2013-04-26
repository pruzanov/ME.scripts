#!/usr/bin/perl -w

use strict;
use DbLoader;
use Data::Dumper;
use constant DEBUG=>1;

my $pipe_host = "modencode-www1.oicr.on.ca";
my $gb_host   = "modencode.oicr.on.ca"; 
my $gbsite    = "http://modencode.oicr.on.ca/gb2/gbrowse/";
my $GBconf    = "/var/www/conf/GBrowse.conf";
my $nih_dir   = "/modencode/raw/tools/reporter/output/output_nih*";
my $ssh_key   = "/home/jrajasegaram/.ssh/id_rsa";
my %labs      = (white=>1, 
                 celniker=>1, 
                 lieb=>1, 
                 karpen=>1, 
                 waterston=>1, 
                 piano=>1, 
                 lai=>1, 
                 snyder=>1, 
                 macalpine=>1, 
                 henikoff=>1, 
                 oliver=>1);

# Collect all supported updates
#
# NIH table report
# Pipeline status (tracks)
# GBrowse configs (published submissions)
#
my %reports = (); # A hash with ;-delimited reports from various checks. Will go to 'machine' field in Submissions table for data clinic if there are reports.
my %posted  = (); # just to hold all sub ids on GBrowse
my %ok_subs = (); # Register ok submissions, they should not go into report
my %orgs    = ();
# get all orgs from Gbrowse.conf
# use http://modencode.oicr.on.ca/gb2/gbrowse/$org/?action=scan and grep data source (will get us list of all published submissions)
# ================GBrowse config:
# Check the total of posted submissions, in a future - correct mapping os sub ids to track ids
# presence of the features referred in stanza code
my @orgs =  `ssh -i $ssh_key $gb_host grep -B 1 description $GBconf`;
my $current_org = "fly";
foreach my $org(@orgs) {
 next if $org=~/^$/;
 chomp($org);

 if ($org=~/^\[/) {
  $org=~s/[\[,\]]//g;
  $current_org = $org;
  print STDERR "Found organism: [$org]\n" if DEBUG;
 }

 next if ($org!~/ DB$/ && $org!~/ Genomic Browser$/);
 $org = $`;

 if ($org=~/\.(\S+?)$/ || $org=~/ (\S+?)$/) {
  print STDERR "Registering organism: [$current_org] as $1\n" if DEBUG;
  $orgs{$current_org} = $1;
 } else {
  next;
 }

 `wget -O temp_scan_$$ \"$gbsite.$org?action=scan\"`;
 open SCAN, "cat temp_scan_$$ |" or die "Couldn't fork ";
 my($current_stanza,$current_key);
 while (<SCAN>) {
  chomp;
  # Extract stanza tag
  if (/^\[(.*)\]/) {
   $current_stanza = $1;
  }
  # Extract description
  if (/^key\s+= /) {
   $current_key = $';
  }
  # Sub ids 
  if (/^data source/) {
   s/.*= //;
   my @subs = split(" ");
   map{$posted{$_}++} @subs;
   map{$reports{$_}->{stanza} = $current_stanza;$reports{$_}->{desc} = $current_key;} @subs;
  }
 }
 close SCAN;
 `rm temp_scan_$$`;
}

# =================NIH table report:
# submissions state (relesed, deprecated etc) extract sub id, group name, status
my $nih_latest = `ssh -i $ssh_key $pipe_host ls -t $nih_dir | head -1`;
chomp($nih_latest);
print STDERR "Latest nih spreadsheet: [$nih_latest]\n" if DEBUG;

if ($nih_latest=~/txt$/) {
 `scp -i $ssh_key $pipe_host\:$nih_latest nih_latest`;
 &process_nih_table("nih_latest");
}


# ================Pipeline Status check:
# We will check if there are any files in ###/tracks directory 
# - only the released submissions from step one which are not published 
# (according to the info collected at step two)
sub check_tracks {
 my $sub = shift @_;
 my @compare = ();
 my @lines = `ssh -i $ssh_key $pipe_host ls -t /modencode/raw/data/$sub/tracks/ 2> /dev/null`;
 if (!@lines || scalar(@lines) == 0) {
   my @files = `ssh -i $ssh_key $pipe_host ls -lt /modencode/raw/data/$sub/extracted/ 2> /dev/null`;
   if(!@files || scalar(@files)== 0) {
     $reports{$sub}->{report} = $reports{$sub}->{report}=~/\S/ ? $reports{$sub}->{report}."; no tracks" : "no tracks";
     return 0;
   }
   foreach my $file(@files){
    if($file !~m/^l/ && ($file=~m/gff/i || $file=~m/\.bam/i || $file=~m/\.bw/i || $file=~m/\.wig/i || $file =~m/pair/i || $file =~m/\.sam/i || $file=~m/fastq/ ||$file =~m/\.fq\./ || $file =~m/^d/)){
     chomp($file); 
     push (@compare,$file);
    }
   }
   if(scalar(@compare)== 1 && $compare[0] =~m/^d/){
    if(!`ssh -i $ssh_key $pipe_host ls -lt /modencode/raw/data/$sub/extracted/*/* 2> /dev/null`){
     $reports{$sub}->{report} = $reports{$sub}->{report}=~/\S/ ? $reports{$sub}->{report}."; metadata only" : "metadata only";
     return 0;
    }
   } 
   if(scalar(@compare) == 0 || !@compare){
    $reports{$sub}->{report} = $reports{$sub}->{report}=~/\S/ ? $reports{$sub}->{report}."; metadata only" : "metadata only";
    return 0;
   }
   else {
    $reports{$sub}->{report} = $reports{$sub}->{report}=~/\S/ ? $reports{$sub}->{report}."; no tracks" : "no tracks";
    return 0;
   }
  }
  else {
  $ok_subs{$sub}++;
  return 1;
 }
}

# Check if we have submissions posted on GBrowse but no information available in the current nih spreadsheet
foreach my $posted (keys %posted) {
 if (!$reports{$posted} && !$ok_subs{$posted}){$reports{$posted} = "submission is in GBrowse but not in nih spreadsheet (metadata?)";}
}


print Dumper(%reports) if DEBUG;
# Ok subs and submissions with reports (plus posted subs) will need to be retained, all the others should go from the database
my %keep_these = ();
map{$keep_these{$_}++} (keys %ok_subs);
map{$keep_these{$_}++} (keys %reports);

# Now, having collected all information bits we may update the database fields here:
my $dbl = new DbLoader();
my %existing = %{$dbl->get_ids()};

foreach my $sub (keys %reports)  {
 if ($reports{$sub}->{report}=~/^$/) {
  print STDERR "Report set to OK\n" if DEBUG;
  $reports{$sub}->{report} = "OK";
 }
 print STDERR Dumper($reports{$sub}) if DEBUG;
 if (%existing && $existing{$sub}) {
  print STDERR "Updating $sub...\n" if DEBUG;
  $dbl->update_field($sub,"pc",$reports{$sub}) unless DEBUG;
 } else {
  print STDERR "Inserting $sub...\n" if DEBUG;
  $dbl->insert_new($sub,"pc",$reports{$sub}) unless DEBUG;
 }
}

my %delete_these = map{if($keep_these{$_}){$_=>1}} (keys %existing);

# Update the database
#$dbl->cleanup([keys %delete_these]);

# Subroutine for processing nih_spreadsheet
# At this point, only checking status and GEO ids
sub process_nih_table {
 my $file = shift @_;
 if (! -e $file) {
     warn "There is no such file, [$file] cannot proceed with nih table check!";
     return;
 }          

 # Find out which fields are Status, Submission ID and GEO/SRA IDs
 my $header = `head -n 1 $file`;
 my @fields = split("\t",$header);
 my %nih_checks = (checks => ["Submission","Status","GEO/SRA","Project","Organism"],
                   ordered => [0,0,0,0,0]); # ordered will hold array indexes of id, status and geo fields
 
 for (my $f=0; $f<@fields; $f++) {
  map{if ($fields[$f] =~ /^$nih_checks{checks}->[$_]/){$nih_checks{ordered}->[$_] = $f}} (0..4);
 }


  print STDERR "Processing NIH spreadsheet...\n" if DEBUG;
  open(NIH,"<$file") or die "Couldn't read from NIH table [$file]";
  while(<NIH>) {
   chomp; 
   my @temp = split("\t");
   my $sub_id = $temp[$nih_checks{ordered}->[0]] =~/(\d+)\D/ ? $1 : $temp[$nih_checks{ordered}->[0]];
   #if (@temp != @fields) {print STDERR "Fields are missing or extra fields\n" if DEBUG;}
   next if $sub_id!~/^\d+$/;
   #print join("\t",($sub_id,$temp[$nih_checks{ordered}->[1]],$temp[$nih_checks{ordered}->[2]])),"\n" if DEBUG;
   my $lab = lc($temp[$nih_checks{ordered}->[3]]);
   next if !$labs{$lab};
   if (defined $reports{$sub_id}) { 
    $reports{$sub_id}->{report} = "";
    $reports{$sub_id}->{lab}    = $lab;
    $reports{$sub_id}->{org}    = 'unsupported';
   } else {$reports{$sub_id} = {report=>"",lab=>$lab,org=>'unsupported'};}
   # Clarify organism if possible
   if ($temp[$nih_checks{ordered}->[4]]=~/\,/) {
     $reports{$sub_id}->{org} = 'mixed';
   } else {
     map{ if ($temp[$nih_checks{ordered}->[4]]=~/$orgs{$_}/){$reports{$sub_id}->{org}=$_}} (keys %orgs);
   }


   # Status check
   if ($temp[$nih_checks{ordered}->[1]] ne 'released') {
    if ($temp[$nih_checks{ordered}->[1]] eq 'replaced' || $temp[$nih_checks{ordered}->[1]]=~/^super|^depr/) {
         $reports{$sub_id}->{report} = $reports{$sub_id}->{report}=~/\S/ ? $reports{$sub_id}->{report}."; is replaced" : "is replaced";
    } else {
         if (!&check_tracks($sub_id)) {
          $reports{$sub_id}->{report} = $reports{$sub_id}->{report}=~/\S/ ? $reports{$sub_id}->{report}."; Not released yet" : "Not released yet";
         }
    }

   } else {
        # Submission is released, check if it has tracks
        &check_tracks($sub_id);
   }
   
   #GEO check
   if ($temp[$nih_checks{ordered}->[2]] && $temp[$nih_checks{ordered}->[2]]=~/MISSING_GEO_ID/i) {
       if ($temp[$nih_checks{ordered}->[2]]=~/GS/) {
	    $reports{$sub_id}->{report} = $reports{$sub_id}->{report}=~/\S/ ? $reports{$sub_id}->{report}."; GEO id not entered in db" : "GEO id not entered in db"; 
      } else {
	    $reports{$sub_id}->{report} = $reports{$sub_id}->{report}=~/\S/ ? $reports{$sub_id}->{report}."; data not sent to GEO" : "data not sent to GEO"; 
      }
   }
  }
  close NIH;

}

