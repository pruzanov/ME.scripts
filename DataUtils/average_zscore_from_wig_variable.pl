#!/usr/bin/perl -w

# This script will eat WIG (variable step) files and
# excrete a new file with the average or median score
# NOTE: input files must all the same same number of lines
# and the same sequence coords!

use Statistics::Descriptive;
use strict;
use Data::Dumper;

my $thing = shift || die "Provide a concise description (use quotes i > 1 word)\n";

if ($thing && -e $thing) {
  die "$thing is a file!\nDid you put a text description as the first argument?\n";
}

my %index; # To register all lines
my @files;
my @chroms;
my %chroms;
my %chromheaders;
my $workdir;
my @infiles;

while (my $file = shift) {
  $workdir = $file =~ m!^(.*)/! ? $1 : "";
  my $in;
  open $in, $file or die $!;
  if ($file) {push @infiles, {fh=>$in,name=>$file};}
}

if (@infiles < 2) {
  die "I need at least two wig files to take an average!\n";
}

# Try to find all chromosomes first, fail if no chromosomes found
my @fnames = map {$_->{name}} (@infiles);
my @chromlines = `grep chrom @fnames | sort -u`;
if (!@chromlines && @chromlines == 0) {
 @chromlines = `grep -v track @fnames | awk '{print \$1}' | sort -u`;
 map{chomp;$chroms{$_}++} @chromlines;
} else {
 map{if (/chrom=(\S+) /){$chroms{$1}++;$chromheaders{$1} = $_;$chromheaders{$1}=~s/.*\://;}} @chromlines;
}
@chroms = (sort keys(%chroms));
print STDERR "Found ".scalar(@chroms)." chromosomes\n";

$workdir.="/$thing";
open MEDIAN, ">$workdir\_median.wig" or die $!;
open MEAN,   ">$workdir\_mean.wig" or die $!;
#my $current_chrom;
#my %sorted_c;


#my $first = $infiles[0];
#my $fh = $first->{fh};
#while (<$fh>) {
  #if (/wiggle|variable/) {
   # s/description="[^\"]+"/description="$thing median scores"/;
   # print MEDIAN $_;
   # s/median scores/mean scores/;
   # print MEAN $_;
   # $current_chrom = $1 if (/chrom\=(\S+) /);
    #foreach my $f (keys %index) {
    # map{$sorted{$_}->{$f}++} (keys %{$index{$f}->{$current_chrom}});
    #}
   # my $ifh;
   # foreach (@infiles){$ifh = $_->{fh};<$ifh>;}
   # next;
  #}
  #elsif (/^(\d+)\s+(\S+)$/) {
  #  my ($c,$s) = ($1,$2);
  #  chomp $s;
  #  my @scores = ($s);
  #  my @lines;
  #  for my $file (@infiles) {
  #    my $line = <$file>;
  #    chomp $line;
  #    my ($c1,$s1) = split /\s+/, $line;
  #    if ($c != $c1) {
#	die "We have a mismatch at line $_\nCheck your files and the instructions at the top of this script.\n";
 #     }
  #    push @scores, $s1;
  #  }
  #  my $stat = Statistics::Descriptive::Full->new;
  #  $stat->add_data(@scores);
  #  print MEAN join("\t",$c,sprintf("%.2f",$stat->mean)), "\n";
  #  print MEDIAN join("\t",$c,sprintf("%.2f",$stat->median)), "\n";
 # }

#elsif (/^(.+?)\s+(\S+)$/) { # Handle BED-wig
  #  next if /^\#/;
   # my ($c,$s) = ($1,$2);
   # if ($c =~ /\D/){if(!$current_crom || $current_chrom ne $c) {
    #                 foreach my $f (keys %index) {
#		       map{$sorted{$_}->{$f}++} (keys %{$index{$f}->{$c}});
 #   		     }		
  #                  }
   #                 $current_chrom = $c;}
    #chomp $s;
    #my @scores;
    # = ($s);
    #my @lines;
  for my $current_chrom (@chroms) {
    print STDERR "Processing $current_chrom\n";
    print MEAN $chromheaders{$current_chrom} if $chromheaders{$current_chrom};
    print MEDIAN $chromheaders{$current_chrom} if $chromheaders{$current_chrom};
    
    %index = ();
    my @fnames = map{$_->{name}} @infiles;
    map{&index_lines($_,$current_chrom)} @fnames;

       COORD:
    for my $coord (sort {$a<=>$b} keys %index) {
    my @scores = ();
    my ($ch,$c1,$c2,$s1);
    FILE:
    for my $file (@infiles) {
      #print STDERR "Checking if we have data on $current_chrom at $coord for $file->{name}\n" if $current_chrom eq '3Het'; 
#      if (!$index{$coord}->{$file->{name}}){next FILE;}
 #     my $lfh = $file->{fh};
  #    my $line;
   #   while (!$line || $line=~/^\#/){
    #    $line = <$lfh>;
     #   if(!$line){print STDERR "No line available\n";
      #             last COORD;}
       # if ($line =~ /wiggle|variable/) {
        # if ($file->{name} eq $infiles[0]->{name}) {
         #  $line =~ s/description="[^\"]+"/description="$thing median scores"/;
          # print MEDIAN $line;
           #$line =~ s/median scores/mean scores/;
           #print MEAN $line;
           #}
       #  $line = undef;
       # }
      #}

  #    chomp $line;

      #if ($line =~ /^(\S+?)\t(\S+)$/){($c1,$s1) = ($1,$2);}elsif ($line =~ /(\S+)\s(\d+)\s(\d+)\s(\S+)$/){($ch,$c1,$c2,$s1) = ($1,$2,$3,$4);}
      #unless ($c1){next COORD;}
      #if ($c1 ne $coord) {
      #  print STDERR join(" ",("Files:",keys %{$index{$current_chrom}->{$coord}}));
      #  print STDERR "\n";
      #  die "We have a mismatch at line [$line] ($c1 vs $coord for $current_chrom)\nCheck your files and the instructions at the top of this script.\n";
      #}
      push(@scores, $index{$coord}->{$file->{name}}) if $index{$coord}->{$file->{name}};
    }
  
  if (!@scores) {warn "No scores for $coord\n";
                 next COORD;}
  my $stat = Statistics::Descriptive::Full->new;
  $scores[1] ||= $scores[0]; # Impute the second value if it is absent. A work-around to handle missing values
  $stat->add_data(@scores);
  $ch ? print MEAN join("\t",$ch,$coord,$c2,sprintf("%.2f",$stat->mean)), "\n" : print MEAN join("\t",$coord,sprintf("%.2f",$stat->mean)), "\n";
  $ch ? print MEDIAN join("\t",$ch,$coord,$c2,sprintf("%.2f",$stat->median)), "\n" : print MEDIAN join("\t",$coord,sprintf("%.2f",$stat->median)), "\n";
  }
 }

#else {
 #   warn "I don't know what to do with this line: $_\n";
  #}

#}



sub index_lines {
 my($file,$chr) = @_;
 
 print STDERR "Indexing $file...\n";
 open FILE,"<$file" or die "Couldn't open [$file]";
 my $in = 0;


 while(<FILE>) {
  next if /^\#/;
  if (/chrom\=(\S+)/ && $1 eq $chr) {
    $in = 1;
  } elsif (/chrom\=(\S+)/ && $1 ne $chr) {
    $in = 0;
  }

   if ((/^(\d+)\t(\S+)$/ || /^(\d+) (\S+)$/)&& $in ) {$index{$1}->{$file} = $2;}
   #if (/^(\d+)\S(\S+)$/ && $in ) {$index{$1}->{$file} = $2;}
   #if (/^(\w+)\S(\d+)\S\d+\S(\d+)$/ || /^(\w+)\S(\d+)\S(\d+)$/) {
   if (/^(\w+)\t(\d+)\t\d+\t(\d+)$/ || /^(\w+)\t(\d+)\t(\d+)$/ || /^(\w+) (\d+) \d+ (\d+)$/ || /^(\w+) (\d+) (\d+)$/) {
    if(!$chr || $chr ne $1){
     next;
    }
  $index{$2}->{$file} = $3;
  }
 }
 close FILE;
 print STDERR "Indexed ".scalar(keys %index)." coordinates for [$file]\n";
}
