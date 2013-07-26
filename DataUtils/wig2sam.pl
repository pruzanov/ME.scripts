#!/usr/bin/perl -w

=head1 SUMMARY

Script is for handling situation when we have wiggle files for replicate ChIP-Seq experiments
but no merged wiggle file. Script will convert wiggle files to fake sam/bam files and do the
merging using samtools merge command. After that, if Bio::DB::BigFile is installed the script
will call bamToGBrowse.pl script and create bigwig file(s) for all bam files in the directory

Depending on the options different outputs will be produced

=head1 SYNOPSIS

wig2sam.pl [OPTIONS] 

Will read the directory and parse all wiggle files it finds one by one. If wiggle files are
variable step files (or BED files) they will be converted to sam/bam format and if the -m option
used, a merged bam file will be created

Depending on the options intermediate files will or won't be cleaned

=head1 OPTIONS

--out    ouput is either bam (default) or sam

--m      merge BAM files (default)

--org    organism (will try to guess from fasta name, but will default to C.elegans in case of failure)a
                   currently supports two dafault organisms - C.elegans and D.melanogaster

--rel    genomic release

--wigdir directory with wiggle file

--f      fasta file to use for fake SAM generation

=head1 EXAMPLES

wig2sam.pl -m MYDIR  elegans-ws190.fa  - will read all wiggle files and create intermediate fake sam files

wig2sam.pl -S MYDIR  elegans-ws190.fa  - will create sam files for each of wiggle files in MYDIR

wig2sam.pl -mS MYDIR  elegans-ws190.fa - will create a merged bam file and keep intermediate sam files

=cut


use strict;
use Getopt::Long;
 
use constant PROBELENGTH=>36;

my %options;
my($bed,%fasta,%sizes);

GetOptions(
           'out=s'  => \$options{output},
           'wigdir=s'   => \$options{wigdir},
           'm'      => \$options{merge},
           'f=s'    => \$options{fasta},
           'org=s'  => \$options{org},
           'rel=s'  => \$options{rel}
           ) || die <<END;
Usage: 
  wig2sam.pl [OPTIONS] -d directory_with_wigfiles -f fasta_file
END

$options{output} ="bam" if !$options{output};
$options{merge} ||=1;

#map{print join(" = ",($_,$options{$_}))."\n"} (keys %options);

#First, generate a header for intermediate SAM file

if ($options{fasta} && !$options{org}) {
 $options{org} = $options{fasta} =~/elegans/i ? "C.elegans" : "D.melanogaster";
 if (!$options{rel}) {
  #Default modENCODE releases for worm and fly:
  $options{rel} = $options{org} eq "C.elegans" ? "WS220" : "r5";
 }
}

&get_fasta($options{fasta});

my @sam_header;
map{push @sam_header,join("\t",("\@SQ","SN:$_","AS:$options{rel}","LN:$sizes{$_}","SP:$options{org}"))} (keys %sizes);

#Second, collect all wiggle files and create sam files

opendir(DIR,$options{wigdir}) or die "Couldn't open directory with wiggle files";
my @wigfiles = grep {/\.wig$/} readdir (DIR);
closedir DIR;

my @samfiles;
my @bamfiles;
my $wigitem = 1;

foreach my $wigfile (@wigfiles) {
 my $sam = $wigfile;
 my $wig = join("/",($options{wigdir},$wigfile));
 my $line = 1;
 my $id = $1 if $wigfile=~/(\w+?)_/;
 if ($id) {$id.="_$wigitem";}
 $wigitem++;
 $id ||= "TEMPSAM_";
 $sam =~ s/\.wig/\.sam/;

 $sam = join("/",($options{wigdir},$sam));
 
 push @samfiles,$sam;
 
 open(WIG,"<$wig") or die "Couldn't read from [$wigfile]";
 open(SAM,">$sam") or die "Couldn't write to samfile [$sam]";

 map{print SAM $_."\n"} @sam_header;
 my($chrom,$span,$cur_pos,$score,$probe_seq,$seq_score,$probe,$lines); 
 $span = PROBELENGTH;

 while(<WIG>) {
  if (/^\#/ || /^track/ || /^$/){next;}
  if (/chrom=(\S+).*span=(\d+)/){
   if ($chrom && $lines) {print STDERR $lines." probes collected for chromosome $chrom\n";}
   $lines = 0;
   $chrom = $1;
   $span = $2;
   $chrom =~s/^chr//; #strip the UCSC prefix
   print STDERR "Data for chromosome $chrom getting processed...\n";
   &get_fasta($options{fasta},$chrom);

   if($cur_pos) {
    $probe = $span;
    next if $probe <= 0;
    $probe_seq = $cur_pos+$probe-2 <= $#{$fasta{$chrom}} ? join("",@{$fasta{$chrom}}[$cur_pos-1..$cur_pos+$probe-2]) : &get_dummy($probe);
    $seq_score = &get_dummy($probe,'h');
    map{print SAM join("\t",(join("_",($id,$line++)),0,$chrom,$cur_pos,255,$probe."M","*",0,0,$probe_seq,$seq_score,"NH:i:1"))."\n"} (1..$score);
   }
   next;
  }
  chomp;
  my @temp = split("\t");
  $bed = @temp == 4 ? 1 : 0;
  #Two different ways of parsing
  #=======BED FILE==============
  if ($bed) {
  
   if(!$chrom || $chrom ne $temp[0]) {
    $chrom = $temp[0];
    $chrom =~s/^chr//;
    &get_fasta($options{fasta},$chrom);
   }
  
   $probe = $temp[2]-$temp[1];
   next if $probe <= 0;
   if ($temp[3]=~/\./ || $temp[3]=~/^\-/){die "It seems that wiggle file does not come from ChIP-Seq experiment";}
   $score = $temp[3];
   $probe_seq = join("",@{$fasta{$chrom}}[$temp[2]-1..$temp[3]-2]) || &get_dummy($probe);
   $probe_seq = uc($probe_seq);
   $seq_score = &get_dummy($probe,'h');
   
   map{print SAM join("\t",(join("_",($id,$line++)),0,$chrom,$temp[1],255,$probe."M","*",0,0,$probe_seq,$seq_score,"NH:i:1"))."\n"} (1..$score);
   $lines++;
   next;
  #========VAR STEP WIGGLE========
  } else {

   if ($cur_pos) {
    $probe = $temp[0]-$cur_pos >= $span ? $span : $temp[0]-$cur_pos;
    if ($probe <= 0){$cur_pos = $temp[0];next;}
    #print STDERR @{$fasta{$chrom}}[$cur_pos-1..$cur_pos+$probe-1];
    $probe_seq = join("",@{$fasta{$chrom}}[$cur_pos-1..$cur_pos+$probe-2]) || &get_dummy($probe);
    $probe_seq = uc($probe_seq);
    $seq_score = &get_dummy($probe,'h');
    
    map{print SAM join("\t",(join("_",($id,$line++)),0,$chrom,$cur_pos,255,$probe."M","*",0,0,$probe_seq,$seq_score,"NH:i:1"))."\n"} (1..$score);
    $lines++;
   }
    $score = $temp[1];
    $cur_pos = $temp[0];
  }
 }
 
 close WIG;
 close SAM;

 my $bam = $sam;
 $bam =~ s/\.sam$/\.bam/;

 #if (!$options{output} ||  $options{output} =~/bam/i || $options{m}) {
 # print STDERR "Creating $bam...\n";
 # `samtools view \-S $sam \-b > $bam`;
 # my $sorted = $bam;
 # $sorted =~s/\.bam$/_sorted/;
 # print STDERR "Sorting $bam\n";
 # `samtools sort $bam $sorted`;
 # $sorted.=".bam";
 # push @bamfiles,$sorted;
 #}
}



# Clean up, merge bams if requested
if ($options{output} !~/sam/i) {
 #map{`rm $_`} @samfiles;
}

if ($options{merge} && @bamfiles > 1) {

 # Construct a name for merged bam file
 my @matches;
 for (my $i=0; $i<@bamfiles; $i++) {
  $matches[$i] = [];
  my @letters = split //,$bamfiles[$i];
  map{push @{$matches[$i]},$_} @letters;
 }
 
 my($stop,$merge_name);
 while (!$stop) {
  foreach my $l (1..length($matches[0]->[0])) {
   map{$stop = 1 if $matches[$_]->[$l] ne $matches[0]->[$l]} (0..$#matches);
   $merge_name.=$matches[0]->[$l] if !$stop;
  }
  last; #just in case
 }
 
 length($merge_name) > 0 ? $merge_name.="_merged.bam" : $merge_name = "BAM_merged.bam";

 # Now merge the bamfiles

 my $mergestring = join("/",($options{wigdir},$merge_name))." ".join(" ",@bamfiles);
 #`samtools merge $mergestring`;
}


# Subroutines

sub get_fasta {
 my($fasta,$get_chrom) = @_;
 my($found,$skip);
 my @fasta = ();

 if ($get_chrom) {
  print STDERR "Will Get sequence for $get_chrom...\n";
  %fasta = ();
 } else {
  print STDERR "Will get sizes of the chromosomes...\n";
 }
 open(FASTA,"<$fasta") or die "Couldn't read from fasta file [$fasta], aborting";
 # This may not work for big genomes
 my $current;
 while(<FASTA>) {
 chomp;
 if (/^\>(\S+)/) {if ($found) {last;}
                  $current = $1;
		  $skip = ($get_chrom && $get_chrom eq $current) ? 0 : 1;
                  next if $skip;
                  print STDERR "Reading from $current\n";
                  $fasta{$current} = [];
                  next;}
 next if $skip && $get_chrom; 
 my @temp = split //,$_;
 if ($get_chrom && $current eq $get_chrom) {
   $found = 1;
   push(@fasta,@temp);
   
 } else {
   $sizes{$current}+=scalar(@temp);
 }
 }
 if ($get_chrom) {
  $fasta{$current} = [@fasta];
  print STDERR scalar(@{$fasta{$current}})." nucleotides collected for $current\n";
 }
 close FASTA;
}

sub get_dummy {
 my $dummy;
 my($length,$letter) = @_;

 $letter ||= "N";

 map{$dummy.=$letter} (1..$length);
 return $dummy;
}

