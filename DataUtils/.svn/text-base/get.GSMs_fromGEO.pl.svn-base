#!/usr/bin/perl -w

#
# screen -scrapping script for retrieving all GSM ids from a GEO report page given a list of GSE accessions
#


my $list = shift @ARGV;

open(LIST,"<$list") or die "I need a list of GSE accessions";
my %gses;
my $geo = "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=";

while(<LIST>) {

 chomp;
 if (/(GSE\d+)/) {$gses{$1} = ();}
}
close LIST;


foreach my $gse(keys %gses) {
 `wget -q -O temp_$$ $geo$gse`;
 open (FILE,"<temp_$$") or die "Couldn't read from wget output";
 my(@lines,%gsms);
 while (<FILE>) {
  push @lines,$_ if /GSM\d+/;
 }

 close FILE; 
 map{map {$gsms{$_}++} (/(GSM\d+)/g)} @lines;

 print STDERR join(", ",($gse, sort keys %gsms));
 print STDERR "\n";
 `rm temp_$$`;
}
