#!/usr/bin/perl

use strict;
use warnings;

# ps_geoemail.pl - Process Submission: GEO Email
# TODO: Explain motivation, input file format.

use Getopt::Long;
use File::Slurp;    # Clean way of reading an entire file at once.
use LWP::Simple;    # To grab data off of GEO web pages.
use WWW::Mechanize; # To submit forms on the DCC and attach the GEO ID's.
use Data::Dumper;

my $ssh_key = "/home/pruzanov/cron/flyking-rsync-key"; # You should change this to your own ssh key
my($login,$password,$subs,$fin_geo_email);
my $result = GetOptions ('geo_email=s'=> \$fin_geo_email,
                         'subs=s'     => \$subs,
                         'login=s'    => \$login,    # working (output) directory
                         'password=s' => \$password); # directory with temporary GATK files


use constant DEBUG=>1;

# Takes in a string and returns a shaved (more than just trimmed!) version of
# the string, stripping any spaces.
sub shave {
    my $str = shift;
    # Remove all whitespace. (\s = any whitespace char).
    $str =~ s/\s//g;
    return $str;
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
if (!$fin_geo_email || !$subs || !$login || !$password) {
    print STDERR "This script expects the following parameters:\n";
    print STDERR "--geo_email=[file containing the text from a GEO email with GEO ID's]\n";
    print STDERR "--subs=[comma-delimited list of submissions that need GEO ids attached]\n";
    print STDERR "--login=[DCC pipeline login]\n";
    print STDERR "--password=[DCC pipeline password].\n";
    die "Check your parameters and launch again";
}

my @subs = split(",",$subs);
my %subs = map{$_=>1} @subs;

my $geo_email = read_file($fin_geo_email);
print Dumper($geo_email) if DEBUG;
# Strip the email text file of unneccesary lines, ie. dashed lines, and ensure
# that each line begins with either a GSE or GSM ID, ie. each line contains
# all the information needed for one submission.

$geo_email =~ s/^\s+|\s+$//gm;
$geo_email =~ s/\n((?!GSM|GSE|modENCODE_submission).+$)/$1/gm;
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
foreach (split /\n/, $geo_email) {
    # If the line starts with a GSE ID, then we fetch its page from GEO and
    # parse it to determine the submission to which this ID and subsequent GSM
    # ID's belong to.
    if (/modENCODE_submission_(\d+)\:\s+(GSE\d+)/) {
         $sub = $1;
         my $gse = $2;
         print "[$sub] $gse belongs to submission $sub.\n";
         $ids{$sub} = {gse => $gse};
         next;
    }

    if (m/^GSE[0-9]+/) {
        my $gse_id = $&;
        $gse_id = shave($gse_id);

        my $has_sub;
        map{$has_sub = $_ if $ids{$_}->{gse} eq $gse_id } (keys %ids);

        if (!$has_sub) {
        # Fetch the page.
        my $url = $base_geo_url . $gse_id;
        print "[Main] Fetching page for $gse_id...\n";
        my $geo_page = get($url) or die "Could not fetch $url: $!";
        sleep_dots(3);
        
        # It should contain an instance of a string "modENCODE_submission_"
        # which tells us what submission the GSE ID belongs to. If it exists,
        # we parse it for the ID otherwise something is wrong so we die.
        if ($geo_page =~ m/modENCODE_submission_([0-9]{2,4})/) {
            $sub = $1;
            #$sub =~ s/modENCODE_submission_//;

            print "[$sub] $gse_id belongs to submission $sub.\n";
            $ids{$sub}->{gse} ||= $gse_id;
        } else {
            die "Could not find mention of a modENCODE submission ID in $url";
        }
       } else {
         $sub = $has_sub;
       }
    }
    # If the line starts with a GSM ID, we fetch its page and parse it to
    # determine what experiment number it belongs to.
    elsif (m/^GSM[0-9]+/) {
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
        my $expt_number;
        if ($geo_page =~ m/Input.{0,1}Rep.{0,1}(\d+)/i) {
            $expt_number = $1;
            print STDERR "[$sub] $gsm_id belongs to Input number $expt_number.\n";
            $ids{$sub}->{input}->{$expt_number} = $gsm_id;
        } elsif ($geo_page =~ m/ChIP.{0,1}Rep.{0,1}(\d+)/i) {
            $expt_number = $1;
            print STDERR "[$sub] $gsm_id belongs to ChIP number $expt_number.\n";
            $ids{$sub}->{chip}->{$expt_number} = $gsm_id; 
        } else {
            die "Could not find mention of an experiment number in $url";
        }
    }
    # If the line contains neither a GSM or GSE ID, then the GEO email may
    # contain extra data or be badly formatted. It should be edited manually
    # to comply with input expectations in that case.
    else {
       die "Following line began with neither of GSE, GSM or modENCODE:\n$_";
    }
}

# Now we download the SDRF file for each submission from
# modencode-www1.oicr.on.ca and parse it for the order of the experiments.
# Using the data we parsed from GEO, this will let us construct a GSM ID
# string with ID's in the correct order as we know what GSM ID corresponds to
# each experiment number.

foreach my $sub (sort {$a <=> $b} keys %ids) {
    next if !$subs{$sub}; # If we don't have submission on the list, do not fetch SDRF, do not attach ids
    # Download the SDRF using scp and save in the current directory quietly.
    print "[$sub] Downloading SDRF...\n";
    my @SDRF_files = grep {/SDRF/i} `ssh -i $ssh_key -x modencode-www1.oicr.on.ca "ls /modencode/raw/data/$sub/extracted/*"`;
    my $SDRF;

    if (@SDRF_files && @SDRF_files > 0) {
      $SDRF = $1 if $SDRF_files[0]=~/(sdrf\S*)$/i;
    } else {
      warn "Couldn't load sdrf for $sub\n";
      next;
    }
    
    if(! -e "./$sub.sdrf.txt") {
    `scp -q -i $ssh_key "modencode-www1.oicr.on.ca:/modencode/raw/data/$sub/extracted/*$SDRF" ./$sub.sdrf.txt`;
    }
    # TODO: Check if scp returns -1.

    # Read in all the lines of the SDRF file.
    my @sdrf = read_file("$sub.sdrf.txt");
    print STDERR @sdrf > 0 ? "Loaded SDRF\n" : "SDRF Couldn't load\n"; 
    # Now we parse the SDRF file and look for experiment numbers at the start
    # of each line. They are in order so if we parse the SDRF line by line,
    # we'll know what order the GSM ID's should be in.
    $ids{$sub}->{gsm} = '';
    my @gsms = ();
    shift @sdrf; # remove the header
    foreach (@sdrf) {
        if (m/Rep.{0,1}(\d+)\t/i) {
            my $expt_number = $1;
            my $head = $`;
            print STDERR "HEAD: $head\n" if DEBUG;
            $head =~s/.*\s//;
            
            my $gsm_id = $head=~/input/i ? $ids{$sub}->{input}->{$expt_number} : $ids{$sub}->{chip}->{$expt_number};
            push(@gsms,$gsm_id);
        } else {
          print STDERR "Could not find replicate info in SDRF\n" if DEBUG;
        }
        $ids{$sub}->{gsm} = join(",",@gsms);
    }
}
print STDERR Dumper(%ids) if DEBUG;

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
        $mech->submit_form(form_number => 1, fields => { login => $login,
                                                      password => $password });
    }

    if ($mech->content() =~ m/A set of GEO ids has already been successfully attached to this project/i) {
        print "[$sub] GEO ID's already present!\n";
        print "[$sub] Must add them manually if you'd like to overwrite existing ID's.\n";
        print "[$sub] |`- GSE: " . $ids{$sub}->{gse} . "\n";
        print "[$sub]  `- GSM: " . $ids{$sub}->{gsm} . "\n";
        
        if ($sub ~~ @subs) {
            push @manual_attach, $sub;
            next;
        }
    } else {
        print "[$sub] Creating $ids{$sub}->{gse} and $ids{$sub}->{gsm}...\n";
        #$mech->submit_form(form_number => 1, fields => { gse => $ids{$sub}{gse}, gsms => $ids{$sub}{gsm} });
        $mech->form_number(1);
        $mech->field('gse', $ids{$sub}->{gse});
        $mech->field('gsms', $ids{$sub}->{gsm});
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
        print "[$sub] " . $ids{$sub}->{gse} . "\n";
        print "[$sub] " . $ids{$sub}->{gsm} . "\n";
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
