package Utils::MitoFixer;

=head1 TITLE

 MitoFixer - Maybe used for batch processing of bam files with dmel_mitochondrion_genome (instead of M) refs

 needs a list of directories (submission ids) which maybe passed as n-n if there are successing numbers used as id names
 
 example: ./mito_fixer 23 24-28 34-56 67

=head1 SINOPSIS
 
 MitoFixer need a bamfile (D.melanogaster only!) as an argument
     
=head1 USAGE 
 
 my $fix = MitoFixer->new();
 $fix->fix_mito($file);


=cut

use constant BADMITO=>"dmel_mitochondrion_genome";
use constant GOODMITO=>"M";


sub new {
 my $class = shift;
 $class = ref($class) || $class;
 return bless {},$class;

}


sub fix_mito {

 my $self = shift;
 my $file = shift;
 my $dir = $file=~m!(\S+)/! ? $1 : ".";

 open BAM, "samtools view -h $file |" or die "Cannot fork!";
 open(SAM,">$dir/temp.sam") or die "Cannot write to [$dir/temp.sam]\n";

 print STDERR "Sorting alignments from $file ...\n";
  while(<BAM>) {
   chomp;
   s/BADMITO/GOODMITO/;
   print SAM $_."\n";
  }
  close BAM;
  close SAM;

  print STDERR "Creating BAM file...\n";
  `samtools view -Sb $dir/temp.sam > $file`;

  `rm $dir/temp.sam`;
}

1;
