#!/usr/bin/perl -w
#
# Script for composing gffs for Lai's project - sorts by chromosome and coordinates, extracts matches only
#

use strict;
use IO::File;

# Some hard-coded parameters
my $method = "match";


my $file = shift @ARGV;
my @chroms = `awk '{print \$1}' $file | grep -v Sequence | grep -v ^# | sort -u`;
my $header = `grep gff-version $file`;

print $header;

foreach my $chr(@chroms){
 chomp($chr);
 next if $chr=~/^$/;
 print STDERR "Proceed with Chromosome $chr (y/n)?\n";
 my $answer = "no";
 QUE:
 while($answer = <STDIN>){
  unless($answer=~/y/i || $answer=~/n/i){print STDERR "Come again?\n";
                                         next QUE;}
  last QUE;
 }
 next unless $answer =~/y/i;

 print `awk '{if(\$1==\"$chr\"){print \$0}}' $file | sort -nk 4`;
}


