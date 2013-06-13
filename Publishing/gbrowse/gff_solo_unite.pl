#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

use List::Util qw(max min);
use Getopt::Long;
use Data::Dumper;

# A "MY_STRUCT" is:
#
# {
# 	"CHR1" => [
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED] # <-- Intervals
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
#											.
#											.
#											.
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
#			  ]                                                      # <-- List of Intervals
#
# 	"CHR2" => [
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
#											.
#											.
#											.
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 			  ]
#	  .
#	  .
#	  .
#
# 	"CHRN" => [
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
#											.
#											.
#											.
# 						[INT_START, INT_END, INT_SCORE, BOOL_MERGED]
# 			  ]
# }

my $verbose = '';
my $trackid = '';
GetOptions("verbose" => \$verbose,
"trackid=n" => \$trackid) or die("Usage: gff_solo_intersect.pl --trackid=ID [--verbose] [GFF3]\n");

$|++;
my $features = load_file();
my $new_features = {};

for my $chrom (keys %{$features}) {
    $new_features->{$chrom} = unite_chrom($features->{$chrom});
    foreach my $line (@{$new_features->{$chrom}}) {
        printf STDOUT "%s\t%d_details\tbinding_site\t%d\t%d\t%.20f\t.\t.\t.\n", $chrom, $trackid, $line->[0], $line->[1], $line->[2];
    }
    #print "Return value: " . Dumper(unite_chrom($features->{$chrom}));
}
$|--;

# load_file -> MY_STRUCT
# Build our data structure from the GFF3 passed through STDIN/ARGV and return it.
sub load_file {
    my $features = {};
    while(<>) {
        next if m/^$/ or m/^#/;
        my @cols = split('\t');
        $features->{$cols[0]} = [] unless exists $features->{$cols[0]};
        push $features->{$cols[0]}, [$cols[3], $cols[4], $cols[5], 0];
    }
    return $features;
}


# unite_chrom LISTOFINTERVALS -> LISTOFINTERVALS
# Takes a list of intervals within a single chromosome and unites
# overlapping features.

# Internal usage only:
# unite_chrom LISTOFINTERVALS ACCUMULATOR INTERVAL -> LISTOFINTERVALS
# 	where ACCUMULATOR is a list of intervals.
sub unite_chrom {

    # Really, deep recursion limit of 100?
    no warnings 'recursion';

    my $features = shift;

    # Overload this sub for ease of use.
    return unite_chrom($features, [], shift @{$features}) unless scalar(@_);

    # Keep a list of "chains" of overlapping features.
    my $acc = shift;

    my $featA = shift;

    # We've reached the last feature on this chromosome.
    print STDERR "Empty case\n" unless scalar(@{$features}) or not $verbose;
    #print STDERR Dumper($features);
    unless (scalar(@{$features})) {
        push @{$acc}, $featA;

        my $new_start = min(map { $_->[0] } @{$acc});
        my $new_end = max(map { $_->[1] } @{$acc});
        my $new_score = max(map { $_->[2] } @{$acc});
        return [[$new_start, $new_end, $new_score]];
    }

    my $featB = shift @{$features};


    # If we've found an overlap, push the first feature onto the
    # accumulator and recurse with the second feature to find the entire
    # "chain" of overlaps.
    if ($featB->[0] < $featA->[1] and $featA->[0] < $featB->[1]) {
        push @{$acc}, $featA;
        print STDERR "Overlap: [$featA->[0],$featA->[1]] with [$featB->[0],$featB->[1]] \n" if $verbose;
        #print STDERR "Stack:\t" . Dumper($acc);
        return unite_chrom($features, $acc, $featB);
    } else {
        # We've reached the end of the chain (or this interval overlapped nothing else, so we just keep it.)
        push @{$acc}, $featA;
        my $new_start = min(map { $_->[0] } @{$acc});
        my $new_end = max(map { $_->[1] } @{$acc});
        my $new_score = max(map { $_->[2] } @{$acc});

        print STDERR "No Overlap: [$featA->[0],$featA->[1]] with [$featB->[0],$featB->[1]] \n" if $verbose;
        print STDERR "\tNew interval: [$new_start, $new_end] ($new_score)\n" if $verbose;
        my $retval = unite_chrom($features, [], $featB);
        push @{$retval}, [$new_start, $new_end, $new_score];
        return $retval;
    }
}
