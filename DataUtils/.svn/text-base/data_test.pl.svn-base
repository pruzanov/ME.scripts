#!/usr/bin/perl -w
use Bio::DB::GFF;

my $thing = shift or die "What should I delete (eg 'method' or 'method:source')?\n";

# Open the sequence database
my $db      = Bio::DB::GFF->new( -adaptor => 'dbi::mysqlopt',
                                 -dsn     =>
'dbi:mysql:worm:user=modencode:password=modencode+++',
                                );


for (qw/I II III IV V X MtDNA/) {
 my $segment = $db->segment($_);
 my @transcripts = $segment->features($thing);
 print STDERR scalar(@transcripts)." features of this type [$thing] on chromosome $_\n";
}
