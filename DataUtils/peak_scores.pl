#!/usr/bin/perl -w

#
# Simple script for writing boxplot-generating R code for checking distribution of scores in peak (GFF) files

=head1 TITLE

 peak_scores.pl - Maybe used for batch checking score distribution in GFF files

 needs a list of directories (submission ids) which maybe passed as n-n if there are successing numbers used as id names
 
 example: ./peak_scores.pl 23 24-28 34-56 67

=head1 SINOPSIS
    
 usage:  peak_scores.pl [submission ids]


=cut

my @args = @ARGV;
my %dirs;
my $count = 0;

foreach (@args) {
 #next if (!/^\d+/);
 if (/\s(\d+)\-(\d+)\s/) {
  map {$dirs{$_}++} ($1..$2)
 } else {$dirs{$_}++;}
}

foreach my $d (keys %dirs) {
 my $okdir = 0;
 opendir(DIR,$d) and $okdir = 1;
 print STDERR "Cannot read from directory $d skipping...\n" if !$okdir;
 next if !$okdir;
 my @gffs = grep {!/wiggle/} grep {/\.gff3*$/} readdir DIR;
 close DIR;

 map{print "PEAK".++$count." = read.table (\"$d/$_\",header=FALSE)\n"} @gffs;
}
map{push @peaks,"PEAK".$_."[,6]"} (1..$count);

print "ALLPEAKS = list(".join(",",@peaks).")\n";
print "boxplot(ALLPEAKS,outline=F)\n";
