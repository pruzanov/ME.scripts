#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use List::Util qw(max min);

=pod

=head1 NAME

removeoverlaps.pl - Intersect overlapping intervals within a sorted, SINGLE GFF3 file.

=head1 SYNOPSIS

removeoverlaps.pl < [GFF3]

=head1 DESCRIPTION

Takes in a sorted (ascending by col 4) GFF3 as input, outputs a GFF3 with all overlapping intervals
intersected.

Motivation: overlapping peaks found within individual biological replicates 
for Snyder GFP ChIP experiments. This could not be solved using the traditional "bedtools intersect"
approach because there are already overlaps within one file.

=cut

# We use the following data structure throughout:

# A "MY_STRUCT" is:
#
# {
# 	"CHR1" => [
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 						. . . . . . . . . . . .
# 					]
# 	"CHR2" => [
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 						. . . . . . . . . . . .
# 					]
# . . . . . . . . . . . . . . . . . . . . . . .
# }

# Where the BOOL_MERGED flag denotes whether or not the feature
# overlapped another in the original GFF3.

# proc_stdin -> MY_STRUCT
# Build our data structure from the GFF3 passed through STDIN and return it.
sub proc_stdin {
    my $features = {};
    while(<>) {
        next if m/^$/ or m/^#/;
        my @cols = split('\t');
        $features->{$cols[0]} = [] unless exists $features->{$cols[0]};
        push $features->{$cols[0]}, [$cols[3], $cols[4], $cols[5], 0];
        #print STDERR Dumper(%{$features});
    }
    return $features;
}

# fix_gff3 MY_STRUCT TRACKID -> (void)
# Take our data structure, a track ID, and print a fixed GFF3 to STDOUT.
# No return value.
sub fix_gff3 {
    print STDOUT "##gff-version 3\n";
    my ($features,$trackid) = @_;
    foreach my $chrom (keys %{$features}) {
        for (my $i = 0; $i <= $#{$features->{$chrom}}; $i++) {

            my @overlaps;
            my $hasOverlap = 0;
            push @overlaps, [$features->{$chrom}->[$i]->[0],$features->{$chrom}->[$i]->[1],$features->{$chrom}->[$i]->[2]];

            print STDERR "Checking [$features->{$chrom}->[$i]->[0],$features->{$chrom}->[$i]->[1]] on $chrom:\n";

            # Ugh, quadratic time.
            for (my $j = $i+1; $j <= $#{$features->{$chrom}}; $j++) {

                print STDERR "\t ... against [$features->{$chrom}->[$j]->[0],$features->{$chrom}->[$j]->[1]] on $chrom\n";

                # If the second feature begins after the first one ends, there
                # is no overlap. Since feature start coordinates are sorted in
                # ascending order, all subsequent features will also start after
                # the first one ended.

                # Additionally, if we have already intersected the feature with another, we don't
                # care about it any more.

                if ($features->{$chrom}->[$j]->[0] > $features->{$chrom}->[$i]->[1] or $features->{$chrom}->[$j]->[3]) {
                    # AL CODA
                    last;
                } else {
                    # Keep track of which intervals overlap the "interval in question" (i.e. the one at the index in the outer loop).
                    $hasOverlap = 1;
                    push @overlaps, [$features->{$chrom}->[$j]->[0],$features->{$chrom}->[$j]->[1],$features->{$chrom}->[$j]->[2]];
                    $features->{$chrom}->[$i]->[3] = 1;
                    $features->{$chrom}->[$j]->[3] = 1;
                    print STDERR "\t[$features->{$chrom}->[$i]->[0],$features->{$chrom}->[$i]->[1]] OVERLAPS WITH [$features->{$chrom}->[$j]->[0],$features->{$chrom}->[$j]->[1]]\n";
                }
            }
            ########
            # CODA #
            ########
            if ($hasOverlap) {
                # Pick the largest start coord and the smallest end coord.
                my $new_start = max(map { $_->[0] } @overlaps);
                my $new_end = min(map { $_->[1] } @overlaps);

                # Pick the largest score.
                my $new_score = max(map { $_->[2] } @overlaps);

                printf STDOUT "%s\t%d_details\tbinding_site\t%d\t%d\t%.20f\t.\t.\t.\n", $chrom, $trackid, $new_start, $new_end, $new_score;
                print STDERR "\tCREATING NEW INTERVAL [$new_start,$new_end]\n";
            } else {
                printf STDOUT "%s\t%d_details\tbinding_site\t%d\t%d\t%.20f\t.\t.\t.\n", $chrom, $trackid, $features->{$chrom}->[$i]->[0], $features->{$chrom}->[$i]->[1], $features->{$chrom}->[$i]->[2] unless $features->{$chrom}->[$i]->[3];
                #print "\t ... NO OVERLAP, ORIGINAL: [$features->{$chrom}->[$i]->[0],$features->{$chrom}->[$i]->[1]]\n" unless $features->{$chrom}->[$i]->[3];
            }
        }
    }
}

$|++;
fix_gff3(proc_stdin(),31337);
$|--;
