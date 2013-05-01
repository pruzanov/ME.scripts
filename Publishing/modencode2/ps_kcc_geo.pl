#!/usr/bin/perl

use strict;
use warnings;

use Cwd;

# Die if no input is given.
if ($#ARGV == -1) {
    die "No input SOFT file given!"
}

# Open and specify the input and output SOFT files.
my $fin = $ARGV[0];
my $fout = $fin . '.softer';
open FHIN, '<', $fin or die $!;   # Dying with $! lets perl print its own error message,
open FHOUT, '>', $fout or die $!; # which looks to be better than what I come up with.

# Ask for the submission's name and generate the "underscored" version.
print "Submission name: ";
my $name = <STDIN>;
$name =~ s/^\s+//;
chomp $name;
(my $nameu = $name) =~ s/ /_/g;

# Ask for the short name.
print "Short name: ";
my $short_name = <STDIN>;
$short_name =~ s/^\s+//;
chomp $short_name;

# Determine what CEL files exist in this directory and store them in a hash.
my %cel_files;
my $dir = getcwd;
opendir(DIR, $dir) or die $!;
my @dir_files = readdir DIR;

my $file_counter = 1;
foreach (@dir_files) {
    $cel_files{$file_counter++} = $_ if /CEL/;
}

# Ask user about order of CEL files. The naming seems too inconsistent to rely on
# automated ordering.
# Actually, you could split them up into Input files or not, then order them by experiment
# number. That would automate the process reliably as long as Input CEL files always have
# input in the filename and the ChIP CEL files do not.
my @cel_files;
while (%cel_files) {
    # TODO: This next line may be troublesome but hey, it works!
    # http://stackoverflow.com/questions/3033/whats-the-safest-way-to-iterate-through-the-keys-of-a-perl-hash
    foreach (sort {$a <=> $b} keys %cel_files) {
        print "[$_] $cel_files{$_}\n";
    }

    if (scalar @cel_files == 0) {
        print "Which CEL file comes in first? ";
    } else {
        print "Which CEL file comes next? ";
    }

    my $key_to_add = <STDIN>;
    $key_to_add =~ s/^\s+//;
    chomp $key_to_add;

    print "\n";

    push @cel_files, $cel_files{$key_to_add};
    delete $cel_files{$key_to_add};
}

# Counters.
my $series_sample_id_counter   = 1; # Counts which !Series_sample_id          field we're on.
my $sample_counter             = 1; # Counts which ^Sample                    field we're on.
my $sample_title_counter       = 1; # Counts which !Sample_title              field we're on.
my $sample_source_name_counter = 1; # Counts which !Sample_source_name_ch1    field we're on.
my $sample_sup_file_counter    = 1; # Counts which !Sample_supplementary_file set of fields we're on.

my $series_sample_id_input_rep_counter = 1; # Counts which Input replicate we're currently on in the !Series_sample_id fields.
my $series_sample_id_chip_rep_counter  = 1; # Counts which ChIP  replicate we're currently on in the !Series_sample_id fields.
my $sample_input_rep_counter           = 1; # Counts which Input replicate we're currently on in the ^Sample fields.
my $sample_chip_rep_counter            = 1; # Counts which ChIP  replicate we're currently on in the ^Sample fields.
my $sample_title_input_rep_counter     = 1; # Counts which Input replicate we're currently on in the !Sample_title fields.
my $sample_title_chip_rep_counter      = 1; # Counts which ChIP  replicate we're currently on in the !Sample_title fields.

my $new_sample = 0;

# Finally create the new SOFT file.
while (<FHIN>) {
    if (/^!Series_sample_id/) {
        my $expt_type_suffix = "";
        my $expt_rep_suffix  = "";

        # To determine whether the current file is an Input or ChIP, we grep the filename for case insensitive 'Input'.
        # This should work for any number of CEL files as long as all Input CEL's have the 'Input' in their filename, which
        # seems to be the case.
        # It also determines which replicate we're currently working with, which is kept track of using two counters.
        # This same code is used to determine type and rep suffixes for other fields.
        if (index(lc($cel_files[$series_sample_id_counter-1]), 'input') > -1) {
            $expt_type_suffix = "Input";
            $expt_rep_suffix = "Rep" . $series_sample_id_input_rep_counter++;
        } else {
            $expt_type_suffix = "ChIP";
            $expt_rep_suffix = "Rep" . $series_sample_id_chip_rep_counter++;
        }

        my $series_sample_id_suffix = "extraction" . $series_sample_id_counter . "_array" . $series_sample_id_counter;
        print FHOUT "!Series_sample_id = GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $series_sample_id_suffix . "\n";
        $series_sample_id_counter++;
    } elsif (/^\^Sample/) {
        my $expt_type_suffix = "";
        my $expt_rep_suffix  = "";

        if (index(lc($cel_files[$sample_counter-1]), 'input') > -1) {
            $expt_type_suffix = "Input";
            $expt_rep_suffix = "Rep" . $sample_input_rep_counter++;
        } else {
            $expt_type_suffix = "ChIP";
            $expt_rep_suffix = "Rep" . $sample_chip_rep_counter++;
        }

        my $sample_suffix = "extraction" . $sample_counter . "_array" . $sample_counter;
        print FHOUT "^Sample = GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $sample_suffix . "\n";

        $new_sample = 1; # We've entered a new ^Sample, this is to alert the block that deals with supplementary files.
        $sample_counter++;
    } elsif (/^!Sample_title/) {
        my $expt_type_suffix = "";
        my $expt_rep_suffix  = "";

        if (index(lc($cel_files[$sample_title_counter-1]), 'input') > -1) {
            $expt_type_suffix = "Input";
            $expt_rep_suffix = "Rep" . $sample_title_input_rep_counter++;
        } else {
            $expt_type_suffix = "ChIP";
            $expt_rep_suffix = "Rep" . $sample_title_chip_rep_counter++;
        }

        print FHOUT "!Sample_title = " . $name . " " . $expt_type_suffix . " " . $expt_rep_suffix . "\n";
        $sample_title_counter++;
    } elsif (/^!Sample_source_name_ch1/) {
        my $expt_type_suffix = "";

        if (index(lc($cel_files[$sample_source_name_counter-1]), 'input') > -1) {
            $expt_type_suffix = "Input";
        } else {
            $expt_type_suffix = "ChIP";
        }

        my @file_name = split(/\./, $cel_files[$sample_source_name_counter-1]);
        my $expt_number = $file_name[-3]; # Assuming all CEL files are named "...xxxx.CEL.ZIP" where xxxx is the experiment number.

        print FHOUT "!Sample_source_name_ch1 = " . $short_name . " " . $expt_type_suffix . " expt." . $expt_number . " channel_1" . "\n";
        $sample_source_name_counter++;
    } elsif (/^!Sample_supplementary_file/) {
        my @line = split(/=/, $_);
        my $sup_file = $line[1];
        $sup_file =~ s/^\s+//;
        chomp $sup_file;

        if ($new_sample) {
            $sample_sup_file_counter = 1;
            $new_sample = 0;
        }

        if (index(lc($sup_file), 'wig') > -1) {
            my $wig_file = $sup_file;

            print "Is [" . $cel_files[$sample_counter-2] . " -> " . $wig_file . "] correct? "; # FIXME: Potential danger with using $sample_counter here!
            my $correct_wig_file = <STDIN>;
            $correct_wig_file =~ s/^\s+//;
            chomp $correct_wig_file;
            
            next if (lc($correct_wig_file) eq "d"); # We should delete this WIG file entry, so move on.
            
            if ($correct_wig_file ne "") { # User entered the correct WIG's file name.
                $wig_file = $correct_wig_file;
            }

            print FHOUT "!Sample_supplementary_file_" . $sample_sup_file_counter . " = " . $wig_file . "\n";
            print FHOUT "!Sample_supplementary_file_type_" . $sample_sup_file_counter . " = WIG\n";
        } elsif (index(lc($sup_file), 'gff') > -1) {
            # We look for the line that specifies the gff file. As it's always the last file in the list of supplementary files,
            # we delete the entry and insert a raw_file block instead.

            my $cel_filename = $cel_files[$sample_counter-2]; # FIXME: Potential danger with using $sample_counter here!

            # Making the CEL filename string safe to pass to the UNIX shell by escaping brackets and spaces.
            (my $cel_filename_escaped = $cel_filename) =~ s/\(/\\\(/g;
            $cel_filename_escaped =~ s/\)/\\\)/g;
            $cel_filename_escaped =~ s/ /\\ /g;

            # Calculate the CEL's MD5 checksum.
            my $cel_checksum = `md5sum $cel_filename_escaped|cut -d ' ' -f1`;
            $cel_checksum =~ s/^\s+//;
            chomp $cel_checksum;

            print FHOUT "!Sample_raw_file_1 = " . $cel_filename . "\n";
            print FHOUT "!Sample_raw_file_type_1 = CEL\n";
            print FHOUT "!Sample_raw_file_checksum_1 = " . $cel_checksum . "\n";
        }

        $sample_sup_file_counter++;
    } else {
        print FHOUT $_;
    }
}

close FHIN, $fin or die $!;
close FHOUT, $fout or die $!;
close FHIN;  # Not sure why I close each handle/file twice, the example said so.
close FHOUT; # TODO: Look into why this is.
