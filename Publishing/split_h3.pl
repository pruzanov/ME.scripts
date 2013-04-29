#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp;

if ($#ARGV != 0) {
    die "SYNTAX: $0 <h3.conf>";
}

my $fin_h3_conf = shift;
my $h3_conf = read_file($fin_h3_conf);

my %subs;

my $track_ids = $1 if $h3_conf =~ m/track source = (.*)$/gm;
my $sub_ids = $1 if $h3_conf =~ m/data source\s*=\s*(.*)$/gm;

my $h1 = $1 if $h3_conf =~ m/(.*?)feature/sm;
my $h2 = $1 if $h3_conf =~ m/data source.*?$(.*?)select\s*=\s*name/sm;
my $h3 = $1 if $h3_conf =~ m/(category.*?$[.]*?)key/sm;
my $h4 = $1 if $h3_conf =~ m/key.*?$(.*?source;)/sm;
my $h5 = $1 if $h3_conf =~ m/(\s*if \(!\$subs.*)/sm;

my @track_ids = split ' ', $track_ids;
my @sub_ids = split ' ', $sub_ids;

if (scalar @track_ids != scalar @sub_ids) {
    die "There are an unequal number of track and submission ID's in this conf!\n";
}

foreach my $i (0 .. scalar @sub_ids - 1) {
    my $sub = $sub_ids[$i];
    my $track = $track_ids[$i];

    if (!exists $subs{$sub}) {
        $subs{$sub}{tracks} = [$track];
        $subs{$sub}{name} = '';
    } else {
        push $subs{$sub}{tracks}, $track;
    }
}

my %newsubs;

foreach (split /^/, $h3_conf) {
    if (m/^\s* [^"]* \"([^"]*)\" = ([0-9]{2,4})\;$/) {
        my $sub = $2;
        my $track_name = $1;
        $subs{$sub}{name} = $track_name;

        my $h3_region = $1 if $_ =~ m/H3K([0-9]{1,2})/;
        if (!exists $newsubs{$h3_region}) {
            $newsubs{$h3_region} = {$sub => {tracks => $subs{$sub}{tracks}, name => $subs{$sub}{name}}};
        } else {
            $newsubs{$h3_region}{$sub} = {tracks => $subs{$sub}{tracks}, name => $subs{$sub}{name}};
        }
    }
}

foreach my $h3_region (sort {$a <=> $b} keys %newsubs) {
    my $subs = $newsubs{$h3_region};

    my $feature_string = 'feature      = ';
    my $track_string   = 'track source = ';
    my $data_string    = 'data source  = ';
    my $select_string  = 'select       = name;';
    my $hash_string    = '		     my %subs = (';

    foreach my $sub (sort {$a <=> $b} keys %{$subs}) {
        my $tracks = $newsubs{$h3_region}{$sub}{tracks};
        my $name = $newsubs{$h3_region}{$sub}{name};

        $feature_string .= "VISTA:$tracks->[0]\n               ";
        $track_string   .= join(' ', @$tracks) . ' ';
        $data_string    .= "$sub " x (scalar @$tracks);
        $select_string  .= "\n               $name \"$name\" = $sub\;";
        $hash_string    .= "$tracks->[0]=>$sub,\n                         ";
    }

    $h1 =~ s/HISMODS_H3.*?_/HISMODS_H3K$h3_region\_/g;

    $feature_string =~ s/\s+$//g;
    $track_string =~ s/\s+$//g;
    $data_string =~ s/\s+$//g;
    $select_string =~ s/\s+$//g;
    $hash_string =~ s/,\s+$/);/g;

    print "# H3K$h3_region\n";
    print "$h1$feature_string\n$track_string\n$data_string$h2$select_string\n$h3";
    print "key          = H3K$h3_region Histone modifications in XXX";
    print "$h4\n$hash_string$h5\n";
}

#use Data::Dumper;
#print Dumper(%newsubs);
