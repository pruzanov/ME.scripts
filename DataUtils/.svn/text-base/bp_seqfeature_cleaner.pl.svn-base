#!/usr/bin/perl 

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

# An interactive script which allows finding orphan files (wiggle files, primarily) referenced by seqfeatures and compare what's in db
# with what is present on filesystem (in case there are files not used by db they may be deleted)
# uses bp_seqfeature_delete.pl code

=head1 TITLE

 bp_seqfeature_cleaner.pl - Script for maintanance of gff3-compliant databases
 will produce a report whith information on 3 possible problems:
 1. Files are referenced in database but are absent on the filesystem
 2. Files are on the filesystem but are not referenced in database (possibly deprecated data)
 3. File collision: files are referenced by multiple databases (i.e. cases where different data files get the same name)

 needs username and password for database access 
 (by default, several parameters are assumed)
     
      -u username to use for databse connection
      -p password to use
      -d (database handler, by default dbi:mysql)
      -a adaptor (DBI::mysql)
      -b base directory in a filesystem where script will look for files of interest (it will also look one level down in subdirectories)
      -e extension of files (by default it's wi* which would capture binary wiggle files - .wib, .wigdb, .wig

=head1 SINOPSIS
    
 bp_seqfeature_load will look for files with extension of choice and check if they are properly referenced in database (that whould be gff3-compliant)
      
 usage:   bp_seqfeature_load.pl [-u username] [-p password] [-d dsn] [-b basedir] [-e extension ]

 example: bp_seqfeature_load.pl -u lorem -p ipsum -d dbi:psql -a DBI::Pg -b /data/my_stash_of_wigs -e wi* > test_report

=cut



use strict;

use Getopt::Long;
use Bio::DB::SeqFeature::Store;
use constant DEBUG => 0;

my $DSN      = 'dbi:mysql';
my $USER     = '';
my $PASS     = '';
my $ADAPTOR  = 'DBI::mysql';
my $BASE     = "/browser_data/fly/wiggle_binaries";	# This is a default path in a filesystem, should be something else for projects other than modENCODE
my $EXT      = 'wi*'; 					# By default, need to capture all binary wiggle files (wib, wigdb, wig)

GetOptions(
	   'user=s'      => \$USER,
	   'password=s'  => \$PASS,
           'adaptor=s'   => \$ADAPTOR,
           'extension=s' => \$EXT,
           'basedir=s'   => \$BASE
	   ) || die <<END;
Usage: $0 [options] 
  Options:
          -d --dsn        The database name ($DSN)
          -u --user       User to connect to database as
          -p --password   Password to use to connect to database
	  -b --basedir    Base directory to search for files of interest (This dir should contain files of interest or/and subdirs with those files)
          -e --extension  Extension (wild cards allowed) of files to search for
END
    ;


print STDERR "Have user $USER Dsn $DSN Password $PASS and Adaptor $ADAPTOR\n" if DEBUG;
$BASE =~ s!/$!!;

my @databases = `mysql -u$USER -p$PASS -N --disable-pager -e  'show databases' | sed 's!|!!g'`;
my (@dbs_touse,%wigs_db,%wigs_fs);

print STDERR "\nNote that files found only in selected (and gff3-compliant) databases will be considered not orphans\n\n";

foreach (@databases) {
 chomp;
 next if /mysql/ || /test/;
 print STDERR "Include $_ in the list of searched databases (y/n)?\n";
 my $answer = <STDIN>;
 if ($answer =~ /y/i) {push(@dbs_touse,$_);}
}

# Load the list of all files in wiggle_binary dirs for worm and fly (to make it generic we'll need to somehow
# be able to supply 2 base dirs to this script

 my @subdirs;
 print STDERR "Going to check the files in [$BASE] directory...\n\n";

 opendir(DIR,$BASE) or die "Couldn't open [$BASE] for reading\n";
 my @files = grep {!/\.{1,2}$/ } readdir(DIR);
 
 $EXT =~ /^\./ ? $EXT =~s!^\.!\\.! : $EXT;
 $EXT =~s/\*/\.\*/;

 my @subdirs = grep {!/$EXT$/} @files;
 close(DIR);

 map{$wigs_fs{join("/",($BASE,$_))}++ if /$EXT$/} @files;

 foreach my $d (@subdirs) {
  my $dir = join("/",($BASE,$d));
  print STDERR "Checking in $BASE/$d...\n";
  opendir(DIR,$dir) or print STDERR "Couldn't open [$dir] for reading\n" && next;
  @files = grep {/$EXT$/} readdir(DIR);

  map{$_=~ /$dir/ ? $wigs_fs{$_}++ :  $wigs_fs{join("/",($dir,$_))}++} @files;
  close(DIR);
}



print STDERR keys(%wigs_fs)." Binary wig files in filesystem found\n";

DB:
foreach my $db (@dbs_touse) {
 my $store = Bio::DB::SeqFeature::Store->new(
					    -dsn     => join(":",($DSN,$db)),
					    -adaptor => $ADAPTOR,
					    -user    => $USER,
					    -pass    => $PASS,
					    -write    => 0,
    ) or next; # die "Couldn't create connection to the database"; (Just skip it)
 print STDERR "Looking in $db...\n";
 my @results = $store->search_attributes($BASE,['wigfile']);
 @results = (@results,$store->search_attributes($BASE,['wigfileA'])); # HybridPlot syntax
 @results = (@results,$store->search_attributes($BASE,['wigfileB'])); # HybrydPlot syntax
 if (!@results || @results == 0){next DB;} #No files referred in this database

 my $res_index;
 # Examine the first of results and determine the index of array element which hold the file information
 print STDERR scalar(@results)." Results retrieved when searching for attribute wigfile\n" if DEBUG;
 my @testarray = @{$results[0]};

 RESINDEX:
 foreach my $i (0..$#testarray) {
   $testarray[$i]=~/$BASE/ ? $res_index = $i : next RESINDEX;
   last RESINDEX;
 }
 if (!$res_index) {die "Cannot determine the index of result array with file info!\n";}

 map{$wigs_db{$db}->{$_->[$res_index]}++} (@results);
}

my %total_db = ();
foreach  my $d (keys %wigs_db) {
 map{$total_db{$_}++} (keys %{$wigs_db{$d}});
}

print STDERR scalar(keys %total_db)." Files linked to in database(s)\n";

# Now we have wiggle files from both file system and db, check if all fs files are registered in db
my %seen = ();
my %info = {'deadref' => {},	# Refered to in DB, but absent on filesystem
            'orphan'  => {},	# Present on filesystem, but not referenced in DB (depricated data, most likely)
	    'collide' => {}};	# Files referenced by multiple databases
my $count = 0;
foreach my $db (keys %wigs_db) {
 foreach my $file (keys %{$wigs_db{$db}}) {
  print STDERR "FILE: $file\n" if DEBUG;
  if ($wigs_fs{$file}) {$seen{$file}++} else {$info{'deadref'}->{"$db: $file"}++;}
 }
}
print scalar(keys %seen)." Files registered in DB and present in File System\n";

map{ if (! $seen{$_}){$info{'orphan'}->{$_}++}} (keys %wigs_fs);
map{$info{'collide'}->{$_}++ if $seen{$_} > 1} (keys %seen);


print STDERR "We have:\n",
             scalar(keys %{$info{'deadref'}})." Files referred in Database, but absent on Filesystem\n",
	     scalar(keys %{$info{'orphan'}})." Files with no reference in Database, but present on Filesystem\n",
	     scalar(keys %{$info{'collide'}})." Files referred by multiple databases\n";

if (scalar(keys %{$info{'deadref'}}) > 0 || scalar(keys %{$info{'orphan'}}) > 0 || scalar(keys %{$info{'collide'}}) > 0) {
 print STDERR "Print them to a list (y/n)?\n";
 my $answer = <STDIN>;
 if ($answer =~ /y/i) {&print_report;}
}

exit 0;

sub print_report {
 # References without files:
 if (scalar(keys %{$info{'deadref'}})  > 0){
  print "\n\n--Dead Refereces (no files in filesystem):--\n";
  map{print $_."\n"} (keys %{$info{'deadref'}});
 }

 # Orphan files:
 if (scalar(keys %{$info{'orphan'}})  > 0){
  print "\n\n--Orphan Files (no references in selected databases):--\n";
  map{print $_."\n"} (keys %{$info{'orphan'}});
 }

 # Colliding tracks:
 if (scalar(keys %{$info{'collide'}})  > 0){
   print "\n\n--Colliding tracks:--\n";
   foreach my $coll (keys %{$info{'collide'}}) {
                     print $coll;
                     my @dbs = ();
                     map{push(@dbs, $_) if $wigs_db{$_}->{$coll}} (keys %wigs_db);
                     print @dbs > 0 ? "\t".join(",",sort @dbs)."\n" : "\n";
                     }
 }
}

