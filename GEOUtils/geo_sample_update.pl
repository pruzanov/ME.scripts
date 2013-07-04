#!/usr/bin/perl -w

# This code is ugly as all hell.

use strict;
use warnings;

use Cwd;
use Data::Dumper;

=pod

=head1 NAME
geo_sample_update.pl - Process GEO submissions that share files with other submissions

=head1 SYNOPSIS
geo_sample_update.pl [DUPEFILE] [MAPFILE] [SUBIDs..]

=head1 DESCRIPTION
This script takes in a .softer (a .soft file produced by chado2GEO.pl that has been fixed) file,
removes extraneous !Sample_* lines, and inserts !Sample_GEO_accession lines according to MAPFILE.

This script should be run in a directory with the following structure:

    [CWD]
        -> 9001
            > modencode_9001.soft.softer
            > ...
        -> 9002
            > modencode_9002.soft.softer
            > ...
        -> 9003
            > modencode_9003.soft.softer
            > ...
        -> ....

DUPEFILE and MAPFILE should both be in the CWD.

=cut

################################################################################
################### CONFIGURATION VARS - TREAT AS CONST/FINAL ##################
################################################################################
#                                                                              #
my $cwd = getcwd;

#                                                                              #
################################################################################


# read_dupes FILENAME
#
# Processes a file containing the output of a geo_find_common_files.pl run.
# Returns a hashref of filenames to arrayrefs of submission IDs.
#
# This hashref contains only shared filenames.
sub read_dupes {
    my $fname = shift;
    open(my $fh, "<", "$cwd/$fname") or die($!);

    my %fnames_to_ids;
    my $curfile;
    while (<$fh>) {
        chomp;
        if (m/^(\S+) FOUND IN MULTIPLE SUBMISSIONS:$/) {
            $curfile = $1;
            $fnames_to_ids{$curfile} = [] unless exists $fnames_to_ids{$curfile};
        } elsif (m/^\s+([0-9]+)$/) {
            die "Something went wrong, we found an ID before a file!" unless defined $curfile;
            push @{$fnames_to_ids{$curfile}}, $1;
        }
    }
    return \%fnames_to_ids;
}

# read_softer SUBID FILENAME
#
# Read the .softer file named FILENAME into an arrayref and return it.
sub read_softer {
    my $subid = shift;
    my $softfn = shift;

    my @lines;

    open(my $softfh, "<", "$cwd/$subid/$softfn") or die($!);
    while (<$softfh>) {
        chomp;
        push @lines, $_;
    }
    return \@lines;
}

# build_sample_file_map SUBID LINES
#
# Builds a hashref of sample names to files contained in that sample and returns it.
sub build_sample_file_map {
    my $subid = shift;
    my $lines = shift;

    my %sample_to_files;

    # We keep some state outside the loop to keep track of which files are under which samples.
    my $samplename;
    foreach (@{$lines}) {
        next if m/^(!|^)Series/i;

        if (m/^\^Sample\s+=/) {
            $samplename = (split(/\s+=\s+/))[1];
            $sample_to_files{$samplename} = [] unless exists $sample_to_files{$samplename};
        } elsif (m/^!Sample_\S+_file_[0-9]{1,2}/) {
            my $filename = (split(/\s+=\s+/))[1];
            push @{$sample_to_files{$samplename}}, $filename;
        }
    }
    return \%sample_to_files;
}

# placeholder_to_gsm SAMPLENAME SAMPLE_TO_FILES FNAMES_TO_IDS FASTQ_TO_GSM
sub placeholder_to_gsm {
    my $samplename = shift;
    my $sample_to_files = shift;
    my $fnames_to_ids = shift;
    my $fastq_to_gsm = shift;

    foreach my $file (@{$sample_to_files->{$samplename}}) {
        if (grep { (lc $_) eq (lc $file) } (keys %{$fnames_to_ids})) {
            return $fastq_to_gsm->{$file};
        }
    }
    return $samplename;
}

# proc_shared_sample EXCERPT SAMPLE-FILE-MAP FILE-TO-IDS-MAP FASTQ_TO_GSM
#
# Modifies and returns an arrayref of lines EXCERPT corresponding to a SOFT Sample block that
# shares files with other modENCODE submissions.
sub proc_shared_sample {
    my $lines = shift;
    my $sample_to_files = shift;
    my $fnames_to_ids = shift;
    my $fastq_to_gsm = shift;

    # Wow this is ugly.
    my $samplename = (split(/\s+=\s+/, ((grep { $_ =~ m/^\^Sample\s+=/ } @{$lines})[0])))[1];

    foreach my $file (@{$sample_to_files->{$samplename}}) {
        if (grep { (lc $_) eq (lc $file) } (keys %{$fnames_to_ids})) {
            # This is a bit of a hack for karpen_batch_12 only - the only shared files
            # were input fastq's so we just blow away the corresponding raw_file_* entries.
            my @newlines;
            my $filenum;
            foreach (@{$lines}) {
                if (m/^\^Sample\s+=/) {
                    s/\Q$samplename\E/\Q$fastq_to_gsm->{$file}\E/;
                }
                $filenum = $1 if (m/^!Sample_raw_file_([0-9]+)\s+=\s+\Q$file\E$/i);
                next if ($filenum and m/^!Sample_raw_\S+_$filenum/i);
                push @newlines, $_ if m/^!Sample_title/ or m/^!Sample_\S+_file/ or m/^\^Sample/;
            }
            $lines = \@newlines;
    }
}
return $lines;
}

# extract_sample LINES SAMPLENAME
#
# Given a SOFT file read into an arrayref LINES, return those lines
# between "^Sample = SAMPLENAME" and the next "^Sample" line.
sub extract_sample {
    my $lines = shift;
    my $samplename = shift;

    my @excerpt;

    my $in_block = 0;
    foreach (@{$lines}) {
        if (m/^\^Sample\s+=\s+(.+)$/) {
            last if $in_block;
            next unless (lc $1) eq (lc $samplename);
            $in_block = 1;
        }
        next unless $in_block;
        push @excerpt, $_;
    }
    return \@excerpt;
}

# build_fastq_gsm_map FILENAME
sub build_fastq_gsm_map {
    my $filename = shift;
    my %map;
    open(my $fh, "<", "$cwd/$filename") or die($!);

    while (<$fh>) {
        chomp;
        my @fields = split("\t");
        $map{$fields[1]} = $fields[0];
    }
    return \%map;
}

################################################################################
############################ ENTRY POINT #######################################
################################################################################

my $dupefile = shift;
my $mapfile = shift;
foreach my $subid (@ARGV) {
    my $softlines = read_softer($subid, "modencode_$subid.soft.softer");
    my $sample_to_files = build_sample_file_map($subid, $softlines);
    my $fnames_to_ids = read_dupes($dupefile);
    my $fastq_to_gsm = build_fastq_gsm_map ($mapfile);

    foreach (@{$softlines}) {
        last if m/^\^Sample\s+=\s+/i;
        if (m/^!Series_sample_id/) {
# placeholder_to_gsm SAMPLENAME SAMPLE_TO_FILES FNAMES_TO_IDS FASTQ_TO_GSM
            s/=\s+(.*)$/"= " . placeholder_to_gsm($1, $sample_to_files, $fnames_to_ids, $fastq_to_gsm)/e;
        }
        print "$_\n";
    }

    foreach my $sampleline (grep { m/^\^Sample\s+=\s+/i } @{$softlines}) {
        (my $samplename = $sampleline) =~ s/^\^Sample\s+=\s+(.+)$/$1/g;
        print join("\n", @{proc_shared_sample(extract_sample($softlines,$samplename), $sample_to_files, $fnames_to_ids, $fastq_to_gsm)});
        print "\n";
    }

    #print "\n";
}

# sanity tests
#print Dumper(build_sample_file_map($subid, read_softer($subid, "modencode_$subid.soft.softer")));
#print Dumper(read_dupes($dupefile));
#print Dumper(proc_shared_sample(extract_sample(read_softer($subid, "modencode_$subid.soft.softer"),"GSM for H2B-ubiq_(NRO3).L3.Solexa_Input_Rep1 extraction1_seq1"), build_sample_file_map($subid, read_softer($subid, "modencode_$subid.soft.softer")), read_dupes($dupefile)));
#print join("\n", @{extract_sample(read_softer($subid, "modencode_$subid.soft.softer"), "GSM for H2B-ubiq_(NRO3).L3.Solexa_Input_Rep1 extraction1_seq1")});
