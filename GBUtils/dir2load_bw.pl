#!/usr/bin/perl -w

#
# A simple script for composing load wiggle gff file
# given a list of directories with wiggle files and bw files
#

my @args = @ARGV;
my %dirs;
my $fasta = "/browser_data/fly/fasta/dmel-all-chromosome-r5.8.fasta";
my %tracks;
my $trackfile = "sublist";



foreach (@args) {
 next if (!/^\d+/);
 if (/(\d+)\-(\d+)/) {
  map {push @dirs,$_} ($1..$2);
 } else {push @dirs,$_;}
}

# Load track info, if available
if (-e $trackfile) {
open(TRACKS,"<$trackfile") or die "Couldn't read from [$trackfile]";
 while (<TRACKS>) {
  next if /^$/;
  chomp;
  my @temp = split("\t",$_);
  $tracks{$temp[0]} = $temp[1];
 }
 close TRACKS;
}

# Calculate coordinates for each feature and collect the list of bw files

foreach my $dir (@dirs) {
 print STDERR "Processing $dir ...\n";
 $dirs{$dir} = {bw=>[],coords=>{},name=>"No_name"};
 opendir(DIR,$dir) or warn "Cannot read from directory [$dir]" and next;
 my @bams = grep{/\.bam$/} readdir DIR;
 my %sizes = map{chomp;@temp=split("\t",$_);$temp[0]=>$temp[1];} `samtools view -H $dir/$bams[0] | awk '{OFS="\t";print \$2,\$5}' | sed 's/SN\://' | sed 's/LN\://'`;
 foreach my $chr (keys %sizes) {
  my($start,$end) = (1,$sizes{$chr});
  $dirs{$dir}->{coords}->{$chr} = [$start,$end];
 }
 rewinddir DIR; 
 $dirs{$dir}->{bw} = [sort grep {/(plus|minus).*\.bw$/} readdir(DIR)]; 
 #print STDERR "Got ".scalar(@{$dirs{$dir}->{bw}})." BigWig files for submission $dir\n";

 rewinddir(DIR);
 my($idf_file) = grep {/idf/i} readdir(DIR);
 my $name = `grep \"Investigation Title\" $dir/$idf_file | awk -F \"\t\" '{print \$2}' | sed 's/\"//g' | sed 's/ //g'`;
 chomp($name);
 $dirs{$dir}->{name} = $name if $name =~ /\w+/;
 closedir(DIR);
}

# Compose a load wiggle file


print "\#\#gff-version 3\n\n";
foreach my $d (sort {$a<=>$b} keys %dirs) {
 my $track = $tracks{$d} ? $tracks{$d} : $d;
 my $wigstring = "Name=$dirs{$d}->{name}\;peak_type=\"\";wigfileA=$dirs{$d}->{bw}->[1];wigfileB=$dirs{$d}->{bw}->[0];fasta=$fasta";
 map{print join("\t",($_,$track,"WIG",$dirs{$d}{coords}{$_}->[0],$dirs{$d}{coords}{$_}->[1],".",".",".",$wigstring)),"\n";} (keys %{$dirs{$d}->{coords}}); 
 print "\n";
}
