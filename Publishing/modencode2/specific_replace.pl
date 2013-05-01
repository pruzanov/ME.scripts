#!/usr/bin/perl

use strict;
use warnings;

my $fin = $ARGV[0];
my $fout = $fin . ".replaced";
open FHIN, '<', $fin or die $!;
open FHOUT, '>', $fout or die $!;

while (<FHIN>) {
    if (/^\!Sample_raw_file_1/) {
        my @line = split(/=/, $_);
        my $cel_filename = $line[1];
        $cel_filename =~ s/^\s+//;
        chomp $cel_filename;

        $cel_filename =~ s/\(|\)/\./g;
        $cel_filename =~ s/ /_/g;
        $cel_filename =~ s/\.\./\./g;
        print "!Sample_raw_file_1 = " . $cel_filename . "\n";
        print FHOUT "!Sample_raw_file_1 = " . $cel_filename . "\n";
    } else {
        print FHOUT $_;
    }
}

close FHIN, $fin or die $!;
close FHOUT, $fout or die $!;
close FHIN;
close FHOUT;
