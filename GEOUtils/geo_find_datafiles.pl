#!/usr/bin/perl -w

=pod

=head1 NAME

geo_find_datafiles.pl - Generates a .txt list of raw and supplementary files associated with a modENCODE submission

=head1 SYNOPSIS

geo_find_datafiles.pl [-s] [SDRF]

=head1 CAVEATS

=over 8

=item Some SDRF files on the pipeline contain GEO:TMPID entries which will appear
in this script's output.


=item If you plan to use this script for building GEO tarballs, please ensure
that you remove extraneous entries from the generated datafiles.txt file -
this script may pick up 'GEO:TMPID' entries, bam and sam files, or other
files that are not accepted by GEO.

=back

=head1 OPTIONS

=over 8

=item B<-s>
Prints a display relating sample names in the SDRF to files within that sample.

=cut

use strict;
use warnings;

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Getopt::Std;
our($opt_s);

# transpose MATRIX
# transpose MATRIX _ACCUMULATOR
#
# MATRIX :: arrayref of arrayrefs
# _ACCUMULATOR :: arrayref of arrayrefs (INTERNAL USE, defaults to empty list)
sub transpose {
    my $mref = shift;
    my $acc = shift || []; 

    my @matrix = map { [@$_] } @{$mref};

    # This is our recursive base case.
    return $acc unless scalar(@{$matrix[0]});

    push(@{$acc}, [map { $_->[0] } @matrix]);
    return transpose([map { shift $_; $_ } (my @matrix_ = @matrix)], $acc);
}

# trim_sdrf SDRFMATRIX
#
# Return a submatrix of SDRFMATRIX consisting of the first column
# and all file columns.
#
# ARGUMENTS:
# SDRFNAME :: String
sub trim_sdrf {
    my $sdrfmatrix = shift;

    my $sdrftranspose = transpose($sdrfmatrix);
    # This is the submatrix of SDRFMATRIX that only contains
    # those columns necessary for building a SOFT file out
    # of the entire SDRF.
    #my @softmatrix = grep { $_->[0] =~ m/Result File \[.+\]/ } @{$sdrftranspose};
    my @softmatrix = grep { $_->[0] =~ m/Result File \[.+\]/ or $_->[0] =~ m/Result Value \[fastq file\]/ } @{$sdrftranspose};
    splice(@softmatrix, 0, 0, $sdrftranspose->[0]);

    return transpose(\@softmatrix);

}

# sdrf_to_matrix SDRFNAME
#
# Open the file specified by SDRFNAME and read it into
# an arrayref of arrayref of Strings.
#
# Return value: Arrayref of arrayref of Strings (An SDRFMATRIX)
#
# ARGUMENTS:
# SDRFNAME :: String
sub sdrf_to_matrix {
    my $sdrfname = shift;
    my @matrix;

    open(my $fh, "<", $sdrfname) or die($!);
    chomp(my @rows = <$fh>);
    close($fh);

    foreach (@rows) {
        push @matrix, [split("\t")];
    }
    return \@matrix;
}

# print_plain SDRFNAME
# Just prints all the datafiles we found.
sub print_plain {
    my $trimmed_sdrf = trim_sdrf(sdrf_to_matrix(shift));
    shift @{$trimmed_sdrf};
    my @files;
    foreach (@{$trimmed_sdrf}) {
        foreach my $file (@{$_}[1..$#{$_}]) {
            next unless $file;
            push @files, $file unless grep { $_ eq $file } @files;
        }
    }

    print STDOUT join("\n", @files);
}

# sample_view SDRFNAME
#
# Shows all the datafiles associated with all the samples in the SDRF.
sub sample_view {
    my $trimmed_sdrf = trim_sdrf(sdrf_to_matrix(shift));
    shift @{$trimmed_sdrf};
    my %samples;
    foreach (map { $_->[0] } @{$trimmed_sdrf}) {
        $samples{$_} = [] unless exists $samples{$_};
    }

    foreach (@{$trimmed_sdrf}) {
        foreach my $file (@{$_}[1..$#{$_}]) {
            push @{$samples{$_->[0]}}, $file unless grep { $_ eq $file } @{$samples{$_->[0]}};
        }
    }

    foreach my $sample (keys %samples) {
        foreach my $file (@{$samples{$sample}}) {
            print STDOUT "$sample\t$file\n";
        }
    }
}

getopts("s");
if (defined $opt_s) {
    sample_view(shift);
} else {
    print_plain(shift);
}
#print STDERR Dumper(trim_sdrf(sdrf_to_matrix(shift)));
