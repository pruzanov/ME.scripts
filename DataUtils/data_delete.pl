#!/usr/bin/perl -w
use Bio::DB::GFF;

my $thing = shift or die "What should I delete (eg 'method' or 'method:source')?\n";

# Open the sequence database
my $db      = Bio::DB::GFF->new( -adaptor => 'dbi::mysql',
                                 -dsn     => 'dbi:mysql:worm:user=modencode:password=modencode+++',
                                );

# Probably it's a good idea to have some code for checking 
# which chromosomes have this type of feature annotated



for (qw/I II III IV V X MtDNA/) {
 my $segment = $db->segment($_);
 my @transcripts = $segment->features($thing);
 print STDERR "deleting from $_...\n";
 #print join "\n", 
 $db->delete_features(@transcripts);
}
