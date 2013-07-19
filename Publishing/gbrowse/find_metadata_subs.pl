#!/usr/bin/perl -w

=pod

=head1 NAME

find_metadata_subs.pl - Identify metadata-only modENCODE submissions

=head1 SYNOPSIS

find_metadata_subs.pl [FILELIST]

=head1 DESCRIPTION

FILELIST is a text file containing all files found for some submission(s) on
modencode-www1:/modencode/raw/data/[SUBID]/extracted

Example input file:

	/modencode/raw/data/9001/extracted/9001.idf
	/modencode/raw/data/9001/extracted/9001.sdrf
    /modencode/raw/data/9002/extracted/9002.idf
    /modencode/raw/data/9002/extracted/9002.sdrf
    /modencode/raw/data/9002/extracted/9002.gff
    /modencode/raw/data/9002/extracted/9002.fastq
    /modencode/raw/data/9002/extracted/9002.wig

=cut

use strict;
use warnings;

use Data::Dumper;

my %ids_to_files;

while (<>) {
    if (m!^/modencode/raw/data/([0-9]+)/extracted/(.*)!) {
        $ids_to_files{$1} = [] unless exists $ids_to_files{$1};
        push @{$ids_to_files{$1}}, $2;
    }
}

foreach my $id (keys %ids_to_files) {
    my $found_data = 0;
    foreach my $file (@{$ids_to_files{$id}}) {
        if ($file =~ m/\.wig/i or $file =~ m/\.gff/i or $file =~ m/\.bam/i or $file =~ m/\.fastq/i) {
            $found_data = 1;
        }
    }
    print "$id is a metadata only submission!\n" unless $found_data;
}
