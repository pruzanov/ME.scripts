#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp;

# Used by sort to sort gff entries by range start.
sub gff_sort {
    my ($a1, $b1) = ($a->[0], $b->[0]);
    if ($a1 < $b1) { return -1; }
    elsif ($a1 > $b1) { return 1; }
    else { return 0; }
}

if ($#ARGV != 0) {
    print STDERR "This script currently accepts only one gff file!\n";
    die "SYNTAX: $0 <gff>\n";
}

my @gff_files = @ARGV;
my %gff_in;

# We go through each entry in each gff file and store the range and chromosome
# it belongs to in a list. Each chromosome has its own list.
foreach my $gff_file (@gff_files) {
    foreach my $line (read_file($gff_file, chomp => 1)) {
        if ($line !~ m/^#/ and $line !~ m/^$/) {
            my @line = split /\t/, $line;
            my ($chromosome, $range_start, $range_end) = ($line[0], $line[3], $line[4]);
            if (!exists $gff_in{$chromosome}) { $gff_in{$chromosome} = []; }
            push @{$gff_in{$chromosome}}, [$range_start, $range_end];
        }
    }
}

my $overlaps = 0;

foreach my $chromosome (keys %gff_in) {
    my $ranges_ref = $gff_in{$chromosome};
    @$ranges_ref = sort gff_sort @$ranges_ref;
    foreach my $i (0 .. (scalar @$ranges_ref - 1)) {
        my ($a1, $a2) = @{$ranges_ref->[$i]};
        foreach my $j ($i+1 .. (scalar @$ranges_ref - 1)) {
            my ($b1, $b2) = @{$ranges_ref->[$j]};
            last if ($b1 > $a2);
            if (not (($b1 >= $a2) or ($a1 >= $b2))) {
                print "($a1, $a2) overlaps with ($b1, $b2) in chromosome $chromosome!\n";
                $overlaps++
            }
        }
    }
}

print "Found $overlaps overlaps.\n";
