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
use Bio::Graphics::FeatureFile;
use Data::Dumper;
use constant DEBUG=>1;

my $confdir;
my $pipe_host = "modencode-www1.oicr.on.ca";
my $nih_dir   = "/modencode/raw/tools/reporter/output/output_nih*";
my $local_nih_dir = "./nih_spreadsheet";
my $ssh_key   = "$HOME/.ssh/clinic_key"; # TODO update this after installation
my $result = GetOptions ('confdir=s'    => \$confdir); # directory with .conf files

$confdir ||=".";
opendir(DIR,"$confdir") or die "Couldnt read from directory [$confdir]";

my @files = grep {/\.conf$/} readdir(DIR);
closedir DIR;

if (@files == 0) {die "We have 0 .conf files, check the directory and perldoc for this script";}




# =====================================================
# Process config files
# =====================================================

foreach my $file(@files) {
 my $conf = Bio::Graphics::FeatureFile->new(-file => join("/",($confdir,$file)));
 if (!$conf) {
  # simple check #1
  warn("ERROR: config file $confdir/$file couldn't be loaded - syntax problems");
  next;
 }

 # Extract all stanza snippets
 my @snippets = grep{!/\:/} @{$conf->{types}}; 
 

 foreach my $stanza(@snippets) {
  print STDERR "TYPE: ".$stanza."\n";
  my $features = $conf->{config}->{$stanza};
 
  my @features = split(" ",$features->{feature});
  # Do something with features
  # print Dumper(@features);

  my @ds = split(" ",$features->{'data source'});
  print STDERR "Has ".scalar(@ds)." data sources\n";
  # Do something with submission ids
  #print Dumper(@ds); (check_sources)

  # Simple checks 2 and 3
  my @ts = split(" ",$features->{'track source'});
  # Do something with track ids
  #print Dumper(@ts); (check_sources, check_uniqness)

  my $db = $features->{'database'};
  # We need this for checking what's in mysql

  my $select = $features->{'select'};
  # Do something with select (select_matches)


  &check_nih_spreadsheet;
  
 
  last; 
 }

 #print STDERR Dumper($conf);
}


# ================================================
# TODO: Implement the below API
# ================================================


# Check that number of entries in 'data source' and 'track source' is the same
sub check_sources {
 warn("Not implemented yet");
}

# Check that entries in 'track source' are unique
sub check_uniqness {
 warn("Not implemented yet");
}

sub confirm_present {
 my $feature_id = shift;
 my $db = DbConnect->new;
 warn("Not implemented yet");
}

sub select_matches {
 my($track_id,$label) = @_;
 my $db = DbConnect->new;
 warn("Not implemented yet"); 
}

sub confirm_status {
 my $submission_id = shift;
 warn("Not implemented yet");
}

sub check_nih_spreadsheet {

}


# ======================================================
# NIH spreadsheet loading subroutine (call at the start)
# ======================================================

sub load_nih_spreadsheet {
 my $nih_latest = `ssh -i $ssh_key $pipe_host ls -t $nih_dir | head -1`;
 chomp($nih_latest);
 print STDERR "Latest nih spreadsheet: [$nih_latest]\n" if DEBUG;

 if (-e 'nih_latest') {
  my $nih_old = `ls -t $local_nih_dir | head -1`;
  if ($nih_old eq $nih_latest) {
    return;
  }
 }

 if ($nih_latest=~/txt$/) {
  `scp -i $ssh_key $pipe_host\:$nih_latest nih_latest`;
 }
}

# ======================================================
# A service package for getting data from the database
# ======================================================

package DbConnect;

use strict;
use warnings;
use DBI;
use Data::Dumper;
use constant DEBUG=>0;

my $database  = "data_clinic";
my $host      = "localhost";
my $user      = "viewer";
my $password  = "viewer";

sub new {
    my $class = shift;
    my %arg = @_;

    my $self = bless { dbstring  => join(':', 'DBI:mysql', $database, $host, '3306'),
                       user      => $user,
                       password  => $password}, ref $class || $class;
}

sub get_data {
   my $self = shift;
   my $query = shift;

   my @datarows = ();

   my $dbh = DBI->connect(join(':','DBI:mysql',$database,$host,'3306'),$user,$password,{RaiseError=>1, AutoCommit=>1});
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
