#!/usr/bin/perl -w

#
# A simple script for composing load wiggle gff file
# given a list of directories with wiggle files and bw files
#
use strict;
use constant DEBUG => 0;

#Things that change
my $USAGE = "./dir2load_gff.pl [DIR IDS, space- or dash-separated] [ORGANISM, optional]\n"; 
my $fasta = {fly =>"/browser_data/fly/fasta/dmel-all-chromosome-r5.8.fasta",
             dana=>"/browser_data/dana/fasta/dana-all-chromosome-r1.3.fasta",
             dmoj=>"/browser_data/dmoj/fasta/dmoj-all-chromosome-r1.3.fasta",
             dpse=>"/browser_data/dpse/fasta/dpse-all-chromosome-r2.4.fasta",
             dsim=>"/browser_data/dsim/fasta/dsim-all-chromosome-r1.3.fasta",
             dvir=>"/browser_data/dvir/fasta/dvir-all-chromosome-r1.2.fasta",
             dyak=>"/browser_data/dyak/fasta/dyak-all-chromosome-r1.3.fasta",
             worm=>"/browser_data/worm/fasta/c_elegans.WS220.genomic.fa",
             cbrenneri=>"/browser_data/cbrenneri/fasta/c_brenneri.WS227.genomic.fa",
             cbriggsae=>"/browser_data/cbriggsae/fasta/c_briggsae.WS225.genomic.fa",
             cjaponica=>"/browser_data/cjaponica/fasta/c_japonica.WS227.genomic.fa",
             cremanei=>"/browser_data/cremanei/fasta/c_remanei.WS225.genomic.fa"};
           

my $wigpath = "/browser_data/ORG/wiggle_binaries/PI/";
my $method  = "binding_site";
my $org;
my $id_file;
my $id_mask = "_sub2_sig_peak"; # THE PRESENCE OF THIS FILE IS MANDATORY, the rest should be configured automatically
my $size_file = 'chrom.sizes'; # Must be present (linked to) in the current directory

#===================AUTOMATIC CONFIGURATION============================//
my @confchecks = `ls \*$id_mask`;
my $pwd = `pwd`;
chomp($pwd);
@confchecks > 0 or die "A file with submission->track id mappings should be present in the [$pwd] and its name should look like *$id_mask"; 
if ($confchecks[0]=~/(\w+)$id_mask/) {
  my $pi = $1;
  $id_file = $pi.$id_mask;
  $wigpath =~ s/PI/$pi/;
} else {
  die "Could not find a proper file submission->track id mappings although a file [$confchecks[0]] is present";
}

if (! -e $size_file) {
  die "Could not find chrom.sizes file, make sure it is present on the file system and is linked to from the current dir. Also make sure it is for the right organism!\nit may be created with this one liner:\ncat your_species.fa \| perl -ne \'{chomp;if(/^>(\\S+)/){\$current = \$1;next;}else{if(\$current && /^(\\S+)/){\$chroms{\$current}+=length(\$1);}}} END {map{print join(\"\\t\",(\$_,\$chroms{\$_})),\"\\n\"}(keys \%chroms)}\'\n";
}



#====================SCRIPT BEGINS=====================================//
my @args = @ARGV;
my(@dirs,%dirs,%ids,%chroms);

foreach (@args) {
 next if (!/^\d+/);
 if (/(\d+)\-(\d+)/) {
  map {push @dirs,$_} ($1..$2);
 } else {push @dirs,$_;}
}
if(@dirs == 0){die $USAGE;}
print STDERR "Got ".scalar(@dirs)." directories\n" if DEBUG;

#==================CHECK FOR ORGANISM==================================//
if ($args[$#args] !~/\d/ && $fasta->{$args[$#args]}) {
 $wigpath=~s/ORG/$args[$#args]/;
 $org = $args[$#args];
} else {
  print STDERR "Error [$args[$#args]], we need a recognizable organism alias passed as the last argument to this script, The avaliable Organisms:\n";
  map {print $_."\n"} (keys %$fasta);
  exit;
}

# Load track/peak ids from the suppplied filea
print STDERR "Reading from $id_file...\n" if DEBUG;
open(INFO,"<$id_file") or die "Cannot read from [$id_file]";
while (<INFO>) {
 chomp;
 my @temp = split("\t");
 if ($ids{$temp[0]}) {print STDERR "Duplicate entry for submission $temp[0], need manual checking\n";}
 
 $ids{$temp[0]} ||= {signal=>$temp[1],peak=>$temp[2]};

}
my %notfound = ();
map {$notfound{$_} = 1 if !$ids{$_}} @dirs;
if (scalar(keys %notfound) > 0) {
 print STDERR "File [$id_file] does not have data for:\n";
 print STDERR join("\n",(sort {$a<=>$b} keys %notfound)),"\n\n"; 
}
close INFO;

# Read chrom sizes (in case we don't have wiggle files we'll just use chrom sizes for feature's coordinates
open(SIZE,"<$size_file") or die "Couldn't read from size file [$size_file]";
   while(<SIZE>) {
    chomp;
    my @temp = split("\t");
    next if $temp[0] =~ /^dmel/; # Bybass drosophila's mitochondrial annotation, we need 'M'
    $chroms{$temp[0]} = $temp[1];
   }
close SIZE;
print STDERR "Got ".scalar(keys %chroms)." chromosomes with sizes\n" if DEBUG;


# Calculate coordinates for each feature and collect the list of bw files

foreach my $dir (@dirs) {
 print STDERR "Processing $dir ...\n";
 $dirs{$dir} = {bw=>[],coords=>{},name=>"No_name"};
 opendir(DIR,$dir) or warn "Cannot read from directory [$dir]" and next;
 my @wigs = grep {/wiggle.gff$/} readdir (DIR);
 rewinddir DIR;
 my @chroms;

 if (@wigs == 0) {
  if (my $id = $ids{$dir}->{peaks} || $ids{$dir}->{signal}){&fixgff($id."_details",$dir);}
  map{$dirs{$dir}->{coords}->{$_} = [1,$chroms{$_}]} (keys %chroms);
 } else {
  WIG:
  foreach my $wig (@wigs) { 
   open(WIG,"<$dir/$wig") or die "Couldn't read from [$dir/$wig]";
   LINE:
   while (<WIG>) {
   if (/^$/ || /^\#/){next LINE;}
   if (/^(\S+)\t\S+\t\S+\t(\d+)\t(\d+)\t/) {$dirs{$dir}->{coords}->{$1} = [$2,$3];}

   }
   close WIG;
   if(scalar(keys %{$dirs{$dir}->{coords}}) > 0) {last WIG;}
  }
  
  if (scalar(keys %{$dirs{$dir}->{coords}}) == 0) {
   print STDERR "Will use chromosomal sizes for coordinates\n";
   map{$dirs{$dir}->{coords}->{$_} = [1,$chroms{$_}]} (keys %chroms);
   }
   #print STDERR "For $dir got $chr START: $start END: $end\n" if DEBUG;
 }
 
 $dirs{$dir}->{bw} = [sort grep {/.*bw$/} readdir(DIR)]; 
 if (scalar (@{$dirs{$dir}->{bw}}) > 1 && scalar (@{$dirs{$dir}->{bw}}) != 2) {
  my @filtered = grep {/plus|minus/} @{$dirs{$dir}->{bw}};
  if (@filtered == 0) {@filtered = grep {/t\.bw|u\.bw/} @{$dirs{$dir}->{bw}};}
  if (@filtered == 2) {$dirs{$dir}->{bw} = \@filtered;} else {print STDERR "Could not automatically find proper BigWig files!\n";}
 }

 print STDERR "Got ".scalar(@{$dirs{$dir}->{bw}})." BigWig files for submission $dir\n";

 rewinddir(DIR);
 my($idf_file) = grep {/idf/i} readdir(DIR);
 $idf_file =~s!(\()!\\$1!g;
 $idf_file =~s!(\))!\\$1!g;
 $idf_file =~s!(\s)!\\$1!g;
 if ($idf_file) {
  my $name = `grep \"Investigation Title\" $dir/$idf_file | awk -F \"\t\" '{print \$2}' | sed 's/\"//g' | sed 's/ //g'`;
  chomp($name);
  print STDERR "Extracted name [$name] from $idf_file\n" if DEBUG;
  $dirs{$dir}->{name} = $name if $name =~ /\w+/;
 }
 closedir(DIR);
}

# Compose a load wiggle file


print "\#\#gff-version 3\n\n";
foreach my $d (sort {$a<=>$b} keys %dirs) {
 next if ! $ids{$d}->{signal} || scalar(@{$dirs{$d}->{bw}}) == 0;
 print STDERR "Got signal, getting peaks...\n";
 my $peak_id = $ids{$d}->{peak} ? $method.":".$ids{$d}->{peak}."_details" : "\"\"";
 if ($peak_id !~/\:(\d+_details)/){&fixgff($1,$d);}
 my $wigstring = scalar(@{$dirs{$d}->{bw}}) > 1 ?  "Name=$dirs{$d}->{name}\;peak_type=$peak_id;wigfileA=$wigpath$dirs{$d}->{bw}->[0];wigfileB=$wigpath$dirs{$d}->{bw}->[1];fasta=$fasta->{$org}"
                                                :  "Name=$dirs{$d}->{name}\;peak_type=$peak_id;wigfile=$wigpath$dirs{$d}->{bw}->[0];fasta=$fasta->{$org}";
 print STDERR "Printing ".scalar(keys %{$dirs{$d}->{coords}})." lines for submission $d\n";
 if ($wigstring =~ /wigfileA/) {
  my $method = $wigstring=~/plus/ ? "WIG" : "rnaseq_wiggle";
  map{print join("\t",($_,$ids{$d}->{signal},$method,$dirs{$d}{coords}{$_}->[0],$dirs{$d}{coords}{$_}->[1],".",".",".",$wigstring)),"\n";} (keys %{$dirs{$d}->{coords}}); 
 } else {
  map{print join("\t",($_,$ids{$d}->{signal},"VISTA",$dirs{$d}{coords}{$_}->[0],$dirs{$d}{coords}{$_}->[1],".",".",".",$wigstring)),"\n";} (keys %{$dirs{$d}->{coords}});
 }
 print "\n";
}

# Fixing gff file (change field 2 to n_details
sub fixgff {
 my($id,$dir) = @_;
 opendir(FIXDIR,$dir) or die "Cannot read from [$dir]";
 my @gffs = grep {/\.gff/} grep {!/wiggle/} readdir FIXDIR;
 closedir FIXDIR;
 my $index  = 0;
 my $count  = 1;
 my $choice = 0;

 if (@gffs != 1) {
  map {my $gff_id = $gffs[$_];$gff_id =~s/\.gff.*//;if($ids{$dir}->{peak} == $gff_id){$choice = $_+1}} (0..$#gffs);
   
  @gffs == 0 && !$choice ? return undef : print STDERR "Multiple GFF files!";
  map {print STDERR $count++." $_\n"} @gffs;
  while (!$choice || !$gffs[$choice-1]) {
   print STDERR "Which one to fix?\n";
   $choice = <STDIN>;
  }
 } else {
  print STDERR "Fixing $dir/$gffs[0]\n";
 }
 
 open(GFF,"<$dir/$gffs[$choice-1]") or die "Cannot read from [$dir/$gffs[$choice-1]]";
 open(TEMP,">$dir/tempgff_$$") or die "Cannot write to [$dir/tempgff_$$]";
 while(<GFF>) {
  if (/^\#/){print TEMP;next;}
  my @temp = split("\t");
  if ($temp[1] && $temp[1] =~/^\d+_details$/) {
     close TEMP;
     close GFF;
     return; # No fixing required
  }
  $temp[1] = $id if $temp[1];
  print TEMP join("\t",@temp); 
 }
 close GFF;
 close TEMP;

 `mv $dir/tempgff_$$ $dir/$gffs[$choice-1]`;
}


=head2 SYNOPSIS

Simple script that makes loading (scaffold) gff file for a set of directories
Tries to 'intelligently' guess the type of experiment from the content
of a directory. Depends on submission->track tab-delimited mapping file:

SUB_id	SIGNAL_TRACK_id	PEAK_TRACK_id, i.e:

566	6789	6790   (Not modENCODE real data)

Useful for processing data configured for using with vista_plot

=head2 USAGE

dir2load_gff.pl dir1 dir2 dir3-dirX organism

=cut
