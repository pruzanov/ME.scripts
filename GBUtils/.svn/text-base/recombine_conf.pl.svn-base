#!/usr/bin/perl -w

# Script for reshuffling an existing conf file, 
# gets conf file and number of submissions a an argument

use strict;

use constant USAGE=><<END;
Usage: ./recombine_conf.pl [conf_file] [submission ids]
END

my $template = "karpen_vista_template.csv"; #to use with this script, template for stanza
my $subfile  = "karpen_sub2peak";
my $name_file = "R28_names.txt";
my($file,@args) = @ARGV;
if (!$file || ! -f $file){die USAGE;}


my(%subs,%ids,%select);

foreach (@args) {
 next if (!/^\d+/);
 if (/(\d+)\-(\d+)/) {
  map {$subs{$_}++} ($1..$2);
 } else {$subs{$_}++;}
}

#foreach my $s (@subs) {
# 
#}
open(IDS,"<$subfile") or die "Couldn't read from file with submission/track ids";
 while(<IDS>) {
  chomp;
  my @temp = split("\t");
  $ids{$temp[0]}->{peaks}  = $temp[2] ? $temp[2] : undef;
  $ids{$temp[0]}->{signal} = $temp[1] ? $temp[1] : undef;
}
 


open(FILE,"<$file") or die "Couldn't open [file] for reading";

#collect all track/data source info and record it for making feature select and link fields
my $in = 0;
my(@data,@tracks);

while(<FILE>) {
 chomp;
 next if (/^\#/); #skip comments
 if (/^\[/ && !/\:\d+\]/) {
  $in = 1;
 }elsif(/^\s*$/) {
  $in = 0;
  @data = ();
  @tracks = ();
 }

 if (/\S+\s+\".+?\"\s*\=\s*(\d+)\;/) {$select{$1} = $_;}
 if (/(\d+)\=\>(\d+)\,*/) {$ids{$1}->{signal} = $2 if !$ids{$1};}

}

close FILE;

# Try to get names for new submissions to use in 'select' field
my $namefile_ok = 1;
open(NAMES,"<$name_file") or $namefile_ok = 0;
if ($namefile_ok) {
 print STDERR "Namefile ok, reading names from [$name_file]\n";
 while(<NAMES>){
  chomp;
  my @temp = split("\t");
  unless($select{$temp[0]}){
   $select{$temp[0]} = $temp[1]." \"$temp[1]\" \= $temp[0]\;"; 
  }
 }
 close NAMES;
}


#Fill in the template with collected information
open (TEMPLATE,"<$template") or die "Cannot read the template from [$template]";
while(<TEMPLATE>) {
 chomp;
 my $pad;
 /\= \w+/ ? map{$pad.=" "} (1..length($`)+2) : map{$pad.=" "} (1..length($_)); 
 if (/^feature/) {
  my $first;
  print;
  map {if(!$first++){
         print "VISTA:".$ids{$_}->{signal}."\n";
        }else{
         print $pad."VISTA:".$ids{$_}->{signal}."\n";
        }} (sort {$a<=>$b} keys %subs);
  next;
 }

 if (/^data source/) {
  my @ds;
  print;
  map{if ($ids{$_}->{signal}){push @ds,$_;}if ($ids{$_}->{peaks}){push @ds,$_;}} (sort {$a<=>$b} keys %subs);
  print join(" ",@ds),"\n";
  next;
 }

 if (/^track source/){
  my @ts;
  print;
  map{if ($ids{$_}->{signal}){
       push @ts,$ids{$_}->{signal};
     }
     if ($ids{$_}->{peaks}){
       push @ts,$ids{$_}->{peaks};
     }} (sort {$a<=>$b} keys %subs);
  print join(" ",@ts),"\n";
  next;
 }

 if (/^select/) {
  print $_."\n";
  foreach my $s (sort {$a<=>$b} keys %subs){
         if ($select{$s}) {
         print $pad.$select{$s}."\n";
         } else {
         print $pad."Insert select string for submission = $s\;\n";
         }
  }
  next;
 }
 
 if (/\%subs\s*=\s*\($/) {
 my $first;
 my @lines;
 print;
 map {if(!$first++){
         print join("=>",($ids{$_}->{signal},$_));
        }else{
         push @lines,$pad.join("=>",($ids{$_}->{signal},$_));
        }} (sort {$a<=>$b} keys %subs);
 if (@lines > 0) {
  print ",\n";
  print join(",\n",@lines);
 }
 print ");\n";
 next;
 }

 print;
 print "\n";
}

close TEMPLATE;


my $subline = join(" ",keys %subs);
my $cite = `./merge_cites $subline`;
print $cite;
