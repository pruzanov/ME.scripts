#!/usr/bin/perl -w
#
#
#
my $dir = shift @ARGV;
chomp($dir);
$dir = $` if $dir=~/\/$/;

my @tdir = split("/",$dir);
my $db = $tdir[scalar(@tdir)-1];
my $basedir = "/var/lib/mysql/$db";
my $altdir  = "/nfstest/mysql.tables/$db";

my @files = grep{!-l $_} glob "$dir/*.sql";
my $count = 1;

foreach my $f(@files){
 print STDERR "Processing ".$count++." of ".scalar(@files)."...\n";
 my $TABLE = $f;
 $TABLE =~ s/\.sql//;
 my $ft = $f;
 $ft =~ s/\.sql/\.txt/;
 $TABLE =~ s/.*\///g; 
 next unless(-f $ft);

 `mysql -umodencode -pmodencode+++ $db < $f`;
 `mysql -umodencode -pmodencode+++ -D $db -e "load data local infile '$ft' into table $TABLE"`;

 my @tabs = grep {!-l $_} glob "$basedir/$TABLE.MY*";
 
 foreach my $t(@tabs){
  my $basetab = $t;
  $basetab =~ s/.*\///g;
  my $alttab = $altdir."/".$basetab;
  
  unless(-f $alttab){system("cp $t $alttab");}
  if(-f $t){system("rm $t");}
  system("ln -s $alttab $t");
 }

}



