#!/usr/bin/perl -w

use strict;
use warnings;

use Env qw(HOME);

use File::Basename;

# This script (nih_spreadsheet_stats.pl) downloads the latest version of nih_spreadsheet then parses it...
# ...and extracts summary statistics about submission counts by status and project

# It is not advised to modify the two variables below!
# Remote host where nih_spreadsheet is stored (usually modencode-www1.oicr.on.ca)
my $pipe_host 	  = "modencode-www1.oicr.on.ca";
# Location on remote host where nih_spreadsheet is stored (usually /modencode/raw/tools/reporter/output/output_nih*)
my $nih_dir 	  = "/modencode/raw/tools/reporter/output/output_nih*";

# TODO: Change the two variables below to reflect your local machine's filesystem!
# Location of ssh private key for logging onto $pipe_host
my $ssh_key 	  = "$HOME/.ssh/modencode_key";
# Directory where the most up-to-date version of nih_spreadsheet will be stored
my $local_nih_dir = "$HOME/Data";

my %nih_status;
# %nih_status will be a hash of hashes containing data taken from nih_spreadsheet
# TODO: The structure below is subject to change should any additional information be required!
# %nih_status = (
# 	1 => {
# 		proj	=> name of project for submission ID 1
# 		status	=> status of submission ID 1
# 	},
# 	2 => {
# 		proj	=> name of project for submission ID 2
# 		status	=> status of submission ID 2
# 	},
# 	...etc.
# );
my %status_groups;
# %status_groups will be a hash of hashes of arrays storing submission IDs by status, grouped by project
# %status_groups = (
# 	TOTAL  => {
# 		released => [ sorted array of all submission IDs corresponding to released submissions ],
# 		replaced => [ sorted array of all submission IDs corresponding to replaced submissions ],
# 		...etc. for each possible status
# 	},
# 	proj_1 => {
# 		released => [ sorted array of submission IDs from project proj_1 corresponding to released submissions ],
# 		replaced => [ sorted array of submission IDs from project proj_1 corresponding to replaced submissions ],
# 		...etc. for each possible status
# 	},
# 	proj_2 => {
# 		released => [ sorted array of submission IDs from project proj_2 corresponding to released submissions ],
# 		replaced => [ sorted array of submission IDs from project proj_2 corresponding to replaced submissions ],
# 		...etc. for each possible status
# 	},
# 	...etc. for each project name
# );
my %proj_tracker;
# %proj_tracker records the project identifiers and how many submissions were produced by each

my $nih_latest_path = `ssh -i $ssh_key $pipe_host ls -1t $nih_dir | head -1`;
chomp($nih_latest_path);
my $nih_latest = basename($nih_latest_path);
print "Latest nih spreadsheet: [$nih_latest]\n\n";

# Remove trailing slashes from $local_nih_dir to avoid improper concatenation of filenames
if ($local_nih_dir =~ m/\/$/) {
	chop $local_nih_dir;
}

unless (-e $local_nih_dir && -d $local_nih_dir) {
	die("$local_nih_dir is either not a directory or does not exist; died");
}

my $nih_old_path = `ls -1t $local_nih_dir | head -1`;
my $nih_old = basename($nih_old_path);
if ($nih_old ne $nih_latest && $nih_latest =~ /txt$/) {
	`scp -i $ssh_key $pipe_host\:$nih_latest_path $local_nih_dir/$nih_latest`;
}

# Read in only the required data from nih_spreadsheet (each submission ID...
# ...and its current status) and add it to the %nih_status hash
open(my $nih_fh, "<", "$local_nih_dir/$nih_latest") or die $!;
foreach (<$nih_fh>) {
	chomp;
	my @nih_line = split(/\t/, $_);
	my $sub_id;
	if ($nih_line[17] =~ m/^(\d+)(?: (?:deprecated|superseded) by \d+)*$/) {
		$sub_id = $1;
	} else {
		next;
	}
	die("Duplicate entries for $sub_id in $nih_latest; died") if defined($nih_status{$sub_id});
	# Some useful column numbering that may or may not be used in future updates to this script:
	# $nih_line[0] is the name of the submission
	# $nih_line[1] is the project identifier
	# $nih_line[2] is the lab name
	# $nih_line[3] is the assay type (i.e. ChIP-seq, ChIP-chip, RACE, etc.)
	# $nih_line[14] is the original submission date
	# $nih_line[15] is the release date (if applicable, otherwise it is blank)
	# $nih_line[16] is the current status of the submission 
	# $nih_line[17] has the submission's ID (if it has been replaced, the ID of its replacement is also given)
	# $nih_line[18] has any GEO/SRA IDs that have been attached
	$nih_status{$sub_id}{proj} = $nih_line[1];
	$proj_tracker{$nih_line[1]}++;
	$nih_status{$sub_id}{status} = $nih_line[16];
	push(@{ $status_groups{TOTAL}{$nih_line[16]} }, $sub_id);
	push(@{ $status_groups{$nih_line[1]}{$nih_line[16]} }, $sub_id);
	# TODO: Add any additional code here for extracting data from each line
}


# Gather and print out statistics about the data read from nih_spreadsheet
print "----------\nTotal\n----------\n";
# Do a nice, formatted print of the "released" submission count
printf "%4s submission%s %s released\n", scalar @{ $status_groups{TOTAL}{released} },
	scalar @{ $status_groups{TOTAL}{released} } == 1 ? " " : "s",
	scalar @{ $status_groups{TOTAL}{released} } == 1 ? "is " : "are";
# Do a nice, formatted print of the other submission status counts
foreach my $stat (sort keys %{ $status_groups{TOTAL} }) {
	next if ($stat eq 'released');
	printf "%4s submission%s %s %s\n", scalar @{ $status_groups{TOTAL}{$stat} },
		scalar @{ $status_groups{TOTAL}{$stat} } == 1 ? " " : "s",
		scalar @{ $status_groups{TOTAL}{$stat} } == 1 ? "is " : "are",
		$stat;
}
my $total_subs = keys(%nih_status);
print "----\n";
printf "%4s submission%s total\n", $total_subs, 
	$total_subs == 1 ? "" : "s";
# TODO: Add any additional code here for printing statistics about all submissions

# Print submission counts by project name
print "\nView breakdown of submission counts by lab? (yes/[no]) ";
my $proceed = <STDIN>;
if ($proceed && $proceed =~ m/^ye?s?/i) {
	foreach my $proj_name (sort {$a cmp $b} keys %proj_tracker) {
		print "\n----------\n$proj_name\n----------\n";
		# Do a nice, formatted print of the "released" submission count for each project name
		# Only if there are released submissions for the project in question
		if ($status_groups{$proj_name}{released}) {
			printf "%4s %s submission%s %s released\n", scalar @{ $status_groups{$proj_name}{released} }, $proj_name,
				scalar @{ $status_groups{$proj_name}{released} } == 1 ? " " : "s",
				scalar @{ $status_groups{$proj_name}{released} } == 1 ? "is " : "are";
		}
		# Do a nice, formatted print of the other submission status counts for each project name
		foreach my $stat (sort keys %{ $status_groups{$proj_name} }) {
			next if ($stat eq 'released');
			printf "%4s %s submission%s %s %s\n", scalar @{ $status_groups{$proj_name}{$stat} }, $proj_name, 
				scalar @{ $status_groups{$proj_name}{$stat} } == 1 ? " " : "s",
				scalar @{ $status_groups{$proj_name}{$stat} } == 1 ? "is " : "are",
				$stat;
		}
		print "----\n";
		printf "%4s %s submission%s total\n", $proj_tracker{$proj_name}, $proj_name, 
			$proj_tracker{$proj_name} == 1 ? "" : "s";
	# TODO: Add any additional code here for printing statistics about each project's submissions
	}
}

# Print submission lists by status
print "\nPrint active submission information? (yes/[no]) ";
$proceed = <STDIN>;
if ($proceed && $proceed =~ m/^ye?s?/i) {
	print "NOTE: Active submission information output is likely to be very long.\n";
	print "      It is recommended that you enter a destination file for the subsequent output.\n";
	print "Name of existing output file (leave blank to print to STDOUT): ";
	my $file_string = <STDIN>;
	chomp $file_string;
	# Redirect STDOUT to the specified file iff a file to redirect output to has been specified
	unless (!$file_string || $file_string =~ m/^\s*$/) {
		my @file_list = glob($file_string);
		die "Multiple possible files exist for \"$file_string\"; died" if (scalar @file_list > 1);
		die "No existing file matching $file_string; died" if (scalar @file_list < 1);
		my $filename = $file_list[0];
		die "File $filename is not a plain file; died" unless (-f $filename);
		print "Printing active submission information to $filename\n\n";
		open(OLDOUT, ">&STDOUT") or die "Can't duplicate STDOUT: $!\n";
		open(STDOUT, '>', $filename) or die "Can't redirect STDOUT to file: $!\n";
	} else {
		print "\n";
	}
	# Gather info about which subs are released and which are pending
	my %released_subs;
	my %pending_subs;
	foreach my $access_id (keys %nih_status) {
		# Submissions with a status of "released" are, obviously, released
		if ($nih_status{$access_id}{status} eq "released") {
			$released_subs{$access_id} = $nih_status{$access_id}{proj};
		# Submissions that are neither "released", "replaced", or have a project name of "Stein" or "Lewis"...
		# ...are probably pending
		# "Stein" or "Lewis" project names indicate dead submissions
		} elsif ($nih_status{$access_id}{status} ne "replaced" && 
			 $nih_status{$access_id}{proj}   ne "Stein" && 
		 	 $nih_status{$access_id}{proj}   ne "Lewis") {
			$pending_subs{$access_id} = $nih_status{$access_id}{proj};
		}
	}
	# Print info about released and pending submissions
	print "----------\nReleased submissions\n----------\n";
	foreach my $rel_id (sort {$a <=> $b} keys %released_subs) {
		print "$rel_id\t$released_subs{$rel_id}\n";
	}
	print "\n----------\nPending submissions\n----------\n";
	foreach my $pend_id (sort {$a <=> $b} keys %pending_subs) {
		print "$pend_id\t$pending_subs{$pend_id}\t$nih_status{$pend_id}{status}\n";
	}
	# Restore the original STDOUT and clean up unneeded filehandles iff a file to redirect output to has been specified
	unless (!$file_string || $file_string =~ m/^\s*$/) {
		close(STDOUT) or die "Can't close redirected STDOUT: $!\n";
		open(STDOUT, ">&OLDOUT") or die "Can't restore original STDOUT: $!\n";
		close(OLDOUT) or die "Can't close copy of STDOUT: $!\n";
	}
}
