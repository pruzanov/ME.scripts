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
use List::Util qw(max);
use List::MoreUtils qw(uniq);
use Cwd;

# We define an equivalence relation over the set of submissions (modENCODE_IDs).
# We say two submissions are equivalent if they share some data file.
sub eqv {
    my ($s1, $s2, $subs_to_files) = @_;
    foreach (@{$subs_to_files->{$s1}}) {
        return 1 if $_ ~~ @{$subs_to_files->{$s2}};
    }
    return 0;
}

# scan_folder
#
# Opens the cwd and reads all files matching 
# m/^modencode_([0-9])+_chado_datafiles\.txt$/ to generate
# a hashref of filenames to modENCODE_IDs.
sub scan_folder {
    my %files_to_subs;
    my %subs_to_files;
    opendir(my $dh, getcwd) or die($!);
    while (readdir $dh) {
        if (m/^modencode_([0-9]+)_chado_datafiles\.txt$/) {
            open(my $fh, "<", getcwd . "/" . $_) or die ($!);
            while (<$fh>) {
                chomp;
                $files_to_subs{$_} = [] unless exists $files_to_subs{$_};
                $subs_to_files{$1} = [] unless exists $subs_to_files{$1};
                push @{$files_to_subs{$_}}, $1;
                push @{$subs_to_files{$1}}, $_;
            }
        }
    }
    return (\%files_to_subs, \%subs_to_files);
}

# find_dupes FILESTOSUBS
#
# Takes in a hashref of filenames to modENCODE_IDs (returned by scan_folder)
# and prints, to STDOUT, a list of files found in two or more submissions.
sub find_dupes {
    my ($files_to_subs, $subs_to_files) = @_;
    my %subid_tally;
    my @shared_files;
    foreach my $file (keys %{$files_to_subs}) {
        if (scalar @{$files_to_subs->{$file}} > 1) {
            #print "="x80 . "\n";
            #print "$file FOUND IN MULTIPLE SUBMISSIONS:\n";
            #print "="x80 . "\n";
            push @shared_files, $file;
            foreach my $sub (sort { $b <=> $a } @{$files_to_subs->{$file}}) {
                print "$file\t$sub\n";
                if (exists $subid_tally{$sub}) {
                    $subid_tally{$sub} += 1;
                } else {
                    $subid_tally{$sub} = 1;
                }
            }
        }
    }

    my @subs = sort { $subid_tally{$b} <=> $subid_tally{$a} } (keys %subid_tally);

    print STDERR "="x80 . "\n";
    print STDERR "I suggest sending:\n";
    print STDERR "="x80 . "\n";
    while (@subs) {
        my $sendme = shift @subs;
        printf STDERR "%d\n", $sendme;
        print STDERR "\tWhich contains the shared files:\n";
        print STDERR "-"x80 . "\n\t";
        print STDERR join("\n\t", grep { not m/TMPID/ and $_ ~~ @shared_files } uniq @{$subs_to_files->{$sendme}});
        print STDERR "\n";
        @subs = grep { not eqv($sendme, $_, $subs_to_files) } @subs;
    }
}


################################################################################
# ENTRY POINT
################################################################################
find_dupes(scan_folder());
