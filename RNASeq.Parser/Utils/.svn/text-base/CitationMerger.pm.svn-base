package Utils::CitationMerger;

=head1 SYNOPSIS

Processes array of submission ids and gets stanza code for them. Returns merged citation text

=head2 USAGE
default URL for stanza:
http://submit.modencode.org/submit/public/get_gbrowse_stanzas/###

use Utils::CitationMerger;
my $cites = new CitationMerger();
my $text = $cites->get_cites(@dirs);

=cut


use strict;
use IO::File;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Env qw(STANZA_URL);

use constant DEBUG => 1;
use constant CACHE => 1; # Set this to zero to meake the script interactive
use constant DEFAULT_URL => "http://submit.modencode.org/submit/public/get_gbrowse_stanzas/";


sub new {

# my $class = shift;
 #$class = ref($class) || $class;

 #bless {
 # stanza_url=>$STANZA_URL || DEFAULT_URL,
 # pars => {}
 #},$class;

 #return $class;
 my $class = shift;
 my $self = bless 
 { stanza_url=>$STANZA_URL || DEFAULT_URL,
   pars => {},
 }, ref $class || $class;
 return $self;

}

sub stanza_url {
 my $self = shift;
 return $self->{stanza_url};
}


# Read from internet (download stanza from http://submit.modencode.org/submit/public/get_gbrowse_stanzas/SUB_ID)
# Essentially, we need only to merge citations
sub get_cites {
 my $self = shift;
 my @subs = @_;
 my %list = %{$self->get_list(\@subs)};
 my $cachedir = "cache";


 if (!%list || scalar(keys %list) == 0) { print STDERR "We don't have any data to work with, exiting...\n";
                                          return undef; }

 # Ok, we do have some data, let's start stanza extraction
 my $fh = new IO::File();


 # Process just first stanza citation, assume that all stanzas are the same in one filea
 my @coretext = ();	# For the common text
 my $got_core = 0;
 my $in;

 foreach my $file (keys %list) {
  my @current = (); # For storing each parameter's lines

 $fh->open("$cachedir/$file.stanza") or die "Can't read from stanza code for [$file]\n";
 
 LINE:
 while (<$fh>) {
  chomp;
  next if (/^$/ || /^\s+$/);
  
  if (/citation\s+\=/) {
    print STDERR "Found citation\n" if DEBUG;
    $in = 1;
    $got_core = @coretext > 1 ? 1 : 0;
    push(@coretext,$_) if !$got_core;
    next LINE;
  }
  next if !$in;

  if (/\<li\>/ || @current) {
   push(@current,$_);
  }

  if (/\<\/li\>/ && @current) {my $next_par = $self->process_par(\@current);
                               push(@coretext,$next_par) if !$got_core;
                               @current = ();
		               next LINE;
  }
  if (@current) {next LINE;}  
   

  if (/Release Date/) { #we're done
    push(@coretext,$_." Submission $file"); # Register all Release dates
    last LINE;
  }
  push(@coretext,$_);
 }
 $fh->close;
}


 my %seen;
 my $first_track = 1; #Flags first occurance of 'Release' line - we may have multiple Release dates, so we need to print extra text only once
 my $output = "";

 # Final Step: Printing out citation text
 foreach my $line (@coretext) {
  if ($line=~ /\<b\>(.+?)\<\/b\>/ && $self->{pars}->{$1}) {
   my $par = $1;
   print STDERR "Found parameter $par\n" if DEBUG;
   $seen{$par}++;
   my $strings = join(",\n  ",keys %{$self->{pars}->{$par}});
   $strings =~ s/(\S)\s*\,/$1\,/g;
   $output.=join("\n",(' <li>',' <b>'.$par.'</b>',"  $strings",' </li>'."\n"));
   next;
 }

 if ( $line =~ /Release / && $first_track ){
			     $first_track = 0;
  			     foreach my $pr (keys %{$self->{pars}}) {
                             next if $seen{$pr};
                             my $strings = join(",\n  ",keys %{$self->{pars}->{$pr}});
   			     $strings =~ s/(\S)\s*\,/$1\,/g;
                             $output.=join("\n",(' <ol>',' <li>',' <b>'.$pr.'</b>',"  $strings",' </li>',' </ol>',' </br></br>'."\n"));
                            }
                            $output.=$line."\n";}
 last if (!$first_track && $line!~/Release /);
 $output.=$line."\n";
 }
return $output;
}




# Process Each parameter here
sub process_par {
 my $self = shift;

 my @lines = @{shift @_};
 my $string;
 my $par = "ERROR";

 map{$string.=$_} (@lines); # construct solid string
 print STDERR $string."\n" if DEBUG; 
 if ($string=~m!\<li\>\s*\<b\>(.+?)\</b\>(.*)\s*\</li\>!){
 #if ($string=~m/^(.+)/){
   $par  = $1;
   print STDERR "Has Parameter $par\n" if DEBUG;
   my $data = $2;
   my @data = split(", ",$data);
   
   my @fdata; # Remove all besides hrefs
   map{push(@fdata,$_) if $_=~/href/} @data;
   map{$_=~s/^\s*(.*)\s*$/$1/ and $self->{pars}->{$par}->{$_}++} @fdata;
 } else {print STDERR "the string $string is malformed, cannot extract data\n";
         }
 print STDERR scalar(keys %{$self->{pars}})." entries for $par\n" if DEBUG;
 return " \<b\>$par\<\/b\>";
}


# Get the stanza code files list from the web or use an old copy
sub get_list {
 my $self = shift;
 my @subs_ = @{shift @_};
 my %results;

 # Make sure we have the cache dir in place
 if (! -e "cache" || ! -d "cache") {print STDERR "Going to create cache directory\n"; 
                                        my $dir_ok = system("mkdir cache"); }

 my $over_all = 0;

 foreach my $sub (@subs_) {
  if ( -e "cache\/$sub\.stanza" && !$over_all ) {
   print STDERR "Overwrite cached files?\n",
                "1. NO (default)\n",
                "2. YES\n" if !CACHE;
   my $answer = CACHE ? 1 : <STDIN>;
   $over_all = $answer == 2 ? 1 : 0;
   if ($answer == 1 ) {$results{$sub}->{file} = 1; 
		       next;}
  }

 my $success = system("lwp-request -a -t 30 $STANZA_URL$sub > temp_stanza$$");
 if ($success) {print STDERR "Failed to get a stanza code for $sub\n";
                 next;}
 `mv temp_stanza$$ cache/$sub.stanza`; 
 $results{$sub}->{file} = 1;
 }
 return \%results;
}

1;
