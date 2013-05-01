#!/usr/bin/perl

use strict;
use warnings;

use GetOpt::Long;
use WWW::Mechanize;

my $gbrowse_date = '';
my $geo_date = '';
GetOptions('gbrowse=s' => \$gbrowse_date, 'geo=s' =? \$geo_date);

if ($#ARGV < 1) {
    print STDERR "Not enough parameters were specified!\n";
    die "USAGE: $0 [--gbrowse <date>] [--geo <date>] <sub1> <sub2> ... <subn>";
} elsif ($gbrowse_date eq '' and $geo_date eq '') {
    print STDERR "Must specify publication to at least GBrowse or GEO!\n";
    die "USAGE: $0 [--gbrowse <date>] [--geo <date>] <sub1> <sub2> ... <subn>";
} elsif ($gbrowse_date !~ m/^20[0-9]{2}-[01][0-9]-[0123][0-9] [012][0-9]:[0-5][0-9]$/ or
         $geo_date !~ m/^20[0-9]{2}-[01][0-9]-[0123][0-9] [012][0-9]:[0-5][0-9]$/) {
    print STDERR "Date must be correct and in the YYYY-MM-DD HH:MM format.\n";
    die "USAGE: $0 [--gbrowse <date>] [--geo <date>] <sub1> <sub2> ... <subn>";
}

my @subs = @ARGV;
my $mech = WWW::Mechanize->new(autocheck => 1);

my $base_url = "http://submit.modencode.org/submit/pipeline/publish/";

foreach my $sub (@subs) {
    my $url = $base_url . $sub;
    $mech->get($url);

    if ($mech->uri() =~ m/login/i) {
        print "[Main] Logging into modENCODE DCC...\n";
        $mech->submit_form(form_number => 1, fields => { login => 'aramadhan', password => '$72831TesFF]Mod' });
    }

    if ($gbrowse_date) {
        $mech->get($url);
        print "[$sub] Setting GBrowse publication date to $gbrowse_date...\n";
        $mech->form_id('publish_form');
        $mech->field('PublishToGbrowse_date', $gbrowse_date);
        $mech->click_button(value => 'Publish to GBrowse');
        print "[$sub] GBrowse publication date set successfully.\n";
    }
    
    if ($geo_date) {
        $mech->get($url);
        print "[$sub] Setting GEO publication date to $geo_date...\n";
        $mech->form_id('publish_form');
        $mech->field('PublishToGEO_date', $geo_date);
        $mech->click_button(value => 'Publish to GEO');
        print "[$sub] GEO publication date set successfully.\n";
    }
}
