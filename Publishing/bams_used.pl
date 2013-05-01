#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

bams_used - Print the BAM files used by a specified list of modENCODE submission ID's as referenced in their respective SDRF files.

=head1 SYNOPSIS

bams_used [options] [ids ...]

=head1 OPTIONS

=over 8

=item B<-f, --full-path>

Prints the full path of the BAM file on the modENCODE machine rather than just the filename.

=item B<-n, --numbered>

=back

Prints each BAM file under its submission ID.

=cut

use Getopt::Long;
Getopt::Long::Configure ("bundling");

my $full_path = '';
my $numbered  = '';
GetOptions('full-path|f' => \$full_path, 'numbered|n' => \$numbered);

if ($#ARGV == -1) {
    die "USAGE: bams_used.pl [-f] [-n] ids";
}

my @subs = @ARGV;

foreach my $sub (@subs) {
    if ($numbered) {
        print "$sub:\n";
    }
    
    my $files = `cat /modencode/raw/data/$sub/extracted/*sdrf*|cut -f12|tail -n +2|sort -u`;
    if ($full_path) {
       my @files = split(/\n/, $files);
       foreach my $file (@files) {
           print "/modencode/raw/data/$sub/extracted/".$file."\n";
       }
    } else {
        print $files;
    }

    if ($numbered and $sub != $subs[$#ARGV]) {
        print "\n";
    }
}
