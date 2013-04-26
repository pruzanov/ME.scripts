#!/usr/bin/perl -w
#
# Script for merging 2 gff_wiggle files into one (for Eric Lai's data specifically, to be used with hybrid_plot.pm glyph
#

use strict;
use IO::File;

my $file = shift @ARGV;

my $fh = new IO::File("<$file") or die "Can't read from [$file]\n";
my %lines;
my $head_printed = 0;

while(<$fh>){
 if(/^#/ || /^$/){if(/^#/ && !$head_printed){print;$head_printed = 1;}next;}
 chomp;

 my @temp = split("\t");
 unless($lines{$temp[0]}->{$temp[1]}){
  s/Name=/ID=$temp[1]_$temp[0]\;Name=/;
  if (/wigfile\=.+?$temp[1]t.+?\.wi/ || /wigfile\=.+?$temp[1]u.+?\.wi/) {
   /wigfile\=.+?$temp[1]t.+?\.wi/ ? s/wigfile/wigfileA/ : s/wigfile/wigfileB/;
  }else {s/wigfile/wigfileA/;}
  $lines{$temp[0]}->{$temp[1]} = $_;
  next;
 }

 my $append = /wigfile/ ? "wigfile".$' : die "No wigfile found for second part in $temp[0]\n";
 if ($append=~/wigfile\=.+?$temp[1]t.+?\.wi/ || $append=~/wigfile\=.+?$temp[1]u.+?\.wi/) {
   /wigfile\=.+?$temp[1]t.+?\.wi/ ? s/wigfile/wigfileA/ : s/wigfile/wigfileB/;
 }else {$append=~s/wigfile/wigfileB/;}
 #$append=~/wigfile\=.+?$temp[1]t.+?\.wig/ ? $append=~s/wigfile/wigfileA/ : $append=~s/wigfile/wigfileB/;

 print join(";",($lines{$temp[0]}->{$temp[1]},$append));
 print "\n";
}

$fh->close;

