#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use File::Slurp;

# User-set variables here
# $sdrf_path is the filepath to the SDRF file for the current experiment on modencode-www1
# The problem with using a user-set variable for the SDRF path is the modENCODE...
# ...submission ID being part of the filepath
# This could be placed after the submission ID has been processed or inputted by the user...
# ...but this makes it hard to find and awkwardly placed
# An idea: Use a placeholder for the modENCODE submission ID then use a s/// regex...
# ...to replace the placeholder once the submission ID has been determined
# Note to users: The [SUB_ID] in the filepath will be replaced with the modENCODE submission ID
# There may or may not be a better way to go about generating the filepath
# Commented out because SDRF files are not being used, as they may be inconsistent or unreliable
# my $sdrf_path = 'modencode-www1.oicr.on.ca:/modencode/raw/data/[SUB_ID]/extracted/*SDRF.txt';

# Die if no input is given.
if ($#ARGV == -1) {
    die "No input SOFT file given!"
}

# Open and specify the input and output SOFT files.
my $fin = $ARGV[0];
my $fout = $fin . '.softer';
open FHIN, '<', $fin or die $!;   # Dying with $! lets perl print its own error message,
open FHOUT, '>', $fout or die $!; # which looks to be better than what I come up with.
my @old_soft = read_file($fin);
die "Could not read SOFT file; died" unless @old_soft;

# Get the submission's ID
my $sub;
if ($fin =~ m/modencode_([0-9]+)/) {
	$sub = $1;
} else {
	print "modENCODE Submission ID: ";
	$sub = <STDIN>;
	$sub =~ s/^\s+//;
	chomp $sub;
	die "Unrecognized submission ID, died" unless $sub =~ m/^[0-9]+$/;
}

# Update the filepath to the SDRF files to reflect the submission ID
# Commented out because SDRF files are not being used, as they may be inconsistent or unreliable
# $sdrf_path =~ s/\[SUB_ID\]/$sub/;

# Attempt to detect experiment type (ChIP-seq or ChIP-chip) from SOFT file
# Ask user for the experiment type if unsuccessful
my $exp_type;
foreach (@old_soft) {
	if (/^!Series_type/) {
		my @type_line = split(/=/, $_);
		$exp_type = $type_line[1];
		$exp_type =~ s/^\s+//;
		chomp $exp_type;
		last;
	}
}
print "Experiment type: ";
if ($exp_type) {
	print $exp_type . "\n";
} else {
	$exp_type = <STDIN>;
	$exp_type =~ s/^\s+//;
	chomp $exp_type;
}
if ($exp_type =~ m/(?:chip)?(?:-)?seq/i) {
	$exp_type = "seq";
} elsif ($exp_type =~ m/(?:chip)?(?:-)?chip/i) {
	$exp_type = "chip";
} else {
	die "Unrecognized experiment type, died";
}

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

# Determine what CEL/FASTQ/pair raw data files exist in this directory and store the filenames in an array
# Note that some FASTQ files end in "txt.gz" instead of the usual FASTQ file endings
# These misnamed FASTQ files should be renamed
my @raw_files;
my $dir = getcwd;
opendir(DIR, $dir) or die $!;
my @dir_files = readdir DIR;
closedir(DIR);

my $file_counter = 1;
if ($exp_type eq "seq") {
	foreach (@dir_files) {
		push @raw_files, $_ if m/\.fastq/i;
		push @raw_files, $_ if m/\.fq\.gz/i;
	}
} elsif ($exp_type eq "chip") {
	foreach (@dir_files) {
		push @raw_files, $_ if m/CEL/;
		push @raw_files, $_ if m/pair/;
	}
}

# Populate a hash containing filenames as keys of all files that could possibly be supplementary raw data files...
# ...in the current directory as well as the supplementary files in the original SOFT
my $sample_index = 1;
my %supp_files;
foreach (@dir_files) {
	$supp_files{$_} = 1 if (m/\.wig$/i || m/\.GFF(?:3)?$/i);
}
foreach (@old_soft) {
	if (/^!Sample_supplementary_file(?:_)?\d* =/) {
		my @supp_line = split(/=/, $_);
		my $supp_file = $supp_line[1];
		$supp_file =~ s/^\s+//;
		chomp $supp_file;
		# BAM, SAM, and BAM index files are not uploaded to GEO, so ignore them
		if ($supp_file =~ m/\.sam$/i or $supp_file =~ m/\.bam$/i or $supp_file =~ m/\.bai$/i ) {
			next;
		}
		# Due to the way Perl hashes work, duplicate entries for repeated files are avoided
		$supp_files{$supp_file} = 1;
	}
}
# The hash is only necessary in order to avoid duplicate entries
# Convert the hash with filenames as keys into an array of filenames
my @supp_files = sort {$a cmp $b} keys %supp_files;

my %sample_filelist;
# %sample_filelist will be a hash of hashes of arrays containing data about which...
# ...raw data and supplementary files belong to which sample
# Currently empty; will be generated while iterating over the !Series_sample_id lines...
# ...at the beginning of the SOFT file
# The plan for %sample_filelist:
# %sample_filelist = (
# 	1 => {
# 		raw	=> [array of filenames of all raw data files associated with sample 1]
# 		supp	=> [array of filenames of all supplementary files associated with sample 1]
# 		type	=> type of sample 1 (either input or ChIP)
# 	},
# 	2 => {
# 		raw	=> [array of filenames of all raw data files associated with sample 2]
# 		supp	=> [array of filenames of all supplementary files associated with sample 2]
# 		type	=> type of sample 2 (either input or ChIP)
# 	},
# 	etc.
# );

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
my $sample_src_name_input_rep_counter  = 1; # Counts which Input replicate we're currently on in the !Sample_source_name(_ch1) fields.
my $sample_src_name_chip_rep_counter   = 1; # Counts which ChIP  replicate we're currently on in the !Sample_source_name(_ch1) fields.

my $new_sample = 0;

my $old_soft_counter = 0;

# Finally create the new SOFT file.
while (<FHIN>) {
	if (/^!Series_sample_id/) {
		my $expt_type_suffix = "";
		my $expt_rep_suffix  = "";

		# To determine whether the current sample is Input or ChIP, attempt to look at original SOFT file 
		# If unsuccessful, then ask for user input
		# It also determines which replicate we're currently working with, which is kept track of using two counters.
		# This same code is used to determine type and rep suffixes for other fields.
		my @sample_name = split(/=/, $_);
		my $sname = $sample_name[1];
		$sname =~ s/^\s+//;
		chomp $sname;
		print "\n---Information about Series Sample ID $series_sample_id_counter---\n";
		print "Original name: $sname\n";
		# Uses the @old_soft array generated earlier in order to try to automatically determine whether the current sample is Input or ChIP
		my $sample_lines_passed = 0;
		my $old_soft_index = $old_soft_counter + 1;
		while ($sample_lines_passed <= $series_sample_id_counter && $old_soft_index < $#old_soft) {
			if ($sample_lines_passed == $series_sample_id_counter && $old_soft[$old_soft_index] =~ m/^!Sample_description/) {
				if ($old_soft[$old_soft_index] =~ m/ChIP DNA/) {
					$expt_type_suffix = "ChIP";
					last;
				} elsif ($old_soft[$old_soft_index] =~ m/input DNA/ or $old_soft[$old_soft_index] =~ m/negative control for ChIP/) {
					$expt_type_suffix = "Input";
					last;
				}
			}
			if ($old_soft[$old_soft_index] =~ /^\^Sample/) {
				$sample_lines_passed++;
			}
			$old_soft_index++;
		}
		unless ($expt_type_suffix) {
			print "Enter the sample type (input or ChIP): ";
			$expt_type_suffix = <STDIN>;
			$expt_type_suffix =~ s/^\s+//;
			chomp $expt_type_suffix;
		}
		if ($expt_type_suffix =~ m/^input$/i) {
			$expt_type_suffix = "Input";
			$sample_filelist{$series_sample_id_counter}{type} = "Input";
			$expt_rep_suffix = "Rep" . $series_sample_id_input_rep_counter++;
		} elsif ($expt_type_suffix =~ m/^chip$/i) {
			$expt_type_suffix = "ChIP";
			$sample_filelist{$series_sample_id_counter}{type} = "ChIP";
			$expt_rep_suffix = "Rep" . $series_sample_id_chip_rep_counter++;
		} else {
			print "Unrecognized sample type; died";
		}
		print "Sample type: $expt_type_suffix\n";
		my $series_sample_id_suffix;
		if ($exp_type eq "chip") {
			$series_sample_id_suffix = "extraction" . $series_sample_id_counter . "_array" . $series_sample_id_counter;
		} elsif ($exp_type eq "seq") {
			$series_sample_id_suffix = "extraction" . $series_sample_id_counter . "_seq" . $series_sample_id_counter;
		}
		print "New name: GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $series_sample_id_suffix . "\n";
		print FHOUT "!Series_sample_id = GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $series_sample_id_suffix . "\n";

		# Get list of all raw data files belonging to the current sample via user input
		# Store the list in %sample_filelist
		print "List of all raw data file(s):\n";
		foreach (1..scalar(@raw_files)) {
			print "[$_]\t$raw_files[($_ - 1)]\n";
		}
		print "Enter space-separated raw file ID numbers for this sample: ";
		my $rawfiles = <STDIN>;
		$rawfiles =~ s/^\s+//;
		chomp $rawfiles;
		my @rawfilelist = split(/\s+/, $rawfiles);
		foreach (@rawfilelist) {
			push @{ $sample_filelist{$series_sample_id_counter}{raw} }, $raw_files[($_ - 1)];
		}

		# Get list of all supplementary data files belonging to the current sample via user input
		# Store the list in %sample_filelist
		print "List of all supplementary data file(s):\n";
		foreach (1..scalar(@supp_files)) {
			print "[$_]\t$supp_files[($_ - 1)]\n";
		}
		print "Enter space-separated supplementary file ID numbers for this sample: ";
		my $supfiles = <STDIN>;
		$supfiles =~ s/^\s+//;
		chomp $supfiles;
		my @supfilenums = split(/\s+/, $supfiles);
		my @sortednums = sort {$a <=> $b} @supfilenums;
		foreach (@sortednums) {
			push @{ $sample_filelist{$series_sample_id_counter}{supp} }, $supp_files[($_ - 1)];
		}

		$series_sample_id_counter++;
	} elsif (/^\^Sample/) {
		# Generate and print the new ^Sample lines based on previous user input
		my $expt_type_suffix = "";
		my $expt_rep_suffix  = "";

		print "\n---Information about Sample ID $sample_counter---\n";

		if (!exists($sample_filelist{$sample_counter}{type})) {
			die "Type of sample $sample_counter not defined; died";
		} elsif ($sample_filelist{$sample_counter}{type} eq "Input") {
			$expt_type_suffix = "Input";
			$expt_rep_suffix = "Rep" . $sample_input_rep_counter++;
		} elsif ($sample_filelist{$sample_counter}{type} eq "ChIP") {
			$expt_type_suffix = "ChIP";
			$expt_rep_suffix = "Rep" . $sample_chip_rep_counter++;
		}

		my $sample_suffix;
		if ($exp_type eq "chip") {
			$sample_suffix = "extraction" . $sample_counter . "_array" . $sample_counter;
		} elsif ($exp_type eq "seq") {
			$sample_suffix = "extraction" . $sample_counter . "_seq" . $sample_counter;
		}

		print "Sample name: GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $sample_suffix . "\n";
		print FHOUT "^Sample = GSM for " . $nameu . "_" . $expt_type_suffix . "_" . $expt_rep_suffix . " " . $sample_suffix . "\n";

		$new_sample = 1; # We've entered a new ^Sample, this is to alert the block that deals with supplementary files.
		$sample_counter++;
	} elsif (/^!Sample_title/) {
		# Generate and print the new !Sample_title lines based on previous user input
		my $expt_type_suffix = "";
		my $expt_rep_suffix  = "";

		if (!exists($sample_filelist{$sample_title_counter}{type})) {
			die "Type of sample $sample_title_counter not defined; died";
		} elsif ($sample_filelist{$sample_title_counter}{type} eq "Input") {
			$expt_type_suffix = "Input";
			$expt_rep_suffix = "Rep" . $sample_title_input_rep_counter++;
		} elsif ($sample_filelist{$sample_title_counter}{type} eq "ChIP") {
			$expt_type_suffix = "ChIP";
			$expt_rep_suffix = "Rep" . $sample_title_chip_rep_counter++;
		}

		# According to GEO SOFT file specifications, the !Sample_title line must be between 1 and 120 characters
		my $sample_line_length = length($name . " " . $expt_type_suffix . " " . $expt_rep_suffix . "\n");
		if ($sample_line_length > 120) {
			die "!Sample_title line too long; must be between 1 and 120 characters but is $sample_line_length characters long.\n";
		}
		print "Sample title: " . $name . " " . $expt_type_suffix . " " . $expt_rep_suffix . "\n";
		print FHOUT "!Sample_title = " . $name . " " . $expt_type_suffix . " " . $expt_rep_suffix . "\n";
		$sample_title_counter++;
	} elsif (m/^!Sample_source_name/ || m/^!Sample_source_name_ch1/) {
		my $expt_type_suffix = "";
		my $expt_type_suffix_noexp = "";

		if (!exists($sample_filelist{$sample_source_name_counter}{type})) {
			die "Type of sample $sample_source_name_counter not defined; died";
		} elsif ($sample_filelist{$sample_source_name_counter}{type} eq "Input") {
			$expt_type_suffix = "Input";
			$expt_type_suffix_noexp = "Input Rep." . $sample_src_name_input_rep_counter++;
		} elsif ($sample_filelist{$sample_source_name_counter}{type} eq "ChIP") {
			$expt_type_suffix = "ChIP";
			$expt_type_suffix_noexp = "ChIP Rep." . $sample_src_name_chip_rep_counter++;
		}

		my $expt_number = "";
		foreach my $raw_filename (@{ $sample_filelist{$sample_sup_file_counter}{raw} }) {
			# Attempt to find experiment number based on raw data filenames
			# Assuming all CEL files are named "...xxxx.CEL.ZIP" where xxxx is the experiment number.
			# Also assuming that all FASTQ files are named "xxxx.fastq.gz" where xxxx is the experiment number
			# Assumption breaks on .pair files, but there is additional code to handle odd filenames
			# Note that there is code to handle filenames that are NOT formatted as expected
			my @file_name = split(/\./, $raw_filename);
			$expt_number = $file_name[-3];
			last if ($expt_number && $expt_number =~ m/^[0-9]+$/);
		}

		if ($exp_type eq "chip" && $expt_number && $expt_number =~ m/^[0-9]+$/) {
			print "Sample source name: " . $short_name . " " . $expt_type_suffix . " expt." . $expt_number . " channel_1" . "\n";
			print FHOUT "!Sample_source_name_ch1 = " . $short_name . " " . $expt_type_suffix . " expt." . $expt_number . " channel_1" . "\n";
		} elsif ($exp_type eq "seq" && $expt_number && $expt_number =~ m/^[0-9]+$/) {
			print "Sample source name: " . $short_name . " " . $expt_type_suffix . " expt." . $expt_number . "\n";
			print FHOUT "!Sample_source_name = " . $short_name . " " . $expt_type_suffix . " expt." . $expt_number . "\n";
		} elsif ($exp_type eq "chip") {
			# Handle ChIP-chip experiments with oddly named raw data files (i.e. no expt. number)
			print "Sample source name: " . $short_name . " " . $expt_type_suffix_noexp . " channel_1" . "\n";
			print FHOUT "!Sample_source_name_ch1 = " . $short_name . " " . $expt_type_suffix_noexp . " channel_1" . "\n";
		} elsif ($exp_type eq "seq") {
			# Handle ChIP-seq experiments with oddly named raw data files (i.e. no expt. number)
			print "Sample source name: " . $short_name . " " . $expt_type_suffix_noexp . "\n";
			print FHOUT "!Sample_source_name = " . $short_name . " " . $expt_type_suffix_noexp . "\n";
		} else {
			# Code shouldn't ever reach here; this is a "just in case" else
			die "This code should never be executed; died";
		}
		$sample_source_name_counter++;
	} elsif (/^!Sample_supplementary_file/ || /^!Sample_raw_file/) {
		if ($new_sample) {
			$new_sample = 0;
			my $supp_line_counter = 1;
			foreach (@{ $sample_filelist{$sample_sup_file_counter}{supp} }) {
				# Print out !Sample_supplementary_file lines
				my $supp_type;
				if (m/\.wig$/i) {
					$supp_type = "WIG";
				} elsif (m/\.GFF(?:3)?$/i) {
					$supp_type = "GFF3";
				} else {
					print "Supplementary file " . $_ . " is not a supplementary file format included in this type of experiment.\n";
					next;
				}
				print "Supplementary file " . $supp_line_counter . ": " . $_ . "\n";
				print FHOUT "!Sample_supplementary_file_" . $supp_line_counter . " = " . $_ . "\n";
				print FHOUT "!Sample_supplementary_file_type_" . $supp_line_counter . " = " . $supp_type . "\n";
				$supp_line_counter++;
			}
			my $raw_line_counter = 1;
			foreach (@{ $sample_filelist{$sample_sup_file_counter}{raw} }) {
				# Print out !Sample_raw_file lines (beware: .pair files do not have associated checksums!!!)
				(my $raw_filename_escaped = $_) =~ s/\(/\\\(/g;
				$raw_filename_escaped =~ s/\)/\\\)/g;
				$raw_filename_escaped =~ s/ /\\ /g;

				if ((m/\.fastq/i || m/\.fq\.gz/i) && $exp_type eq "seq") {
					my $fastq_checksum = `md5sum $raw_filename_escaped | cut -d ' ' -f1`;
					$fastq_checksum =~ s/^\s+//;
					chomp $fastq_checksum;
					print "Raw file " . $raw_line_counter . ": " . $_ . "\n";
					print "md5 checksum: " . $fastq_checksum . "\n";
					print FHOUT "!Sample_raw_file_" . $raw_line_counter . " = " . $_ . "\n";
					print FHOUT "!Sample_raw_file_type_" . $raw_line_counter . " = FASTQ\n";
					print FHOUT "!Sample_raw_file_checksum_" . $raw_line_counter . " = " . $fastq_checksum . "\n";
				} elsif (m/\.CEL/ && $exp_type eq "chip") {
					my $cel_checksum = `md5sum $raw_filename_escaped | cut -d ' ' -f1`;
					$cel_checksum =~ s/^\s+//;
					chomp $cel_checksum;
					print "Raw file " . $raw_line_counter . ": " . $_ . "\n";
					print "md5 checksum: " . $cel_checksum . "\n";
					print FHOUT "!Sample_raw_file_" . $raw_line_counter . " = " . $_ . "\n";
					print FHOUT "!Sample_raw_file_type_" . $raw_line_counter . " = CEL\n";
					print FHOUT "!Sample_raw_file_checksum_" . $raw_line_counter . " = " . $cel_checksum . "\n";
				} elsif (m/\.pair/ && $exp_type eq "chip") {
					print "Raw file " . $raw_line_counter . ": " . $_ . "\n";
					print "No md5 checksum for pair files.\n";
					print FHOUT "!Sample_raw_file_" . $raw_line_counter . " = " . $_ . "\n";
				} else {
					print "Raw file " . $_ . " is not a raw file format included in this type of experiment.\n";
					next;
				}
				$raw_line_counter++;
			}
			$sample_sup_file_counter++;
		}
	} else {
		print FHOUT $_;
	}
	$old_soft_counter++;
}

close FHIN, $fin or die $!;
close FHOUT, $fout or die $!;
close FHIN;  # Not sure why I close each handle/file twice, the example said so.
close FHOUT; # TODO: Look into why this is.
