package ParseDir;

use strict;
use constant DEBUG=>1;
use Env qw(PIPE_KEY PIPE_URL HOME);
use Utils::Loader;
use Utils::CitationMerger;
use Utils::MitoFixer;
use Utils::ConfigUpdater;
use Data::Dumper;

=head1 SYNOPSIS

This module should be used for parsing directories with individual submissions
(primarily, modENCODE submissions) wth RNA-Seq data in bam format. Willl merge
(if necessary) bam files into submission_xxx.sorted.bam, cange dmel_mitochondrion_genome into M
and check for validity of MD flag if present. If requested, will generate BigWig files
will also output 'fields files' for using with template_filler

=head1 USAGE

my $parse = ParseDir->new(@dirs);

$parse->validate();
$parse->parse();
$parse->fields();

=head1 AUTHOR

Peter Ruzanov OICR 2012 pruzanov@oicr.on.ca

=cut



sub new {
 my $class = shift;


 # Report flags are 1 = action needed (i.e. MD tag fix) or 0 = no action needed NA if not applicable
 my $self  = bless {files=>{},
                    rules=>{rnaseq_wiggle=>0},
                    tracks=>{},
		    updates=>{},
		    mapfile=>'',
                    updatefile=>'',
	            report=>{}}, ref $class || $class;

 $self->check_reqs;
 $self->init(@_);
 return $self;
}

# Getters (files and rules are handled separatly:

sub mapfile {
 my $self = shift;
 return $self->{mapfile};
}

sub report {
 my $self = shift;
 return $self->{report};
}

# Special function for checking prerequisites
# Check for .rules file, env variables PIPE_KEY PIPE_URL $HOME/Data/nih_spreadsheet
sub check_reqs {
 my $self = shift;
 my $USAGE = <<END;
To use this successfully we need a directory Config with all .conf files for current data provding group
Environment varuiables PIPE_KEY and PIPE_URL set to your ssh key that you use for communication with the
the machhine hosting pipeline data and it's name with path to the dir 
with submissions' data (in numerically id-ed directories) and a file (extension .map) with tab-delimited
sub_id->track_id mapping table that looks like:
[sub_id]	[signal_track_id]	[peak_track_id, if available]

END

 my @reports = ();

 if (!$PIPE_KEY) {push(@reports,"environment variable PIPE_KEY");}
 if (!$PIPE_URL) {push(@reports,"environment variable PIPE_URL");}
 if (! -d "Config") {push(@reports,"Directory Config/ with .conf files");}
 if (! -e "$HOME/Data/nih_spreadsheet") {push(@reports,"Current NIH spreadsheet (~/Data/nih_spreadsheet)");}else{$self->{updatefile} = "$HOME/Data/nih_spreadsheet";}

 my @mapfiles = grep {/\.map$/} `ls *`;
 if (!@mapfiles && @mapfiles == 0){push(@reports,'.map file with sub->track mapping');}else{$self->{mapfile} = $mapfiles[0];}

 if (@reports > 0) {
  my $ERROR = join("\n",($USAGE,"Your configuration is missing these items:",@reports));
  print STDERR $ERROR."\n\n";
  exit;
 }
}

sub init {
 my $self = shift;
 my $load = Utils::Loader->new({-key=>$PIPE_KEY,-remote=>$PIPE_URL});
 my @dirs;

 open(IDS,"<$self->{mapfile}") or die "Couldn't read from id table file";
 while(<IDS>) {
 chomp;
 my @temp = split("\t");
 if (!$temp[2]) {
  $self->{tracks}->{$temp[0]}->{sig}->{$temp[1]}++;
 }else{
  $self->{tracks}->{$temp[0]}->{sig}->{$temp[1]}++;
  $self->{tracks}->{$temp[0]}->{peak}->{$temp[2]}++;
 }
 }
 close IDS;

 open(UPDATE,"<$self->{updatefile}") or die "Couldn't read from update table";
 while(<UPDATE>) {
  chomp;
  my @temp = split("\t");
  if ($temp[17] =~/(\d+) .*by (\d+)/) {
   $self->{updates}->{$2} = $1;
  }
 }
 close UPDATE;


 # Read from each directory, write down names of bam files
 foreach (@_) {
 next if (!/^\d+/);
 if (/(\d+)\-(\d+)/) {
  map {push @dirs,$_} ($1..$2);
  } else {push @dirs,$_;}
 }

 my %tried = (); # To keep track of the dirs we tried to load bam files into

 DIR:
 foreach my $dir (@dirs) {
  if (!$self->{tracks}->{$dir}) {
   print STDERR "No mapping information for submission [$dir], skipping\n";
   next DIR;
  }
  my $dirok = 1;
  print STDERR "Opening dir [$dir]\n" if DEBUG;
  opendir DIR, $dir or $dirok = 0;
   unless ($dirok) {
   print STDERR "Loading for $dir, will take some time....\n";
   $load->load_data($dir);
   $dirok = 1;
   opendir DIR, $dir or $dirok = 0;
     if (! $dirok) {
      warn "Couldn't read from $dir";
      next DIR;
     }
   }
  

 my @files = grep {!/idf|sdrf/i} grep {! -d} readdir (DIR);
 if (!@files || @files == 0) {
  print STDERR "The directory [$dir] seems to be empty, loading....\n";
  $load->load_data($dir);
  
  @files = grep {!/idf|sdrf/i} grep {! -d} readdir (DIR);
 }

 FILE:
 foreach (@files) {
  chomp;
  my $ext = $' if /.*\./;
  my $type;  
  if (! $ext){ next FILE; }

  if ($ext =~ /gff/) {
   $type = 'gffs';
  } elsif ($ext =~ /bw$/) {
   $type = 'bws';
  } elsif ($ext =~ /bam$/) {
   $type = 'bams';
  }

  if (! $type){next FILE;}
  $self->{files}->{$dir}->{$type} = $self->{files}->{$dir}->{$type} ? [@{$self->{files}->{$dir}->{$type}},$_] : [$_];
 }
  closedir DIR;
 }

 #Read rules from the first .rules file (if file is available)
 opendir(THIS,".") or return;
 my @confs = grep {/\.rules/} readdir THIS;
 $self->rules($confs[0]) if (-e $confs[0]);
 closedir THIS;

 #Read track mappings from a subfile if available
 if (my $sfile = $self->rules('subfile')) {
  return unless (-e $sfile);
  open (SUBF,"<$sfile") or warn "Cannot read from track mapping file [$sfile]";
  while(<SUBF>) {
   chomp;
   my @temp = split("\t");
   $self->{tracks}->{$temp[0]}->{sig}->{$temp[1]}++;
   $self->{tracks}->{$temp[0]}->{peak}->{$temp[2]}++ if $temp[2];
  }
  close SUBF;
 }
}


sub files {
 my $self = shift;
 my($dir,$type) = @_;
 return $self->{files}->{$dir}->{$type} ? $self->{files}->{$dir}->{$type} : ();
}

sub validate {
 my $self = shift;

 # check MD flag, report if fix is necessary 
 DIR:
 foreach my $dir (keys %{$self->{files}}){
  my @bamfiles = ();
  if ($self->files($dir,'bams')) {
   @bamfiles = @{$self->files($dir,'bams')};
   $self->{report}->{$dir}->{MG} = scalar(@bamfiles) > 1 ? 1 : 0;
  }

 # Validate bam files:
 BAM:
 foreach my $b (@bamfiles) {
  my @lines = `samtools view $dir/$b | head -n 100000 | grep "MD\:Z" | grep -v "MD\:Z\:7" | grep -v "MD\:Z\:3"`;
  unless(@lines){@lines =  `samtools view $dir/$b | head -n 1`;}
  my @filtered;
  print STDERR "BAM file [$dir/$b] check\n";
  my $xscheck = $lines[0]=~/\tXS\:A\:\S/;
 # check if data are stranded (XS:A: flag)
 $self->{report}->{$dir}->{ST} = $xscheck ? 1 : 0;
 map{if (/MD\:Z\:(\S+)/ && $1=~/\D/){push(@filtered,$_)}} @lines;
 if (@filtered > 0) {
  foreach my $f (@filtered) {
   my @fields = split("\t",$filtered[0]);
   if ($fields[13] && $fields[13] =~ /Z\:(\d+)(\D)/){
    my $read = substr($fields[9],$1,1);
    if ($2 eq $read) {
     $self->{report}->{$dir}->{MD} = 1;
     print STDERR "Submission $dir: MD tag needs fixing for [$b]\n";
     last BAM;
    }
   }
  }
 if (!$self->{report}->{$dir}->{MD}) {
   $self->{report}->{$dir}->{MD} = 0;
   print STDERR "MD tag seems ok for [$dir/$b]\n";
  }
 }else{$self->{report}->{$dir}->{MD} = "NA";}

 # check mitochondrial genome
  my $mito = $self->rules("mito_chrom") || "dmel_mitochondrion_genome";
  my $m = `samtools view -H $dir/$b | grep $mito | wc -l`;
  chomp($m);
  $self->{report}->{$dir}->{MI} = $m  ? 1 : 0;

 # check for EOF message (truncated bam file)
  my @hlines = grep {/EOF/} `samtools view -H $dir/$b 2>\&1`;
  map {warn "<<$_>>" if DEBUG} @hlines;
  $self->{report}->{$dir}->{BM} = @hlines && @hlines > 0 ? 1 : 0; 
 }

 # Validate BigWig files:
 $self->{report}->{$dir}->{BW} = $self->files($dir,'bws') && scalar(@{$self->files($dir,'bws')}) > 1 ? 1 : 0;
 # Remove extra bw files, make sure we have needed bws
 warn "Got tracks for $dir" if($self->{tracks}->{$dir} && DEBUG);
 if ($self->{tracks} && $self->{tracks}->{$dir} && $self->files($dir,'bws')) {
  foreach my $bw (@{$self->files($dir,'bws')}) {
   warn "Checking $dir/$bw" if DEBUG;
   if ($bw=~/protein_binding_site.*bw$/) {
    `rm $dir/$bw`;
     next;
   }
   if ($bw =~/^(\d+)/ && ! $self->{tracks}->{$dir}->{sig}->{$1}) {
    `rm $dir/$bw`;
   }
  }
 }

 # Validate GFF files:
 $self->{report}->{$dir}->{GFF} = $self->files($dir,'gffs') && scalar(@{$self->files($dir,'gffs')}) > 1 ? 1 : 0;
 # Remove extra gff files, make sure we have needed gffs
 if ($self->{tracks} && $self->{tracks}->{$dir} && $self->files($dir,'gffs')) {
  print STDERR "Removing extra gff files\n";
  foreach my $gff (@{$self->files($dir,'gffs')}) {
  print STDERR "Checking [$gff]...\n" if DEBUG; 
  if ($gff =~/^(\d+)/ && ! $self->{tracks}->{$dir}->{peak}->{$1}) {
    
    `rm $dir/$gff`;
   }
  }
 } 
}


# Debugging here:
foreach my $d(keys %{$self->{report}}) {

 print STDERR $d."\n";
 if (ref $self->{report}->{$d}) {
  foreach my $tag (keys %{$self->{report}->{$d}}) {
   print STDERR join ("\t",($tag,$self->{report}->{$d}->{$tag}));
   print STDERR "\n";
  }
 }
}

# check if we have been requested to generate t/u bigwig files
}

sub rules {
 my $self = shift;
 my $arg  = shift;

 if (-e $arg && $arg=~/\.rules/) {
  # we have a rules file!
  open RULES, "awk -F \"\t\" '{if (NF==2){print \$0}}' $arg | " or die "Couldn't read from rules file [$arg]";
  while(<RULES>) {
   chomp;
   my @temp = split("\t");
   $self->{rules}->{$temp[0]} = $temp[1];
  }
  close RULES;
  return;
 }

 # Some default rules defined here or read from a config file
 $self->{rules}->{$arg} ? return $self->{rules}->{$arg} : return undef;
}

# Messy
sub parse {
 my $self = shift;
 my $cite = Utils::CitationMerger->new();
 # Some info collection
 # For now, don't check for stanza date, just use it
 foreach my $dir (keys %{$self->{report}}) {
  $self->{report}->{$dir}->{category} = $self->rules('category');
  $self->{report}->{$dir}->{category} ||= "NA";

  if (! -e "cache/$dir.stanza"){
   $cite->get_cites($dir);
  }
  my @tracks = `grep '\^track' cache/$dir.stanza | sed 's/.*= //'`;
  $self->{report}->{$dir}->{name} = `head -n 1 $dir/*idf* | sed 's/\"//g' | awk -F \"\t\" '{print \$2}'`; # | sed 's/\"//g'`;
  chomp($self->{report}->{$dir}->{name});
  print STDERR "Got name [$self->{report}->{$dir}->{name}]\n" if DEBUG;
  $self->{report}->{$dir}->{name} ||= "NA";
  $self->{report}->{$dir}->{tracks} = [];
  map{chomp; push(@{$self->{report}->{$dir}->{tracks}},$_) if /\d+/;} @tracks;
 }

 my $fixer = Utils::MitoFixer->new();
 # Bam parsing
 DIR:
 foreach my $dir (keys %{$self->{report}}) {
 if (ref $self->{report}->{$dir} && $self->{report}->{$dir}->{BM}) {
  warn "Files in $dir need to be reloaded";
  next;
 }

 # Mitochondria
 print STDERR "Checking mito tag for $dir\n";
 my @bamfiles = $self->files($dir,'bams');

 if (@bamfiles > 0) {
 
 my $merge_name = "submission_$dir.sorted.bam";
 $self->{report}->{$dir}->{bamfile} = $merge_name;
 
 if ($self->{report}->{$dir}->{MI}) {
  warn "Fixing mitochondria id for $dir";
  map{$fixer->fix_mito("$dir/$_")} (@bamfiles);
 }

 # MD tag
 if (@bamfiles > 0 && $self->{report}->{$dir}->{MD}) {
  print $self->{report}->{$dir}->{MD} =~/1/ ? "Need to fix MD tag for $dir\n" : "No need to fix MD tag for $dir\n";
 }

 # TODO Strand processing 

 # Merge bam files if there are multiple ones
 
 if ($self->{report}->{$dir}->{MG}) {
  if (! -e "$dir/$merge_name"){
   warn "Merging for $dir...";
   my $merge_string;
   map{$merge_string.=" $dir/$_"} @{$self->files($dir,'bams')};
  
   `samtools merge $dir/$merge_name $merge_string`;
  }
  
 } else {
  if (! -e "$dir/$merge_name" && -e "$dir/$self->{files}->{$dir}->{bams}->[0]"){
   `mv $dir/$self->{files}->{$dir}->{bams}->[0] $dir/$merge_name`;
   my $idx = "$dir/".$self->{files}->{$dir}->{bams}->[0];
   $idx.=".bai";
   `rm $idx` if -e $idx;
  }
 }

 # Update names for files:

 $self->{files}->{$dir}->{bams}->[0] = $merge_name; 
 my $merge_bw = $merge_name =~ /\.bam$/ ? $`.".bw" : $merge_name.".bw";
 $self->{files}->{$dir}->{bws}->[0] = $merge_bw;

 # TODO Temporary, need to customize:
  
  if ($self->rules('rnaseq_wiggle') && $self->rules('rnaseq_wiggle')==1 ){ 
   my $basename = $merge_name =~ /\..*$/ ? $` : $merge_name;
   `./GFF2WIG.pl $basename \"$basename RNA-Seq\" $dir/$merge_name`;

   my $wig = $merge_name;
   $wig =~ s/bam$/t\.wig/;
   my $bw = $wig;
   $bw =~ s/wig$/bw/;

   my $chromsizes = $self->rules('chromsizes') || "~/Data/FlyData/chrom.sizes";
   print STDERR "Chromsizes read from [$chromsizes]\n" if DEBUG;
   foreach ("t","u") {
    my $wig = $basename.$_.".wig";
    my $bw  = $basename.$_.".bw";
 
    `wigToBigWig.pl $dir/$wig $chromsizes $dir/$bw`;
    `rm $dir/$wig`;
   }
  }
 } # have bamfiles 
 } # foreach dir


 # Update Config files

 my $updater = Utils::ConfigUpdater->new({-ids=>$self->{tracks},-ups=>$self->{updates}});
 $updater->update($self->{files});


 # Generate bigwig files if a. Data are stranded b. unique/total read density requested
 # Compose load gff

}

sub fields {
 my $self = shift;
 # generate fields table for using with template_filler

 foreach my $dir (keys %{$self->{report}}) {
  if ($self->files($dir,'bams') && $self->{report}->{$dir}->{bamfile}) {
   print join("\t",($self->rules('bam_dir').$self->{report}->{$dir}->{bamfile},$self->{report}->{$dir}->{name},$dir,join(" ",(@{$self->{report}->{$dir}->{tracks}})),$self->{report}->{$dir}->{category}));
  } elsif ($self->{files}->{$dir}->{bws} && -e "$dir/$self->{files}->{$dir}->{bws}->[0]") {
   my $safe_plug = $self->{report}->{$dir}->{name};
   $safe_plug =~ s/\s/_/g;
   print join("\t",($safe_plug,$self->{report}->{$dir}->{name},$dir,join(" ",(@{$self->{report}->{$dir}->{tracks}})),$self->{report}->{$dir}->{category},$self->{report}->{$dir}->{tracks}->[0]));
  } elsif ($self->{files}->{$dir}->{gffs} && -e "$dir/$self->{files}->{$dir}->{gffs}->[0]") {
   print "Directory [$dir] contains gff files only, need to load features into mysql and configure manually";
  }
  print "\n";
 }

}

1;
