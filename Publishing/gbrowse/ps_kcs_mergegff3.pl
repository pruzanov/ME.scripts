#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp;

sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }

# Used by sort to sort gff entries by chromosome then by range start, in
# ascending order.
sub gff_sort {
    my ($chromosome_a, $a1, $chromosome_b, $b1) = ($a->[0], $a->[1], $b->[0], $b->[1]);
    if ($chromosome_a lt $chromosome_b) { return -1; }
    elsif ($chromosome_a gt $chromosome_b) { return 1; }
    else {
        if ($a1 < $b1) { return -1; }
        elsif ($a1 > $b1) { return 1; }
        else { return 0; }
    }
}

if ($#ARGV < 1) {
    print STDERR "This script requires at least two gff3 files!\n";
    die "SYNTAX: $0 <gff_1> <gff_2> ... <gff_n>\n";
}

my @gff_files = @ARGV;
my @gff_in;

# We go through each entry in each gff file and store the range, peak value
# and chromosome they belong to in a list.
foreach my $gff_file (@gff_files) {
    foreach my $line (read_file($gff_file, chomp => 1)) {
        if ($line !~ m/^#/ and $line !~ m/^$/) {
            my @line = split /\t/, $line;
            my ($chromosome, $range_start, $range_end, $peak_value) = ($line[0], $line[3], $line[4], $line[5]);
            push @gff_in, [$chromosome, $range_start, $range_end, $peak_value];
        }
    }
}

# Sort all input gff entries by chromosome first then by range start.
@gff_in = sort gff_sort @gff_in;

$|++; # Turn on autoflush, we're gonna need it from now on.

# Now we go through the list, comparing every range with every other range in
# the same chromosome. We store any overlapping regions in another large list.
my @gff_out;
foreach my $i (0 .. $#gff_in) {
    print "\rCalculating overlap regions: $i/$#gff_in peaks";
    # We will consider this range to be A = (a1, a2).
    my ($chromosome_a, $a1, $a2, $peak_value_a) = @{$gff_in[$i]};
    foreach my $j ($i .. $#gff_in) {
        # And this range will be B = (b1, b2). 
        next if $i == $j; # Only compare different ranges.
        my ($chromosome_b, $b1, $b2, $peak_value_b) = @{$gff_in[$j]};
        next if ($chromosome_a ne $chromosome_b); # No overlap, different chromosomes.
        next if ($a1 > $b2); # A comes after B, no overlap.
        next if ($b1 > $a2); # B comes after A, no overlap.
        push @gff_out, [$chromosome_a, max($a1, $b1), min($a2, $b2), $peak_value_a];
    }
}
print "\n";

@gff_out = sort gff_sort @gff_out;

my @merged_gff_lines;
foreach my $i (0 .. $#gff_out) {
    print "\rWriting merged ranges: $i/$#gff_out peaks";
    my ($chromosome, $range_start, $range_end, $peak_value) = @{$gff_out[$i]};
    my $line = "$chromosome\t" . "Regions_of_sig_enrichment\t" ."binding_site\t"
    . "$range_start\t" . "$range_end\t" . "$peak_value\t"
             . "\.\t\.\t"
             . "ID=enriched_regions_" . sprintf("%d", $i+1) . "\n";
    push @merged_gff_lines, $line;
}
print "\n";

$|--; # We're done with autoflush.

write_file("merged.gff3", @merged_gff_lines);
