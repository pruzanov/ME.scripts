#!/usr/bin/perl -w
#
# Script for unlinking mysql table files in /var/lib/mysql directory and creation of symbolic links instead (given that files exist in an alternative location)
#
use strict;

my $altdir = shift @ARGV; # This is the location of alt. directory (database) where we have the copies of database tables

my $db = "fly_staging";
chomp($altdir);
if($altdir=~m!/$!){chop($altdir);}
if($altdir=~/\/(\w+?)$/){$db = $1;}

my $basedir = "/var/lib/mysql/".$db;
print STDERR "Reading from $basedir\n";
my @files = grep {!-l $_} glob "$altdir/*.MY*";


foreach my $file(@files){
 my @ff = split("/",$file);
 my $fn = $ff[scalar(@ff)-1];
 my $basefile = "$basedir/$fn";

 #print STDERR "Checking $basefile\n";
 if(-f $basefile){
  my $altfile = "$altdir/$fn";
  #print STDERR "trying to remove/create link for $fn\n";
  system("rm $basefile");
  system("ln -s $altfile $basefile");
 #exit;
 }

}
