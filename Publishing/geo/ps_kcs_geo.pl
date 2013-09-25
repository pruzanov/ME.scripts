#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use File::Slurp;

# Die if improper number of arugments are give.
if ($#ARGV < 2) {
    die "SYNTAX: $0 <soft_file> <name> <short_name>";
}

# Open and specify the input and output SOFT files.
my $fin = $ARGV[0];
my $fout = $fin . '.softer';
open FHIN, '<', $fin or die $!;
open FHOUT, '>', $fout or die $!;

# Get the submission's ID, name and short name, then generate an "underscored"
# version.
my $sub = $1 if $fin =~ m/modencode_([0-9]+)/;
my $name = $ARGV[1];
my $short_name = $ARGV[2];
$name =~ s/^\s+|\s+$//;
$short_name =~ s/^\s+|\s+$//;
(my $nameu = $name) =~ s/ /_/g;

print "Submission:       $sub\n";
print "Submission name:  $name\n";
print "Shortened name:   $short_name\n";
print "Underscored name: $nameu\n";

# Determine what FASTQ files exist in this directory and store them in a hash.
# The hash contains two hashes, input and chip, containing the input FASTQ
# files and the ChIP FASTQ files. These in turn contain key value pairs of 
# experiment numbers and FASTQ filenames.
my %fastq_files;
my $dir = getcwd;
opendir(DIR, $dir) or die $!;
my @dir_files = readdir DIR;

foreach (@dir_files) {
    if (m/fastq/i) {
        my @file_name = split /\./;
        my $expt_number = $file_name[-3];
        
        if (m/input/i) {
            $fastq_files{$expt_number}{filename} = $_;
            $fastq_files{$expt_number}{type} = 'input';
        } else {
            $fastq_files{$expt_number}{filename} = $_;
            $fastq_files{$expt_number}{type} = 'chip';
        }
    }
}

# Now we order the files. Input FASTQ files always come before ChIP FASTQ files
# and within each group they are sorted by increasing experiment number.
my @expt_order;
foreach (sort {$a <=> $b} keys %fastq_files) {
    if ($fastq_files{$_}{type} eq 'input') {
        push @expt_order, $_;
    }
}
foreach (sort {$a <=> $b} keys %fastq_files) {
    if ($fastq_files{$_}{type} eq 'chip') {
        push @expt_order, $_;
    }
}

# Now we download and parse the submission's SDRF file and find what
# supplementary gff3 files belond to each experiment and store them in a list
# under the experiment number in the hash.
system("scp", "-q", "modencode-www1.oicr.on.ca:/modencode/raw/data/$sub/extracted/*SDRF.txt", "./$sub.sdrf.txt");
my @sdrf = read_file("$sub.sdrf.txt");
system("rm", "-v", "./$sub.sdrf.txt");

foreach (@sdrf) {
    next if $_ !~ m/^expt\./;
    my @line = split /\t/;

    my $expt_number = $line[0];
    $expt_number =~ s/expt\.//g;
    $expt_number =~ s/^\s+//g;
    chomp $expt_number;

    my $supplementary_gff3 = $1 if $_ =~ m/([^\t]+\.gff[3]?)/i;
    $supplementary_gff3 =~ s/\s+//g;
    chomp $supplementary_gff3;

    print "$expt_number -> $supplementary_gff3\n";

    if (!exists $fastq_files{$expt_number}{gff3s}) {
        $fastq_files{$expt_number}{gff3s} = [];
    }

    push @{$fastq_files{$expt_number}{gff3s}}, $supplementary_gff3;
}

# Remove duplicate gff3's.
use List::MoreUtils qw(uniq);
foreach (keys %fastq_files) {
    @{$fastq_files{$_}{gff3s}} = uniq(@{$fastq_files{$_}{gff3s}});
}

#use Data::Dumper;
#print Dumper(%fastq_files);
#print Dumper(@expt_order);
#exit;

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
my $new_raw_file = 0;

# Finally create the new SOFT file.
while (<FHIN>) {
    if (m/^!Series_sample_id/) {
        my $expt_type_suffix = "";
        my $expt_rep_suffix  = "";

        # To determine whether the current file is an Input or ChIP, we check
        # if the filename contains the string 'input'. This should work for any
        # number of FASTQ files as long as all Input FASTQ's have the 'Input'
        # in their filename, which seems to be the case.
        # It also determines which replicate we're currently working with,
        # which is kept track of using two counters. This same code is used to
        # determine type and rep suffixes for other fields.
        if ($fastq_files{$expt_order[$series_sample_id_counter-1]}{type} eq 'input') {
            $expt_type_suffix = "Input";
            $expt_rep_suffix = "Rep" . $series_sample_id_input_rep_counter++;
        } else {
            $expt_type_suffix = "ChIP";
            $expt_rep_suffix = "Rep" . $series_sample_id_chip_rep_counter++;
        }

        my $series_sample_id_suffix = "extraction" . $series_sample_id_counter . "_seq" . $series_sample_id_counter;
        print FHOUT "!Series_sample_id = GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $series_sample_id_suffix . "\n";
        $series_sample_id_counter++;
    }
    elsif (m/^\^Sample/) {
        my $expt_type_suffix = "";
        my $expt_rep_suffix  = "";

        if ($fastq_files{$expt_order[$sample_counter-1]}{type} eq 'input') {
            $expt_type_suffix = "Input";
            $expt_rep_suffix = "Rep" . $sample_input_rep_counter++;
        } else {
            $expt_type_suffix = "ChIP";
            $expt_rep_suffix = "Rep" . $sample_chip_rep_counter++;
        }

        my $sample_suffix = "extraction" . $sample_counter . "_seq" . $sample_counter;
        print FHOUT "^Sample = GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $sample_suffix . "\n";

        # We've entered a new ^Sample, this is to alert the block that deals
        # with supplementary files.
        $new_sample = 1;
        $sample_counter++;
    }
    elsif (m/^!Sample_title/) {
        my $expt_type_suffix = "";
        my $expt_rep_suffix  = "";

        if ($fastq_files{$expt_order[$sample_title_counter-1]}{type} eq 'input') {
            $expt_type_suffix = "Input";
            $expt_rep_suffix = "Rep" . $sample_title_input_rep_counter++;
        } else {
            $expt_type_suffix = "ChIP";
            $expt_rep_suffix = "Rep" . $sample_title_chip_rep_counter++;
        }

        print FHOUT "!Sample_title = " . $name . " " . $expt_type_suffix . " " . $expt_rep_suffix . "\n";
        $sample_title_counter++;
    }
    elsif (m/^!Sample_source_name/) {
        my $expt_type_suffix = "";

        if ($fastq_files{$expt_order[$sample_source_name_counter-1]}{type} eq 'input') {
            $expt_type_suffix = "Input";
        } else {
            $expt_type_suffix = "ChIP";
        }

        my $expt_number = $expt_order[$sample_source_name_counter-1];

        print FHOUT "!Sample_source_name = " . $short_name . " " . $expt_type_suffix . " expt." . $expt_number . "\n";
        $sample_source_name_counter++;
    }
    elsif (m/^!Sample_supplementary_file/) {
        if ($new_sample) {
            $new_sample = 0;
            $sample_sup_file_counter = 1;

            foreach (@{$fastq_files{$expt_order[$sample_counter-2]}{gff3s}}) {
                print FHOUT "!Sample_supplementary_file_" . $sample_sup_file_counter . " = " . $_ . "\n";
                print FHOUT "!Sample_supplementary_file_type_" . $sample_sup_file_counter . " = GFF3\n";
                $sample_sup_file_counter++;
            }
        } else {
            $new_raw_file = 1;
            next;
        }
    }
    elsif (m/^!Sample_raw_file/) {
        if ($new_raw_file) {
            $new_raw_file = 0;

            my $fastq_filename = $fastq_files{$expt_order[$sample_counter-2]}{filename}; # FIXME: Potential danger with using $sample_counter here!

            # Making the FASTQ filename string safe to pass to the UNIX shell by escaping brackets and spaces.
            (my $fastq_filename_escaped = $fastq_filename) =~ s/\(/\\\(/g;
            $fastq_filename_escaped =~ s/\)/\\\)/g;
            $fastq_filename_escaped =~ s/ /\\ /g;

            # Calculate the FASTQ's MD5 checksum.
            print "Calculating md5 checksum for " . $fastq_filename . "...\n";
            my $fastq_checksum = `md5sum $fastq_filename_escaped | cut -d ' ' -f1`;
            $fastq_checksum =~ s/^\s+//;
            chomp $fastq_checksum;

            print FHOUT "!Sample_raw_file_1 = " . $fastq_filename . "\n";
            print FHOUT "!Sample_raw_file_type_1 = FASTQ\n";
            print FHOUT "!Sample_raw_file_checksum_1 = " . $fastq_checksum . "\n";
        } else {
            next;
        }
    }
    else {
        print FHOUT $_;
    }
}

close FHIN, $fin or die $!;
close FHOUT, $fout or die $!;
close FHIN;
close FHOUT;
