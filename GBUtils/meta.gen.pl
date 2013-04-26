#!/usr/bin/perl -w

#
# Try to load config files and using db handles - retrieve the names of the features for each label (stanza)
#

use strict;
use lib '/home/pruzanov/gbtest/lib/perl5';
use Bio::Graphics::Browser2;
use Data::Dumper;

my $username = 'nobody';

my $USAGE = "meta.gen.pl [conf_file] [metadata file]";
my $conf_file = shift @ARGV;
my $meta_file = shift @ARGV;
my %meta;
my %dbs; # store db handles here
my $globals = Bio::Graphics::Browser2->open_globals;
my $source  = Bio::Graphics::Browser2::DataSource->new($conf_file,"My Config","Currently processed config file",$globals);
my %idmaps; # Map subtrack names to modencode ids, record here using track stanza labels as keys
my %info;  # Final results, to be used in metadata file
my $metapath = "/browser_data/ORG/wiggle_binaries/PI";

&get_metadata($meta_file);

# Get labels from config file iusing GBrowse code
my @labels = grep {!/_scale/} grep {!/\:\d/} $source->configured_types;
if (!@labels || @labels == 0) {die "Apparently there are no configured tracks here";}

LABEL:
foreach my $label (@labels) {
 %idmaps = (); # We need this only once for processing a single label
 my @subtracks = $source->label2type($label);
 if (@subtracks == 1) {
  print STDERR "[$label] has no subtracks\n";
  next LABEL;
 } elsif (!@subtracks || @subtracks == 0) { # Just in case
  print STDERR "[$label] has some problems, no seq features found\n";
  next LABEL;
 }

 # get data source ids
 # Get select or subtrack table values
 my $dbid = $source->code_setting($labels[0]=>'database');
 my $DB = $dbid=~m/_/ ? $` : $dbid;
 $metapath=~s/PI$/$DB/ if $metapath!~/$DB/;
 my $selects = $source->code_setting($label=>'select') || $source->code_setting($label=>'subtrack table');
 my $dsrc    = $source->code_setting($label=>'data source');


 # Use [select or subtrack table] values to map labels to modencode ids
 # if fails, file with metadata will be using modencode ids in [] instead of subtrack name
 # READ DATA FROM DATABASE
 $selects ? &map_ids($selects) : &map_ids($dsrc);

 $dbs{$dbid} = Bio::DB::SeqFeature::Store->new( -adaptor => 'DBI::mysql',
                                                 -dsn     => 'dbi:mysql:'.$dbid,
                                                 -user    => 'nobody') if !$dbs{$dbid};

 my $db = $dbs{$dbid};
 my @fnames_db = ();

 foreach my $s (@subtracks) {
  my @features = $db->get_features_by_type($s);

  # Do a little validation here, make sure we have just one name for all features here
  my $fname;
  map {if(!$fname){$fname = $_->name}elsif($fname ne $_->name){print STDERR "Feature $s has multiple names in the database\n";}} @features;
  push @fnames_db,$fname;

 }

  # Make sure we have it written correctly in 'select' option
  foreach my $id (keys %idmaps) {
   next if !$idmaps{$id} || $idmaps{$id} eq "1";
   my $ok = 0;
   map{if($_ eq $idmaps{$id}){$ok = 1}} (@fnames_db);
   print STDERR "$idmaps{$id} is different from what is in the database for $label\n" if !$ok;
  }

  # Register metadata for selected data sources or deny writing data if there's no enough deversity (no sense to have metadata)
  my %cat_check = ();
  foreach my $sub (keys %idmaps) {
   foreach my $cat (keys %{$meta{$sub}}) {
    $cat_check{$cat}->{$meta{$sub}->{$cat}}++;
   }
  }
  my $print_meta = 0;
  map{$print_meta = 1 if (keys %{$cat_check{$_}}) > 1} (keys %cat_check);


  # Organize info for printing out to metafiles
  if ($print_meta) {
  my $metatext;
  ID:
  foreach my $id (keys %idmaps) {
   $metatext .= $idmaps{$id} eq  "1" ? "[modENCODE_$id]" : "[$idmaps{$id}]";
   my @cattext = ();
   CAT:
   foreach my $cat(keys %cat_check) {
    if ((keys %{$cat_check{$cat}}) < 2) {next CAT;}
    push(@cattext,sprintf "%-15s %-12s",$cat,"= ".$meta{$id}->{$cat});
   }
   $metatext.="\n";
   $metatext.=join("\n",@cattext);
   $metatext.="\n\n";
  }
  $info{$label} = $metatext; 
  }
}


# Comment all select or subtrack table lines (parsed conf file)
# insert metadata = field after database (parsed conf file)
# Write metafile in special directory [out]
# Print metadata files, parse conf file
if (%info && (keys %info) > 0) {
   print STDERR "What organism (fly, worm etc) it is?\n";
   my $org = <STDIN>;
   chomp($org);
   $metapath =~ s/ORG/$org/;
  
   if (! -d "meta.out") {`mkdir "meta.out"`;}
   
   # Print out metafiles
   STANZA:
   foreach my $l (@labels) {
    if (!$info{$l}){next STANZA;}

    open(METAFILE,">meta.out/$l.txt") or die "Couldn't write to [meta.out/$l.txt]";
    print METAFILE $info{$l};
    close METAFILE;
   }

   # Comment out select and subtrack lines, insert metadata line
   my $new_name = $conf_file;
   $new_name =~s/\.conf/_parsed\.conf/; 
   $new_name =~s!.*/!!;

   open(IN,"<$conf_file") or die "";
   open(OUT,">$new_name") or die "";

   my $current;
   my $select_in = 0;   

   while(<IN>) {
    if (/^\S/) {$select_in = 0;}
    if (!/\:/ && /^\[(.+)\]/) {
     $current = $info{$1} ? $1 : undef;
     print STDERR "Found label [$1], current set to $current\n";
    }


    # Commenting
    if ((/^select/ || /^subtrack/) && $current) {
     print OUT '#'.$_;
     $select_in = 1;
     next;
    }
     
    
    print OUT $select_in ? '#'.$_ : $_;
    # Inserting
    if ($current && /^database/) {
     print OUT "metadata";
     print OUT "     = ".join("/",($metapath,$current.'.txt'));
     print OUT "\n";
    }
   }
   close IN;
   close OUT;
}

# ==============subroutines===================:
# Map ids using select option
sub map_ids {
 my $raw_string = shift;
 chomp($raw_string);

 my @values;

 if ($raw_string =~ /\d+\;/) {
  @values = split("\; ",$raw_string); 
  foreach (@values) {
   if (/^(\S+)\s*.*=\s*(\d+)\;*$/) {
    $idmaps{$2} = $1;
   }
  } 
 } elsif ($raw_string =~ /(\d+ )+/) {
  @values = split(" ",$raw_string);
  map{$idmaps{$_} = 1} (@values);
 }


}

# Get metadata
sub get_metadata {
 my $metafile = shift;
 open(META,"<$metafile") or die "Couldn't read from metafile [$metafile]";
 my $firstline = <META>;
 $firstline =~ s/\"//g;
 chomp($firstline);
 my @headings = split("\t",$firstline);

 while(<META>) {
  chomp;
  s/\"//g;
  my @temp = split("\t");
  $temp[0] =~ /modENCODE_(\d+)/i ? $temp[0] = $1 : next;
  
  foreach my $i (1..$#temp) {
   if ($temp[$i] =~ /Not Applicable/i || $temp[$i] !~/\S/) {
    $meta{$temp[0]}->{$headings[$i]} = "NA";
   } else {
    $meta{$temp[0]}->{$headings[$i]} = $temp[$i];
   }
  }
 }
 close META;
}


=head1 NAME

 meta.gen.pl

=head1 SYNOPSIS

 ./meta.gen.pl [.conf file] [metadata.file]

 where .conf file - file with GBrowse stanza config
       metadata.file - file with tab-delimited info obtained from modMINE query builder

 Query (not necessarily stays this wat, may be updated):
 <query name="" model="genomic" view="
 Submission.DCCid 
 Submission.antibodies.name 
 Submission.antibodies.targetName 
 Submission.cellLines.name 
 Submission.cellLines.tissue 
 Submission.developmentalStages.name 
 Submission.strains.name 
 Submission.developmentalStages.sex" sortOrder="Submission.DCCid asc">
  <join path="Submission.antibodies" style="OUTER"/>
  <join path="Submission.cellLines" style="OUTER"/>
  <join path="Submission.developmentalStages" style="OUTER"/>
  <join path="Submission.strains" style="OUTER"/>
 </query>

 will do two things: 
  1. Comment out all 'select' and 'subtrack table' lines in conf file
  2. will create metadata files (if there's enough diversity) and put a metadata link into stanza

=head1 See Also

 Bio::Graphics::DB::SeqFeature Bio::Graphics::Browser2::DataSource Bio::Graphics::Browser2

=head1 AUTHOR
 
 Peter Ruzanov OICR (2012) pruzanov@oicr.on.ca

=cut
