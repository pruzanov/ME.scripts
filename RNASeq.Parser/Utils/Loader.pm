package Utils::Loader;

=head1 TITLE

 load_sam - Maybe used for batch loading of files from a remote DCC server (presently hard-coded heartbroken)
 Relies on gpg key so multiple password entering is avoided

 needs a list of directories (submission ids) which maybe passed as n-n if there are successing numbers used as id names
 
 example: ./load_sam 23 24-28 34-56 67

=head1 SINOPSIS
    
 my $load = new Loader(-key=>"my_key",-remote=>"remote_host");
 $load->load_data(@dirs);

=cut

use strict;
use Env qw(HOME);


sub new {
 my $class = shift;
 my $options = shift @_;

 $class = ref ($class) || $class;
 my $key    = $options->{-key} || "$HOME/\.ssh/pipeline-key"; 
 my $remote = $options->{-remote} || "modencode-www1.oicr.on.ca:/modencode/raw/data/"; 
 my $user   = `whoami` || 'nobody';
 chomp($user);

 return bless{
  key => $key,
  remote => $remote,
  user => $user
  },$class;
}



sub load_data {
 my $self = shift;
 my @dirs = @_;
 
 foreach my $d (@dirs) {
  if (! -d $d) { `mkdir $d`; }
  my $tracksbad = `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/tracks/* $d/`;
  if ($tracksbad) {print STDERR "It appears there's no tracks\n";}
  
  # Case of IDF/SDRF never set uniformly
  my $noidf = `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*idf* $d/`;
  if ($noidf) {
   $noidf = `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*IDF* $d/`;
  } else {
   `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*sdrf* $d/`;
   return;
  }

  if (!$noidf) {
   `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*SDRF* $d/`;
   return;
  }

  # Try one dir down
  $noidf = `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*/*idf* $d/`;
  if ($noidf) {
   $noidf = `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*/*IDF* $d/`;
  } else {
   `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*/*sdrf* $d/`;
   return;
  }

  if (!$noidf) {
   `scp -Cr -i $self->{key} $self->{user}\@$self->{remote}$d/extracted/*SDRF* $d/`;
  } else {
   print STDERR "Metadata could not be loaded\n";
  }
 } # dir iterations
}

1;
