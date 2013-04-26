#!/usr/bin/perl -w

#
# A simple script for composing load wiggle gff file
# given a list of directories with wiggle files and bw files
#
use strict;

#Things that change

#my $fasta   = "/browser_data/dpse/fasta/dpse-all-chromosome-r2.6.fasta";
my $fasta   = "/browser_data/fly/fasta/dmel-all-chromosome-r5.8.fasta";
#my $fasta   = "/browser_data/worm/fasta/c_elegans.WS220.genomic.fa";
my $wigpath = "/browser_data/fly/wiggle_binaries/celniker/";
my $method  = "binding_site";
my $id_file = "celniker_sub2_sig_peak"; #macalpine_sub2sig";
my $size_file = '/home/pruzanov/Data/FlyData/chrom.sizes';
#'/home/pruzanov/Data/D.pseudoobscura/d.pseudoobscura_chroms.txt';#'/home/pruzanov/Data/FlyData/chrom.sizes';


#====================SCRIPT BEGINS=====================================//
my @args = @ARGV;
my(@dirs,%dirs,%ids,%chroms);

foreach (@args) {
 next if (!/^\d+/);
 if (/(\d+)\-(\d+)/) {
  map {push @dirs,$_} ($1..$2);
 } else {push @dirs,$_;}
}

# Load track/peak ids from the suppplied file
open(INFO,"<$id_file") or die "Cannot read from [$id_file]";
while (<INFO>) {
 chomp;
 my @temp = split("\t");
 if ($ids{$temp[0]}) {print STDERR "Duplicate entry for submission $temp[0], need manual checking\n";}
 
 $ids{$temp[0]} ||= {signal=>$temp[1],peak=>$temp[2]};

}
close INFO;

# Read chrom sizes (in case we don't have wiggle files we'll just use chrom sizes for feature's coordinates
open(SIZE,"<$size_file") or die "Couldn't read from size file [$size_file]";
   while(<SIZE>) {
    chomp;
    my @temp = split("\t");
    next if $temp[0] =~ /^dmel/;
    $chroms{$temp[0]} = $temp[1];
   }
close SIZE;
print STDERR "Got ".scalar(keys %chroms)." chromosomes with sizes\n";


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
   #print STDERR "For $dir got $chr START: $start END: $end\n";
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
 my $wigstring = scalar(@{$dirs{$d}->{bw}}) > 1 ?  "Name=$dirs{$d}->{name}\;peak_type=$peak_id;wigfileA=$wigpath$dirs{$d}->{bw}->[0];wigfileB=$wigpath$dirs{$d}->{bw}->[1];fasta=$fasta"
                                                :  "Name=$dirs{$d}->{name}\;peak_type=$peak_id;wigfile=$wigpath$dirs{$d}->{bw}->[0];fasta=$fasta";
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

Simple script that makes loading gff file for a set of directories
Tries to 'intelligently' guess the type of experiment from the content
of a directory.


=head2 USAGE

dir2load_gff.pl dir1 dir2 dir3-dirX

=cut
