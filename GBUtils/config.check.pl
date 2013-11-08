#!/usr/bin/perl -w

=head2 SYNOPSIS

 check.config.pl is a script for validation of newly created config files
 Simple checks:
  1. Check if we can load a config snippet using GBrowse module(s)
  2. Check if we have equal number of sub ids and track ids
  3. Check for uniqness of track ids
 Not so simple checks:
  1. Check if the features are actually present in the database and there are > 0 features
  2. Check if the key in 'select' matches the name in the database
  3. Check if we have any retracted/deprecated tracks in our configs (using nih_spreadsheet)

=head2 USAGE
 
 check.config.pl --confdir=my_configs

 Simply supply a dir name with .conf files

 Report Examples:
  
 check.config.pl --confdir=configs

 ERROR: config file blah.conf couldn't be loaded - syntax problems
 ERROR: for [SNIPPET_###] the number of data sources is larger than number of track sources
 ERROR: [SNIPPET_###] and [SNIPPET_####] use the same tracks 12345 and 67890, please check
 ERROR: feature VISTA:1234 is in the [1234.conf] but is absent from database [karpen]
 ERROR: submission [1234] uses description [H3K27Ac_E0_4h] but in the database it has [H4K36Me3_E6_12h]
 ERROR: submissions [1234,5678,9843] have tracks configured, but the latest nih_spreadsheet indicates that they are retracted

=cut

use strict;
use warnings;
use Env qw(HOME);
use lib '$HOME/lib';
use Getopt::Long;

use DBI;
use IO::File;
use File::Basename;
use Bio::Graphics::FeatureFile;
use Data::Dumper;
use Bio::DB::SeqFeature::Store;
use constant DEBUG=>1;

my $confdir;
my $pipe_host 	  = "modencode-www1.oicr.on.ca";
my $nih_dir 	  = "/modencode/raw/tools/reporter/output/output_nih*";
my $local_nih_dir = "./nih_spreadsheet";
my $ssh_key 	  = "$HOME/.ssh/clinic_key"; # TODO update this after installation
my $GB_conf 	  = "$HOME/public_html/conf/GBrowse.conf"; # Location of main conf file (GBrowse.conf or equivalent)
my $result 	  = GetOptions ('confdir=s'    => \$confdir); # directory with .conf files

$confdir ||=".";
# Remove trailing slashes from $confdir to avoid improper concatenation of filenames
if ($confdir =~ m/\/$/) {
	chop $confdir;
}
opendir(DIR,"$confdir") or die "Couldnt read from directory [$confdir]\n";

my @files = grep {/\.conf$/} readdir(DIR);
closedir DIR;

if (@files == 0) {die "We have 0 .conf files in $confdir, check the directory and perldoc for this script\n";}


# =====================================================
# Process config files
# =====================================================

# Attempt to recursively parse conf files in order to extract all database names
# These database names will be used to check if the entry is present, if the database can be accessed
# TODO: There should be a better way to do this, as bad database names will not be caught
my %database_list;
my $main_conf_dir = dirname($GB_conf);
my $main_conf = eval { Bio::Graphics::FeatureFile->new(-file => $GB_conf); };
if (!$main_conf || $@) {
	warn("ERROR: main config file $GB_conf couldn't be loaded - syntax problems\n");
	die;
}

my @conf_files = keys %{$main_conf->{'config'}};

foreach my $file (@conf_files) {
	next if (!exists($main_conf->{'config'}->{$file}->{'path'}));
	my $cconf = eval { Bio::Graphics::FeatureFile->new(-file => join("/",($main_conf_dir,$main_conf->{'config'}->{$file}->{'path'}))); };
	if (!$cconf || $@) {
		warn("ERROR: config file $main_conf->{'config'}->{$file}->{'path'} couldn't be loaded - syntax problems\n");
		die if ($@);
		next;
	}
	foreach my $db_string (keys %{$cconf->{'config'}}) {
		next unless $db_string =~ m/^(.*):database$/;
		my $database = $1;
		unless (exists($database_list{$database})) {
			$database_list{$database} = 1;
		}
	}
}

# This hash will store modENCODE submission IDs as the keys and each ID's status as the values
# Currently empty, but will be populated by &load_nih_spreadsheet()
my %id_status;

# Check if the copy of nih_spreadsheet on the local machine in $local_nih_dir...
# ...has the same name as the latest one in $pipe_host:$nih_dir
# If so, do nothing
# If not, scp the latest version of nih_spreadsheet to $local_nih_dir on the local machine
# After getting the latest version of nih_spreadsheet, populate the %id_status hash
&load_nih_spreadsheet();

foreach my $file(@files) {

	print STDERR "\n\n----------\n";
	print STDERR "Checking conf file $confdir/$file\n";

	my $conf = eval { Bio::Graphics::FeatureFile->new(-file => join("/",($confdir,$file))); };
	if (!$conf || $@) {
		# simple check #1
		warn("ERROR: config file $confdir/$file couldn't be loaded - syntax problems\n");
		# FIXME: It would be better if the script skipped to checking the next file instead of dying when...
		# 	 ...Bio::Graphics::FeatureFile->new() throws an exception, but for some unknown reason...
		# 	 ...Bio::Graphics::FeatureFile->new() refuses to read in any actual data in loop iterations...
		# 	 ...after an exception is caught
		warn("ERROR: Bio::Graphics::FeatureFile->new() threw an exception; exiting script\n") if ($@);
		die if ($@);
		next;
	}

	# Extract all stanza snippets
	my @snippets = grep{!/\:/} @{$conf->{types}}; 
	unless (@snippets) {
		warn("ERROR: Could not parse config file $confdir/$file\n");
		next;
	}

	# This hash will have previously encountered track IDs as keys and...
	# ...a reference to an array of the names of the stanzas they occur in as values
	# This is declared in this scope because we only want to retain track ID information...
	# ...about the file currently being examined
	# TODO: Move this to outermost scope in order to retain info about track IDs examined...
	# 	...in all previous conf files
	my %tracks_seen;

	foreach my $stanza(@snippets) {
		print STDERR "----------\n";
		print STDERR "TYPE: [$stanza]\n";
		my $features = $conf->{config}->{$stanza};

		# Skip placeholder stanzas (those with a name starting with '=')
		if ($stanza =~ m/^=/) {
			print STDERR "[$stanza] appears to be a placeholder; skipping all checks\n";
			next;
		}

		# Check to make sure all required data is present
		unless (exists($features->{feature}) && exists($features->{'data source'}) && exists($features->{'track source'})) {
			warn("ERROR: [$stanza] is missing critical information; skipping all subsequent checks\n");
			next;
		}

		my @features = split(" ",$features->{feature});
		# Do something with features
		# Check to ensure there are more than 0 features
		if (scalar(@features) == 0) {
			warn("ERROR: [$stanza] has 0 features\n");
		}
		# Perform a brief sanity check on each feature
		foreach (@features) {
			#if (!m/[a-zA-Z_]+:(?:modENCODE_|modencode_)?[0-9]+(?:r)?(?:_details)?/) {
			if (!m/^\w+(?::\w+)?$/) {
				warn("WARNING: Feature [$_] looks unusual\n");
			}
		}
		# print STDERR Dumper(@features);

		my @ds = split(" ",$features->{'data source'});
		print STDERR "[$stanza] has ".scalar(@ds)." data source(s)\n";
		# Check if each data source ID is numeric
		foreach (@ds) {
			warn("ERROR: Data source ID [$_] is not numeric\n") if (m/\D/);
		}
		# Do something with submission ids

		# Simple checks 2 and 3
		my @ts = split(" ",$features->{'track source'});
		# Do something with track ids
		# Check for equal number of submission and track IDs
		&check_sources($features, $stanza);
		# Check if each track source ID is numeric
		foreach (@ts) {
			warn("ERROR: Track source ID [$_] is not numeric\n") if (m/\D/);
		}
		# Check for presence of each track ID in a hash of previously encountered track IDs
		&check_uniqness($features, $stanza, \%tracks_seen);

		# Not-so-simple checks 1 and 2
		# We need this for checking what's in mysql
		my $db = $features->{'database'};
		if (exists($features->{'database'}) && $db =~ m/^[\w]+$/) {
			# Not-so-simple check 1
			my $return = &confirm_present($db, \@features, "$confdir/$file");
			# Not-so-simple check 2
			# Note that not all stanza snippets have a select field
			# Only compare select keys against database entries if there is a select field and a database field to begin with!
			# Note that the use of the "select" field is actually deprecated; "subtrack select", "subtrack table", and "subtrack labels"...
			# ...fields should be used instead
			if ($return) {
				warn("ERROR: Could not connect to database [$db]; skipping remaining database-related checks\n");
			} elsif (exists($features->{'subtrack select'}) && exists($features->{'subtrack table'}) && exists($features->{'subtrack select labels'})) {
				&subtrack_matches($features);
			} elsif (exists($features->{'subtrack select'}) || exists($features->{'subtrack table'}) || exists($features->{'subtrack select labels'})) {
				warn("ERROR: Subtrack options are incorrectly configured; skipping subtrack checks\n");
			} elsif (exists($features->{'select'})) {
				warn("WARNING: The 'select' subtrack syntax is deprecated; instead use 'subtrack select', 'subtrack table', and 'subtrack select labels'\n");
				&select_matches($features);
			}
		} elsif (exists($features->{'database'}) && exists($database_list{$db})) {
			print STDERR "NOTICE: This script is unable to connect to database [$db]; skipping database-related checks\n";
		} elsif (exists($features->{'database'})) {
			warn("ERROR: Database name [$db] is not recognized; skipping database-related checks\n");
		} else {
			warn("ERROR: Database not specified for [$stanza]; skipping database-related checks\n");
		}

		# Not-so-simple check 3
		&check_nih_spreadsheet(\%id_status, \@ds);
		
	}

	# Print out data about any track IDs that have been used in multiple stanza snippets
	foreach (sort {$a cmp $b} keys %tracks_seen) {
		my @stanzas = @{ $tracks_seen{$_} };
		if (scalar(@stanzas) > 1) {
			print STDERR "----------\n";
			warn("ERROR: Track ID [$_] is used by [" . join("], [", map {$_} @stanzas) . "]\n");
		}
	}
	#print STDERR Dumper($conf);
}

print STDERR "\n";

# ================================================
# API for checking properties of Bio::Graphics::FeatureFile objects derived from GBrowse conf files
# ================================================


# Check that number of entries in 'data source' and 'track source' is the same
# Takes in as input a reference to a hash containing the details of a single config entry...
# ...as well as a string corresponding to the name of the current stanza being checked
sub check_sources {
	my ($features, $stanza) = @_;
	die "Bad input to &check_sources; died" unless (ref($features) eq 'HASH');
	my @ts = split(" ",$features->{'track source'});
	my @ds = split(" ",$features->{'data source'});
	my $dnum = scalar(@ds);
	my $tnum = scalar(@ts);
	if ($dnum != $tnum) {
		warn("ERROR: [$stanza] has $dnum data source(s) but $tnum track source(s)\n");
	} else {
		print STDERR "[$stanza] has $tnum track source(s)\n";
	}
}

# Check that entries in 'track source' are unique
# Takes in as input a reference to a hash containing the details of a single config entry, ...
# ...a string corresponding to the name of the current stanza being checked, and a reference...
# ...to a hash which will contain info about which stanzas have which track IDs
# This hash will be modified within the subroutine because a reference to the actual hash is being passed in
sub check_uniqness {
	my ($features, $stanza, $tracks_ref) = @_;
	die "Bad input to &check_uniqness; died" unless (ref($features) eq 'HASH' && ref($tracks_ref) eq 'HASH');
	my @ts = split(" ",$features->{'track source'});
	foreach (@ts) {
		if (exists($tracks_ref->{$_})) {
			warn("ERROR: Track source ID [$_] in [$stanza] is also used elsewhere in the same file\n");
			push(@{ $tracks_ref->{$_} }, $stanza);
		} else {
			# Initialize the new hash element as a single-element array
			$tracks_ref->{$_} = [ $stanza ];
		}
	}
}

# Check that a given feature ID has a corresponding database entry of the same name
# Takes in as input a database name, a reference to an array holding...
# ...one or more feature entries, and the name of the conf file being looked at
sub confirm_present {
	my ($db_name, $features_ref, $conf_filename) = @_;
	die "Bad input to &confirm_present; died" unless (ref($features_ref) eq 'ARRAY');
	my @features = @{ $features_ref };
	my $db = DbConnect->new($db_name);
	foreach (@features) {
		# For each feature in the array, attempt to find any database entry IDs with the same name (i.e. 'VISTA:18304')
		my $dbresult_ref = $db->get_data("SELECT * FROM typelist WHERE tag = '$_';");
		return 1 unless (ref($dbresult_ref) eq 'ARRAY');
		my @dbresult = @{ $dbresult_ref };
		warn("ERROR: Feature [$_] is in $conf_filename but is absent from database [$db_name]\n") if (scalar(@dbresult) == 0);
	}
	return 0;
}


# Check that each the name of each subtrack matches the name stored in the database, as well as checking whether...
# ...each subtrack has a unique entry in both 'subtrack table' and 'subtrack select fields'
# Unlike &select_matches below, this is made to work on config entries using the newer subtrack syntax
# See http://gmod.org/wiki/GBrowse_2.0_Configuration_HOWTO#Track_Table_Options for details on subtrack configuration
# Takes in as input a reference to a hash containing the details of a single config entry
sub subtrack_matches {
	my $features = shift;
	die "Bad input to &subtrack_matches; died" unless (ref($features) eq 'HASH');
	my $db_name = $features->{'database'};
	my @ts = split(" ",$features->{'track source'});
	my @ds = split(" ",$features->{'data source'});
	# Get the data for each subtrack in the 'subtrack table' field and store it the %subtrack_ids hash
	# Each subtrack's internal name is used as a key and the corresponding data source ID as the value
	# Warnings are printed for any entries with the same internal name
	my %subtrack_ids;
	my @subtrack_table_lines = split(/;/, $features->{'subtrack table'});
	foreach (@subtrack_table_lines) {
		if (m/([-\.\w\(\)]+)\s*=\s*(\d+)/) {
			my $identifier = $1;
			my $sub_id = $2;
			if (exists($subtrack_ids{$identifier})) {
				warn("ERROR: Duplicate entries for [$identifier] are present in the 'subtrack table' field\n");
				next;
			} else {
				$subtrack_ids{$identifier} = $sub_id;
			}
		}
	}
	# Get the data for each subtrack in the 'subtrack select labels' field and store it the %subtrack_labels hash
	# Each subtrack's internal name is used as a key and the corresponding human-readable dialog box name as the value
	# Warnings are printed for any entries with the same internal name
	my %subtrack_labels;
	my @subtrack_label_lines = split(/;/, $features->{'subtrack select labels'});
	foreach (@subtrack_label_lines) {
		if (m/([-\.\w\(\)]+)\s+"(.+)"/) {
			my $identifier = $1;
			my $label = $2;
			if (exists($subtrack_labels{$identifier})) {
				warn("ERROR: Duplicate entries for [$identifier] are present in the 'subtrack select labels' field\n");
				next;
			} else {
				$subtrack_labels{$identifier} = $label;
			}
		}
	}
	# Check whether each internal subtrack name has an entry in the 'subtrack table' and the 'subtrack select labels' field
	# The %subtrack_counter hash has each subtrack's internal name as a key and a value of 1 if it is only in 'subtrack table',...
	# ...a value of 2 if it is only in 'subtrack select labels', and a value of 3 if it is in both
	# A value of 1 or 2 indicates an error
	my %subtrack_counter;
	foreach (keys %subtrack_ids) {
		$subtrack_counter{$_}++;
	}
	foreach (keys %subtrack_labels) {
		$subtrack_counter{$_} = $subtrack_counter{$_} + 2;
	}
	my $db = Bio::DB::SeqFeature::Store->new(-adaptor=>'DBI::mysql', -dsn=>$db_name, -user=>'viewer', -pass=>'viewer');
	foreach my $name (keys %subtrack_counter) {
		if ($subtrack_counter{$name} == 1) {
			warn("ERROR: An entry for [$name] is present in 'subtrack table' but not in 'subtrack select labels'\n");
			next;
		} elsif ($subtrack_counter{$name} == 2) {
			warn("ERROR: An entry for [$name] is present in 'subtrack select labels' but not in 'subtrack table'\n");
			next;
		}
		# @track_ids will hold the track ID numbers associated with the current data source ID
		my @track_ids;
		# FIXME: This assumes that the data source and track source IDs in the same sequential position are associated
		# 	 This may not necessarily be the case, but there's no easy way to reliably check
		foreach (0..$#ds) {
			if ($ds[$_] == $subtrack_ids{$name}) {
				push(@track_ids, $ts[$_]);
			}
		}
		if (scalar(@track_ids) == 0) {
			warn("ERROR: Track source ID [$subtrack_ids{$name}] from 'subtrack table' not found in 'track source' field\n");
			next;
		}
		# Uses Bio::DB::SeqFeature::Store to get a list of "feature" objects stored in the database
		# Each of those feature objects has a track ID corresponding to the submission ID in the current select line
		# Check if the name of each "feature" object matches the name given in the select line
		my @feature_list = $db->features(-source=>\@track_ids);
		warn("WARNING: No matches in database [$db_name]; submission $subtrack_ids{$name} with name [$name] may need manual checking\n") if (scalar(@feature_list) == 0);
		my %name_tracker;
		foreach (@feature_list) {
			if (${$_}{name} ne $name && !exists($name_tracker{${$_}{name}})) {
				warn("ERROR: Submission $subtrack_ids{$name} is named [$name] in the conf file but is named [${$_}{name}] in database [$db_name]\n");
				$name_tracker{${$_}{name}} = 1;
			}
		}

	}
}

# Check that each the name of each entry in a select field matches the name stored in the database
# Unlike &subtrack_matches above, this is made to work on config entries using the older (deprecated) subtrack syntax
# See http://gmod.org/wiki/GBrowse_2.0_Configuration_HOWTO#Track_Table_Options for details on subtrack configuration
# Takes in as input a reference to a hash containing the details of a single config entry
sub select_matches {
	my $features = shift;
	die "Bad input to &select_matches; died" unless (ref($features) eq 'HASH');
	my $db_name = $features->{'database'};
	my @ts = split(" ",$features->{'track source'});
	my @ds = split(" ",$features->{'data source'});
	my @select_entries = split(/;/, $features->{'select'});
	my $db = Bio::DB::SeqFeature::Store->new(-adaptor=>'DBI::mysql', -dsn=>$db_name, -user=>'viewer', -pass=>'viewer');
	foreach (@select_entries) {
		if (m/([-\.\w]+) "(.+)" = (\d+)/) {
			my $description = $1;
			my $title = $2;
			my $sub_id = $3;
			# @track_ids will hold the track ID numbers associated with the current data source ID
			my @track_ids;
			# FIXME: This assumes that the data source and track source IDs in the same sequential position are associated
			# 	 This may not necessarily be the case, but there's no easy way to reliably check
			foreach (0..$#ds) {
				if ($ds[$_] == $sub_id) {
					push(@track_ids, $ts[$_]);
				}
			}
			if (scalar(@track_ids) == 0) {
				warn("ERROR: Track source ID [$sub_id] from 'select' field not found in 'track source' field\n");
				next;
			}
			# Uses Bio::DB::SeqFeature::Store to get a list of "feature" objects stored in the database
			# Each of those feature objects has a track ID corresponding to the submission ID in the current select line
			# Check if the name of each "feature" object matches the name given in the select line
			my @feature_list = $db->features(-source=>\@track_ids);
			warn("WARNING: No matches in database [$db_name]; submission $sub_id with name [$description] may need manual checking\n") if (scalar(@feature_list) == 0);
			my %name_tracker;
			foreach (@feature_list) {
				if (${$_}{name} ne $description && !exists($name_tracker{${$_}{name}})) {
					warn("ERROR: Submission $sub_id is named [$description] in the conf file but is named [${$_}{name}] in database [$db_name]\n");
					$name_tracker{${$_}{name}} = 1;
				}
			}
		}
	}
}

# Checks the status of modENCODE submission IDs based on the data in %id_status
# Takes as input a reference to a hash holding modENCODE submission status information...
# ...with submission IDs as keys and the corresponding status as the value, as well as...
# ...a reference to an array of modENCODE submission numbers (duplicates allowed)
sub check_nih_spreadsheet {
	my ($statref, $dsref) = @_;
	die "Bad input to &check_nih_spreadsheet; died" unless (ref($statref) eq 'HASH' && ref($dsref) eq 'ARRAY');
	my %id_status = %{ $statref };
	my @ds = @{ $dsref };
	# Only check the first of any duplicated entries from @ds
	# %unique_ds tracks with accession numbers have been previously checked
	my %unique_ds;
	foreach (sort {$a <=> $b} @ds) {
		unless ($unique_ds{$_}) {
			$unique_ds{$_} = 1;
			if (!exists($id_status{$_})) {
				warn("ERROR: modENCODE submission $_ has tracks configured but is not in the latest nih_spreadsheet!\n");
			} elsif ($id_status{$_} =~ m/released/) {
				next;
			} else {
				warn("ERROR: modENCODE submission $_ has tracks configured but the latest nih_spreadsheet indicates it is $id_status{$_}\n");
			}
		}
	}
}


# ======================================================
# NIH spreadsheet loading subroutine (call at the start)
# ======================================================

sub load_nih_spreadsheet {
	my $nih_latest_path = `ssh -i $ssh_key $pipe_host ls -1t $nih_dir | head -1`;
	chomp($nih_latest_path);
	my $nih_latest = basename($nih_latest_path);
	print STDERR "Latest nih spreadsheet: [$nih_latest]\n" if DEBUG;

	# Remove trailing slashes from $local_nih_dir to avoid improper concatenation of filenames
	if ($local_nih_dir =~ m/\\$/) {
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
	# ...and its current status) and add it to the %id_status hash
	open(my $nih_fh, "<", "$local_nih_dir/$nih_latest") or die $!;
	foreach (<$nih_fh>) {
		chomp;
		my @nih_line = split(/\t/, $_);
		my $sub_id = $1 if $nih_line[17] =~ m/^(\d+)(?: (?:deprecated|superseded) by \d+)*$/;
		if (!defined($sub_id)) {
			#print STDERR Dumper(@nih_line) if DEBUG;
			next;
		}
		$id_status{$sub_id} = $nih_line[16];
	}
}

# ======================================================
# A service package for getting data from the database
# ======================================================

# INIT is necessary to ensure all required variables have been initialized
INIT{
	package DbConnect;

	use strict;
	use warnings;
	use DBI;
	use Data::Dumper;
	use constant DEBUG=>0;

	# There doesn't seem to actually be a table in the database on modencode@oicr.on.ca named "data_clinic"
	# Not sure why this is here considering that the table to be accessed...
	# ...may be different for each new instance of DbConnect
	our $database  = "data_clinic";
	our $host      = "localhost";
	our $user      = "viewer";
	our $password  = "viewer";

	# Constructor for DbConnect objects
	# Takes in 1 string corresponding to the database to be connected to
	sub new {
		my $class = shift;
		my $db_name = shift;
		my %arg = @_;

		my $self = bless { dbstring  => join(':', 'DBI:mysql', $db_name, $host, '3306'),
				   user      => $user,
				   password  => $password}, ref $class || $class;
	}

	sub get_data {
		my $self = shift;
		my $query = shift;

		my @datarows = ();

		my $dbh = DBI->connect($self->{dbstring},$self->{user},$self->{password},{PrintError=>1, AutoCommit=>1});
		return undef if ($DBI::err);

		my($stm,$sth);

		$sth = $dbh->prepare($query);
		$sth->execute or warn "Couldn't get ids of submissions in the database";

		if ($@) {
			print STDERR "Error executing query [$query]: [$@]\n";
			$dbh->disconnect;
			return undef;
		}

		while(my @row = $sth->fetchrow) {
			next if !$row[0];

			chomp($row[0]);
			push(@datarows,join("\t",@row));
		}

		$sth->finish;
		$dbh->disconnect;
		return \@datarows;
	}

	1;
}
