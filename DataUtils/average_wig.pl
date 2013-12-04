#!/usr/bin/perl -w


# A wrapper for average_zscore script

use strict;

my @dirs;

my @args = @ARGV;

if (@args) {
 foreach (@args) {
  next if (!/^\d+/);
  if (/(\d+)\-(\d+)/) {
   map {push @dirs,$_} ($1..$2);
  } else {push @dirs,$_;}
 }
}else{
 opendir(THIS,".") or die "Couldn't read from current dir";
 @dirs = grep {/^\d+/} readdir(THIS);
 closedir THIS;
}

foreach my $d (@dirs) {
 
 opendir(DIR,$d) or die "Cannot read from Directory [$d]";
 my @files = grep{/cleaned\.wig/} grep{/\.wig$/} readdir(DIR);
 rewinddir(DIR);
 my @mfiles= grep{/mean\.wig/} readdir(DIR);
 closedir DIR;

 if (@mfiles && @mfiles > 0){print STDERR "There's a mean file already, skipping $d\n";
                             next;}


 if (@files > 1) {
  my $name = &match(\@files);
  $name = "Averaged" if length($name) == 0;
  my $mname = $name."mean.wig";
  print STDERR "Will write to $mname\n";
   
  my $argstring = "";

   foreach my $file (@files) {
    $argstring.=" $d/$file";
   }

   `./average_zscore_from_wig_variable.pl $name $argstring`;
   #`mv *mean.wig $d/`;

  }

}
 

sub match {
 my @strings = @{shift @_};
 my($length,$count,%strings);
 $length = 0;
 $count  = 0;

 foreach my $string (@strings) {
  $strings{$count++} = [split //,$string];
  $length = scalar(@{$strings{$count-1}}) if $length == 0;
  $length = $length > scalar(@{$strings{$count-1}}) ? scalar(@{$strings{$count-1}}) : $length;
 }
 my $result = "";

 LETTER:
 for (my $i = 0; $i < $length; $i++) {
  map {if($strings{$_}->[$i] ne $strings{0}->[$i]){last LETTER;}} (sort {$a<=>$b} keys %strings);
  $result.=$strings{0}->[$i];
 }

 return $result;
}
