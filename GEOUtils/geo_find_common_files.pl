#!/usr/bin/perl

=pod

=head1 NAME
geo_find_common_files.pl - Find supplementary/raw files common to multiple modENCODE submissions to be sent to GEO.

=head1 SYNOPSIS
geo_find_common_files.pl [FILE..]

=head1 DESCRIPTION
Just run this script in a directory full of "modencode_ID_chado_datafiles.txt" files, produced by chado2GEO.pl in
reporter_seq. It will output a list of files found in two or more submissions.

=cut

use Data::Dumper;
use Cwd;

# scan_folder
#
# Opens the cwd and reads all files matching 
# m/^modencode_([0-9])+_chado_datafiles\.txt$/ to generate
# a hashref of filenames to modENCODE_IDs.
sub scan_folder {
    my %files_to_subs;
    opendir(my $dh, getcwd) or die($!);
    while (readdir $dh) {
        if (m/^modencode_([0-9]+)_chado_datafiles\.txt$/) {
            open(my $fh, "<", getcwd . "/" . $_) or die ($!);
            while (<$fh>) {
                chomp;
                $files_to_subs{$_} = [] unless exists $files_to_subs{$_};
                push @{$files_to_subs{$_}}, $1;
            }
        }
    }
    return \%files_to_subs;
}

# find_dupes FILESTOSUBS
#
# Takes in a hashref of filenames to modENCODE_IDs (returned by scan_folder)
# and prints, to STDOUT, a list of files found in two or more submissions.
sub find_dupes {
    my $files_to_subs = shift;
    foreach my $file (keys %{$files_to_subs}) {
        if (scalar @{$files_to_subs->{$file}} > 1) {
            print "="x80 . "\n";
            print "$file FOUND IN MULTIPLE SUBMISSIONS:\n";
            print "="x80 . "\n";
            foreach my $sub (@{$files_to_subs->{$file}}) {
                print "\t$sub\n";
            }
        }
    }
}

################################################################################
# ENTRY POINT
################################################################################
find_dupes(scan_folder());
