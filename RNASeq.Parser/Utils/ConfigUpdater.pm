package Utils::ConfigUpdater;

use strict;
use lib '/usr/local/share/gb2libs/lib/perl5';
use Bio::Graphics::Browser2;
use Data::Dumper;
use IO::File;
use constant DEBUG=>0;

sub new {
 my $class = shift;
 my $options = shift @_;

 $class = ref($class) || $class;
 return bless {
  globals => Bio::Graphics::Browser2->open_globals,
  ids     => $options->{-ids},
  updates => $options->{-ups},
  confdir => "Config"
 },$class;

}


sub update {
 my $self = shift;
 my $files = shift;
 my @dirs = (keys %{$files});
 
 DIR:
 foreach my $dir (@dirs) {
  if (!$self->{updates}->{$dir}){next DIR;}

  # Update conf file (complex)
 my $conf_file = `grep '^data source' $self->{confdir}/*conf | grep $self->{updates}->{$dir} | sed 's/\:.*//'`;
 chomp($conf_file);
  if ($conf_file && -e $conf_file) {
  $self->update_config($conf_file,$self->{updates}->{$dir},$dir,$files->{$dir});
  }
 }
}


sub update_config {
 my $self = shift;
 my %report;

 my @update_fields = ("database","data source","citation","feature","track source","link"); # These options may contain old ids
 my $conf_file = shift @_;
 print STDERR "Updating Config file : [$conf_file]\n";
 my($old,$new,$newfiles) = @_;

 my $source  = Bio::Graphics::Browser2::DataSource->new($conf_file,"My Config","Currently processed config file",$self->{globals});
 my @labels = $source->data_source_to_label($old);
 my %len;
 map {$len{$1}++ if /\:(\d+)$/} $source->configured_types;
 my @lens = sort {$a<=>$b} keys %len;

 # Get database options for all semantic levels
 my @dbs;
 push @dbs,$source->semantic_setting($labels[0],'database');
 map{push @dbs,$source->semantic_setting(join(":",($labels[0],$_)),'database')} @lens;

 # Get citation text
 my @cite_lines;
 my $cite_file = $new.".stanza";
 my $fh = new IO::File();

 if ( -f "cache\/$cite_file" && $fh->open("<cache\/$cite_file")) {
   $fh->open("<cache\/$cite_file") or warn "Cannot read from cached citation for $new";
 }
 
 if ($fh) {
   @cite_lines = @{$self->clean_cite($fh)};
   $fh->close;
   if (-e "temp$$"){`rm temp$$`;}
 }
 
 # Go through conf file changing old ids to new ids, append newer citation

 $fh->open($conf_file) or warn "Cannot read from config";

 my $db_in = 0;
 my $cf_in = 0;
 my $skip  = 1;
 my $cite_in = 0;


 open(TEMP,">temp_conf_$$") or die "Cannot proceed, coud not create a temp conf file for [$new]";
 while(<$fh>) {
  #If we are in old citation, skip lines
  if ($cf_in && $cite_in && /^\s+\S+/) {next;}


  # Check if we are in 
  if (/^\[/ ) {
   $db_in = 0; # inside db handle
   $cf_in = 0; # inside config file text
   DB:
   foreach my $d (@dbs) {
    if (/$d\:database/) {
     $db_in = 1;
     s/$old/$new/g;
     last DB;
    }
   }
   LB:
   foreach my $l (@labels) {
    if ($db_in) {last LB;}
    if (/$l[\:|\]]/) {
     $cf_in = 1;
     last LB;
    }
   }
  }

 if (!$db_in && !$cf_in) {
  print TEMP $_;
  next;
 }

 if ($db_in && (/bam\s+(\S+.bam)$/ || /bigwig.*\'(\S+\.bw)\'/)) {
  if ($report{$new}->{old_file}) {
   push(@{$report{$new}->{old_file}},$1);
  }else{
   $report{$new}->{old_file} = [$1];
  }
 }

 if (/^citation/ && $cf_in) {
  $cite_in = 1;
  if (@cite_lines && @cite_lines > 0) {
   map{print TEMP $_} @cite_lines;
   print TEMP "\n";
   next;
  }
 }

 if (/^\S/ && !/^\[/) {
  $skip = 1;
  map{if (/^$_/){$skip = 0}} @update_fields;
 }

 if (!$skip) {

  /WIG:\d+/ ? s/\d+/$self->{ids}->{$new}->[0]/ : s/$old/$new/g;
  if (/^track source/) {
    my $trackstring = join(" ",(keys %{$self->{ids}->{$new}->{sig}}));
    if ($self->{ids}->{$new}->{peak}) {$trackstring.= " ".join(" ",(keys %{$self->{ids}->{$new}->{peak}}));}
    if ($trackstring =~ /\S+/) {
     s/= .*$/= $trackstring/;
   }
  }
 }

 if ($db_in && (m!bam\s+\S*/(\S+.bam)$! || m!bigwig.*\'\S*/(\S+\.bw)\'!)) {
  if (ref($newfiles) && $newfiles->{bams} && $newfiles->{bws}) {
   my $oldf = $1;
   if ($oldf=~/bam$/ && $newfiles->{bams} && $oldf ne $newfiles->{bams}) {
     print STDERR "SWAPPING $oldf for $newfiles->{bams}->[0]\n" if DEBUG;
     s/$oldf/$newfiles->{bams}->[0]/;
   } elsif ($oldf=~/bw$/ && $newfiles->{bws} && $oldf ne $newfiles->{bws}) {
     print STDERR "SWAPPING $oldf for $newfiles->{bws}->[0]\n" if DEBUG;
     s/$oldf/$newfiles->{bws}->[0]/;
   }
  }
 }

 print TEMP $_;
 }
 $fh->close;
 close TEMP;

 # Print out diffs, confirm overwrite
 my @diflines = `diff -bw $conf_file temp_conf_$$`;
 map{print STDERR $_} @diflines if DEBUG;
 print STDERR "\n";

 #print STDERR "Overwrite old config with this one? (y/n)\n";
 print STDERR "Will overwrite old config with new one\n";
 `mv temp_conf_$$ $conf_file`;
}

#=====================Removes spaces, other junk
sub clean_cite ($) {
 my $self = shift;
 my(@results,$in);
 my $f = shift;

 while (<$f>) {
  if (/^citation/ || $in) {
   if ((/^citation/ && $in) || (/^\w/ && !/^citation/)){last;}
   $in = 1;
   if (/^\s*$/ || /^\#/ || /^$/){next;};
   push @results,$_;
  }
 }
 return \@results;
}

1;
