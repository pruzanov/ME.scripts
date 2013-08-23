#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;

=pod

=head1 NAME

find_overlap.pl - Finds overlapping features in a GFF file.

=head1 SYNOPSIS

find_overlap.pl [GFF]

=head1 DESCRIPTION

Do not include "VISTA" track lines in any GFF you wish to check for overlap.

=cut

# A "GFFSTRUCT" is:
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

# load_file :: GFFPATH -> GFFSTRUCT
# Build our data structure from the GFF3 specified by GFFPATH and return it.
sub load_file {
    my $gff = shift;
    my $features = {};

    open(my $fh, "<", $gff) or die($!);
    while(<$fh>) {
        next if m/^$/ or m/^#/;
        my @cols = split('\t');
        $features->{$cols[0]} = [] unless exists $features->{$cols[0]};
        push $features->{$cols[0]}, [$cols[3], $cols[4], $cols[5], 0];
    }
    close($fh);

    return $features;
}

# sort_features :: GFFSTRUCT -> GFFSTRUCT
# Sorts all features within the GFF3 by start position.
# Only features on the same chromosome are compared against
# each other.
sub sort_features {
    my $gff = shift;

    my %sortedgff;
    foreach (keys %{$gff}) {
        $sortedgff{$_} = [sort { $a->[0] <=> $b->[0] } @{$gff->{$_}}];
    }
    
    return \%sortedgff;
}

# print_gff :: GFFSTRUCT -> ()
# Print a GFF to STDOUT.
sub print_gff {
    my $gff = shift;
    foreach my $chrom (keys %{$gff}) {
        foreach my $feature (@{$gff->{$chrom}}) {
            printf STDOUT "%s\t%d_details\tbinding_site\t%d\t%d\t%.20f\t.\t.\t.\n", $chrom, 4242, $feature->[0],$feature->[1],$feature->[2],
        }
    }
}

# find_overlaps :: GFFSTRUCT -> BOOLEAN
# Prints a message to STDOUT specifying the positions of any overlapping features.
# Returns a true value if we find an overlap.
# Returns false otherwise.
sub find_overlaps {
    my $gffstruct = shift;
    my $overlap = 0;
    foreach my $chrom (keys %{$gffstruct}) {
        my $prev_feat = shift @{$gffstruct->{$chrom}};
        foreach my $feature (@{$gffstruct->{$chrom}}) {
            if ($prev_feat->[0] < $feature->[1] and $prev_feat->[1] > $feature->[0]) {
                next if $prev_feat->[0] == $feature->[0] and $prev_feat->[1] == $feature->[1];
                print STDOUT "Found overlap on chromosome $chrom! [$prev_feat->[0], $prev_feat->[1]], [$feature->[0], $feature->[1]]\n";
                $overlap = 1;
            }
        }
    }
    return $overlap;
}

my $gffpath = shift;
my $gffstruct = load_file($gffpath);
find_overlaps(sort_features($gffstruct));
#print_gff(sort_features($gffstruct));
#print Dumper($gffstruct);
#print STDERR Dumper(sort_features($gffstruct));
#sort_features($gffstruct);
