#!/usr/bin/perl -w

use strict;
use warnings;

use Cwd;
use Net::SCP qw(scp iscp);
use Archive::Tar::Wrapper;
use Getopt::Std;
our($opt_f);

=pod

=head1 NAME

geo_build_tarball.pl - Builds modENCODE_[SUBID].tar.gz and writes it to standard output. Designed for Snyder submissions.

=head1 SYNOPSIS

geo_build_tarball.pl [-f] [SUBIDS..]

=head1 DESCRIPTION

geo_build_tarball.pl should be run from a directory with the following structure:

[currentworkingdirectory]

	---> 9001

	---> 9002

	---> 9003

	---> ....


This script will descend into each directory in turn, and expects to find a text file called
"datafiles.txt" with a list of all supplementary and raw files that should be present in the SOFT file.
Lines beginning with '#' are ignored.

We also expect modencode_[SUBID].soft files to be present in each directory. They really only
need to be there so that we can pack them into the final tarball.

	-f
    	Fetch only; do not build tarball.

=cut

################################################################################
################## "FINAL" VARIABLES - DO NOT MODIFY AT RUNTIME ################
################################################################################

my $basedir = getcwd;
my $modencode_host = "modencode-www1.oicr.on.ca";
my $modencode_datadir = "/modencode/raw/data/";
my $modencode_extractdir = "extracted/";

my $scp = Net::SCP->new($modencode_host);

getopts('f');
foreach my $subid (@ARGV) {

    print STDERR "================================================================================\n";
    print STDERR "============================ Processing $subid ===================================\n";
    print STDERR "================================================================================\n";

    my $subfolder = "$basedir/$subid";
    opendir(my $dh, $subfolder) or die($!);
    open(my $flistfh, "<", "$subfolder/datafiles.txt") or die($!);

    my @files;
    while (<$flistfh>) {
        chomp;
        push @files, $_;
    }

    foreach (@files) {
        unless (-e "$subfolder/$_") {
            $scp->scp("$modencode_host:$modencode_datadir" . "$subid/$modencode_extractdir/$_", "$subfolder/$_") or die $scp->{errstr};
        }
    }

    unless ($opt_f) {
        chdir($dh) or die($!);
        my @cmd = ("tar", "cvzf", "modencode_$subid.tar.gz");
        push @cmd, @files;
        push @cmd, "modencode_$subid.soft";
        system(@cmd) == 0 or die($!);
        foreach (@files) {
            system("rm", "-v", $_);
        }

        chdir($basedir);
    }

    #print STDERR join(' ', @cmd);
    #my $tar = Archive::Tar::Wrapper->new();
    #foreach (@files) {
    #    $tar->add("", $_) or die ($!);
    #}
    #$tar->add("", "modencode_$subid.soft.softer") or die($!);
    #$tar->write("modencode_$subid.tar.gz", 1) or die($!);
    #chdir($basedir);
}
