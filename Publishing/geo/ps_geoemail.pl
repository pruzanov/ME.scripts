#!/usr/bin/perl

use strict;
use warnings;

# ps_geoemail.pl - Process Submission: GEO Email
# TODO: Explain motivation, input file format.

use File::Slurp;    # Clean way of reading an entire file at once.
use LWP::Simple;    # To grab data off of GEO web pages.
use WWW::Mechanize; # To submit forms on the DCC and attach the GEO ID's.

# Takes in a string and returns a shaved (more than just trimmed!) version of
# the string, stripping any spaces.
# The reason for this sub is because it seems that regular expressions nor
# chomping would remove the one tailing space character on strings I get using
# LWP::Simple. So until I figure out why, I'll continue to use this hack.
sub shave {
    my $str = shift;
    my $shaved_str = '';
    
    foreach (split "", $str) {
        if ($_ ne ' ') {
            $shaved_str .= $_;
        }
    }

    return $shaved_str;
}

# Prints one dot/period per second for n seconds. Also sleeps for n seconds.
# Useful to show impatient users something while the program sleeps.
sub sleep_dots {
    my $dots = shift;
    $| = 1; # Turn on autoflush for this to work.

    print "[Main] Waiting $dots seconds";
    while ($dots > 0) {
        sleep 1;
        print ".";
        $dots--;
    }
    print "\n";
    $| = 0; # We're done with autoflush so turn it off now.
}

# Explain syntax and die if not given an input text file and at least one
# submission ID.
if ($#ARGV < 1) {
    print STDERR "This script expects at least two arguments, the first a\n";
    print STDERR "file containing the text from a GEO email with GEO ID's\n";
    print STDERR "or alternatively, just each ID on a separate line.\n";
    print STDERR "The rest of the arguments should be individual\n";
    print STDERR "submission ID's for the script to attach GEO ID's for.\n";
    die "SYNTAX: $0 <geo_email.txt> <sub1> <sub2> ... <subn>";
}

my $fin_geo_email = shift;
my @subs = @ARGV;

my $geo_email = read_file($fin_geo_email);

# Strip the email text file of unneccesary lines, ie. dashed lines, and ensure
# that each line begins with either a GSE or GSM ID, ie. each line contains
# all the information needed for one submission.

$geo_email =~ s/^\s+|\s+$//gm;
$geo_email =~ s/\n((?!GSM|GSE).+$)/$1/gm;
$geo_email =~ s/[-]{2,}$//gm;

my $base_geo_url = 'http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=';

# TODO: Explain the structure of %ids.
my %ids = ();
my $sub = 0;

# We now go through each line of the email and construct a hash %ids
# containing the GSE ID for each submission and the GSM ID along with its
# corresponding experiment number for each submission. This, along with the
# SDRF file will allow us to construct a GSM ID string with the ID's in the
# correct order so that the ID's can be properly attached.
foreach (split /^/, $geo_email) {
    # If the line starts with a GSE ID, then we fetch its page from GEO and
    # parse it to determine the submission to which this ID and subsequent GSM
    # ID's belong to.
    if (m/^GSE[0-9]+\s/) {
        my $gse_id = $&;
        $gse_id = shave($gse_id);

        # Fetch the page.
        my $url = $base_geo_url . $gse_id;
        print "[Main] Fetching page for $gse_id...\n";
        my $geo_page = get($url) or die "Could not fetch $url: $!";
        sleep_dots(3);
        
        # It should contain an instance of a string "modENCODE_submission_"
        # which tells us what submission the GSE ID belongs to. If it exists,
        # we parse it for the ID otherwise something is wrong so we die.
        if ($geo_page =~ m/modENCODE_submission_[0-9]{2,4}/) {
            $sub = $&;
            $sub =~ s/modENCODE_submission_//;

            print "[$sub] $gse_id belongs to submission $sub.\n";
            $ids{$sub} = {gse => $gse_id};
        } else {
            die "Could not find mention of a modENCODE submission ID in $url";
        }
    }
    # If the line starts with a GSM ID, we fetch its page and parse it to
    # determine what experiment number it belongs to.
    elsif (m/^GSM[0-9]+\s/) {
        my $gsm_id = $&;
        $gsm_id = shave($gsm_id);

        # Fetch the page.
        my $url = $base_geo_url . $gsm_id;
        print "[Main] Fetching page for $gsm_id...\n";
        my $geo_page = get($url) or die "Could not fetch $url: $!";
        sleep_dots(3);

        # The page should contain an instance of an "expt." string, which will
        # tell us the experiment number for this GSM ID. If it doesn't exist,
        # we cannot continue so we die.
        if ($geo_page =~ m/expt\.[0-9]+\s*/) {
            my $expt_number = $&;
            $expt_number =~ s/expt\.//g;
            $expt_number = shave($expt_number);

            print "[$sub] $gsm_id belongs to experiment number $expt_number.\n";
            $ids{$sub}{$expt_number} = $gsm_id;
        } else {
            die "Could not find mention of an experiment number in $url";
        }
    }
    # If the line contains neither a GSM or GSE ID, then the GEO email may
    # contain extra data or be badly formatted. It should be edited manually
    # to comply with input expectations in that case.
    else {
        die "Following line began with neither GSE nor GSM:\n$_";
    }
}

# Now we download the SDRF file for each submission from
# modencode-www1.oicr.on.ca and parse it for the order of the experiments.
# Using the data we parsed from GEO, this will let us construct a GSM ID
# string with ID's in the correct order as we know what GSM ID corresponds to
# each experiment number.
foreach my $sub (sort {$a <=> $b} keys %ids) {
    # Download the SDRF using scp and save in the current directory quietly.
    print "[$sub] Downloading SDRF...\n";
    system("scp", "-q", "modencode-www1.oicr.on.ca:/modencode/raw/data/$sub/extracted/*SDRF.txt", "./$sub.sdrf.txt");
    # TODO: Check if scp returns -1.

    # Read in all the lines of the SDRF file.
    my @sdrf = read_file("$sub.sdrf.txt");
    
    # Now we parse the SDRF file and look for experiment numbers at the start
    # of each line. They are in order so if we parse the SDRF line by line,
    # we'll know what order the GSM ID's should be in.
    $ids{$sub}{gsm} = '';
    foreach (@sdrf) {
        if (m/^expt\.[0-9]+/) {
            my $expt_number = $&;
            $expt_number =~ s/expt\.//g;
            $expt_number = shave($expt_number);
            my $gsm_id = $ids{$sub}{$expt_number};

            $ids{$sub}{gsm} .= $gsm_id . ", ";
        }
    }

    # We formatted the GSM ID string with commas and spaces so now we just
    # remove the very last one.
    $ids{$sub}{gsm} =~ s/\, $//g;
}

# Now we use WWW::Mechanize to go onto the modENCODE DCC and attach the ID's
# for each submission.
# TODO: Explain what it does and when it requires intervention.

my $mech = WWW::Mechanize->new(autocheck => 1);

my @manual_attach = ();
my @not_found = ();

my $base_dcc_url = "http://submit.modencode.org/submit/curation/attach_geoids/";

foreach my $sub (@subs) {
    if (!exists $ids{$sub}) {
        print "[WARN] Submission $sub does not exist in GEO email. Skipping!\n";
        push @not_found, $sub;
        next;
    }

    my $url = $base_dcc_url . $sub;
    $mech->get($url);

    if ($mech->uri() =~ m/login/i) {
        print "[Main] Logging into modENCODE DCC...\n";
        $mech->submit_form(form_number => 1, fields => { login => 'rdevilla',
                password => 'nope' });
    }

    if ($mech->content() =~ m/A set of GEO ids has already been successfully attached to this project/i) {
        print "[$sub] GEO ID's already present!\n";
        print "[$sub] Must add them manually if you'd like to overwrite existing ID's.\n";
        print "[$sub] |`- GSE: " . $ids{$sub}{gse} . "\n";
        print "[$sub]  `- GSM: " . $ids{$sub}{gsm} . "\n";
        
        if ($sub ~~ @subs) {
            push @manual_attach, $sub;
            next;
        }
    } else {
        print "[$sub] Creating $ids{$sub}{gse} and $ids{$sub}{gsm}...\n";
        #$mech->submit_form(form_number => 1, fields => { gse => $ids{$sub}{gse}, gsms => $ids{$sub}{gsm} });
        $mech->form_number(1);
        $mech->field('gse', $ids{$sub}{gse});
        $mech->field('gsms', $ids{$sub}{gsm});
        $mech->click_button(name => 'commit');
    
        print "[$sub] Attaching GEO ID's...\n";
        $mech->click_button(number => 1);
        print "[$sub] GEO ID's attached successfully.\n";
    }

    delete $ids{$sub};
}

if (@manual_attach) {
    print "[WARN] Must attach following ID's manually:\n";
    foreach my $sub (@manual_attach) {
        print "[$sub] " . $ids{$sub}{gse} . "\n";
        print "[$sub] " . $ids{$sub}{gsm} . "\n";
        delete $ids{$sub};
    }
}

my $unattached_no_request = '';
foreach my $sub (sort {$a <=> $b} keys %ids) {
    $unattached_no_request .= $sub . ", ";
}
$unattached_no_request =~ s/, $//g;

my $unattached_not_found = '';
foreach my $sub (@not_found) {
    $unattached_not_found .= $sub . ", ";
}
$unattached_not_found =~ s/, $//g;

if ($unattached_no_request ne '') {
    print "[WARN] Submissions found in GEO email but not requested to have their ID's attached:\n";
    print "[WARN] $unattached_no_request\n";
}

if ($unattached_not_found ne '') {
    print "[WARN] Submissions requested to have their ID's attached but not found in email:\n";
    print "[WARN] $unattached_not_found\n";
}
