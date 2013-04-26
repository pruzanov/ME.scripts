#!/usr/bin/perl -w

use strict;
use IO::File;

#
# USAGE: GFF2WIG.pl name description infile.gff > outfile.wig
#

=head1 TITLE
  
 GFF2WIG.pl - Convert gff files with small RNA sequencing data to wiggle files

=head1 SINOPSIS
 
 GFF2WIG.pl will convert gff files to wiggle files of two types:
 
 1. Score is calculated as a sum of counts (abundace of sequeces, matching a particular sequence region

 2. Score is calculated as the max count (abundace) among the sequences matching a particular region

 In both cases, score is log10-scaled because of quite large dynamic range of the data (from 1 to few thousands)

=cut

my $USAGE = "GFF2WIG.pl name(smth like GSM00..) description(GSM00.. short RNA reads) infile.gff\n";

# Small addition - now we need to be able to process SAM files
my @chroms; # Collect this info from the file   = qw[2L 2LHet 2R 2RHet 3L 3LHet 3R 3RHet 4 M U X XHet YHet];
my($name,$description,$filename) = @ARGV;
unless($name && $description && $filename){ die $USAGE;}


my $basename = $filename =~ /\..*$/ ? $` : $filename;
my($file_t,$file_u) = map{$basename.$_.".wig"} ("t","u");

my $binsize = 10; # in bases
my $log10 = log(10);

my $fh = new IO::File();
my $header = "track type=wiggle_0 name=\"$name\" description=\"$description\" visibility=pack viewLimits=-2:2 color=255,0,0 altColor=0,0,255 windowingFunction=mean smoothingWindow=16"; 
#print STDERR $header."\n";

#print STDERR "Do we want to\n",
#             "1. Print out total counts or \n",
#             "2. Print max values for unique sequences\n";

#my $answer = 0;
#while($answer = <STDIN>){
# ($answer == 1 || $answer == 2) ? last : print "Pardon?\n";
#}

#print $header."\n";

# Depending on the file type we need either to generate a temp file from SAM format and extract chromosome info or just extract the chrom info (list of used chromosomes)
if ($filename=~/sam$/) { # We have a sam file, parse it into temp gff
 @chroms = `samtools view -S -H $filename | awk '{print \$2}' | sed 's/SN\://' | sort -u`;
 &sam2gff($filename);
} elsif ($filename=~/bam$/) {
 @chroms = `samtools view -H $filename | awk '{print \$2}' | sed 's/SN\://' | sort -u`;
 &sam2gff($filename);
} elsif ($filename=~/gff$/) { # We have a gff file, get chromosomes
 @chroms = `grep -v ^Sequence $filename | grep -v '\#' | awk '{print \$1}' | sort -u`;
# grep -v ^Sequence 762/GSM360256.gff | grep -v ^\# | grep -v ^$ | awk '{print $1}' | sort -u
} else {
 die "Can't read chromosome information, exiting...\n";
}

print STDERR "Finished converting\n"; # For testing ONLY

# Create output files:
print STDERR "Opening [$file_t] and [$file_u]...\n";

my $fh_t = new IO::File(">$file_t") or die "Cannot write to wigfile for total counts"; 
my $fh_u = new IO::File(">$file_u") or die "Cannot write to wigfile for unique counts";

foreach my $chr (@chroms){
 chomp($chr);
 next if $chr=~/^$/ || $chr=~/^\*/;
 my %bins = ();
 open FILE, "awk '{if(\$1==\"$chr\"){print \$0}}' $filename | sort -n -k 4 | " or die "Cannot fork\n"; #> temp_chr$$`;
 my $current = 0;
 while(<FILE>){ 
  my @temp = split("\t");
  my $first_bin = int($temp[3]/$binsize)+1;
  my $last_bin  = int($temp[4]/$binsize)+1;
  map{$bins{$_}->{total}+=$temp[5] and $bins{$_}->{max}||=$temp[5]} ($first_bin..$last_bin);
  map{$bins{$_}->{max} = $temp[5] if $temp[5] > $bins{$_}->{max}} ($first_bin..$last_bin);
 }
 close FILE;
 print STDERR "\nPARSED $chr";
 foreach my $bin(sort {$a<=>$b} keys %bins){
  print $fh_t join(" ",($chr,$bin*10,$bin*10+9,&log10($bins{$bin}->{total}))), "\n";
  print $fh_u join(" ",($chr,$bin*10,$bin*10+9,&log10($bins{$bin}->{max}))), "\n";
  #my $out = $answer == 1 ? join(" ",($chr,$bin*10,$bin*10+9,&log10($bins{$bin}->{total}))) : join(" ",($chr,$bin*10,$bin*10+9,&log10($bins{$bin}->{max})));
 #print $out."\n";
 }
}
system("rm tempsorted$$") if (-e "tempsorted$$");
print STDERR $? >= 0 ? "Temp file removed\n" : "couldn't remove temp file\n";
$fh_t->close;
$fh_u->close;

# Log-scaling
sub log10 {
 my $num = shift @_;
 return sprintf("%.6f",log($num)/$log10);
}


# A subroutine for parsing sam files to temporary 'gff-like' files
# Needs more testing

sub sam2gff {
 my $fn = shift @_;
 print STDERR "Converting $fn to gff...\n";

 # Get all reads for a chromosome then construct a 6-field file
 my $ofh = new IO::File(">tempsorted$$") or die "Couldn't write to a temporary file\n";
 
 foreach my $chr (@chroms) {
  chomp($chr);
  print STDERR "Parsing $chr...\n";
  if ($fn =~ /\.sam$/) {
   open CONV, "awk '{if(\$3==\"$chr\"){print \$0}}' $fn | sort -n -k 4 | " or die "Cannot fork!"; #> temp_conv$$`; # temp file for conversion
  } elsif ($fn =~ /\.bam$/) {
   open CONV, "samtools view $fn | awk '{if(\$3==\"$chr\"){print \$0}}' | sort -n -k 4 | " or die "Cannot fork!";
  }
  my $current_pos;
  my %tags;

  while(<CONV>) { 
   chomp;
   my @temp = split("\t");
   if(!$current_pos || $temp[3] == $current_pos) {
    $current_pos = $temp[3];
   } else {
    map { print $ofh join("\t",($chr,"temp","temp",$current_pos,$current_pos+length($_)-1,$tags{$_},"Sequence:$_")) and
	  print $ofh "\n" } (keys %tags);
    %tags = ();
    $current_pos = $temp[3]; 
   }
   $tags{$temp[9]}++;
  }
  close CONV;
 }

 $filename = "tempsorted$$";
}
