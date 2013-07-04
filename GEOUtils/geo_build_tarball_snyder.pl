#!/usr/bin/perl -w

use strict;
use warnings;

use Cwd;
use Net::SCP qw(scp iscp);
use Archive::Tar::Wrapper;

=pod

=head1 NAME
geo_build_tarball_snyder.pl - Builds modENCODE_[SUBID].tar.gz and writes it to standard output. Designed for Snyder submissions.

=head1 SYNOPSIS
geo_build_tarball_snyder.pl [SUBIDS..]

=head1 DESCRIPTION
geo_build_tarball_snyder.pl should be run from a directory with the following structure:

[currentworkingdirectory]
	---> 9001
	---> 9002
	---> 9003
	---> ....


This script will descend into each directory in turn, and expects to find a tab-delimited text file called
"files" with:

	Anything you want in the first column. We don't read it.

    A list of all supplementary and raw files that should be present in the SOFT file
    in the second column. This script is a bit of a kludge.

We also expect modencode_[SUBID].soft files to be present in each directory. They really only
need to be there so that we can pack them into the final tarball.

=cut

################################################################################
################## "FINAL" VARIABLES - DO NOT MODIFY AT RUNTIME ################
################################################################################

my $basedir = getcwd;
my $modencode_host = "modencode-www1.oicr.on.ca";
my $modencode_datadir = "/modencode/raw/data/";
my $modencode_extractdir = "extracted/Sny*";

foreach my $subid (@ARGV) {

    print STDERR "================================================================================\n";
    print STDERR "============================ Processing $subid ===================================\n";
    print STDERR "================================================================================\n";

    my $subfolder = "$basedir/$subid";
    opendir(my $dh, $subfolder) or die($!);
    open(my $flistfh, "<", "$subfolder/files") or die($!);

    my @files;
    while (<$flistfh>) {
        chomp;
        my @fields = split("\t");
        push @files, $fields[1];
    }

    foreach (@files) {
        unless (-e "$subfolder/$_") {
            scp("$modencode_host:$modencode_datadir" . "$subid/$modencode_extractdir/$_", "$subfolder/$_") or die "Gee, Net::SCP sure leaves some verbose errors. Don't know why, but we failed to scp.";
        }
    }

    chdir($dh) or die($!);

    my @cmd = ("tar", "cvzf", "modencode_$subid.tar.gz");
    push @cmd, @files;
    push @cmd, "modencode_$subid.soft";
    system(@cmd) == 0 or die($!);
    foreach (@files) {
        system("rm", "-v", $_);
    }

    chdir($basedir);

    #print STDERR join(' ', @cmd);
    #my $tar = Archive::Tar::Wrapper->new();
    #foreach (@files) {
    #    $tar->add("", $_) or die ($!);
    #}
    #$tar->add("", "modencode_$subid.soft.softer") or die($!);
    #$tar->write("modencode_$subid.tar.gz", 1) or die($!);
    #chdir($basedir);
}
