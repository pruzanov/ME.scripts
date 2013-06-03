#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use List::MoreUtils qw(lastidx firstidx);

=pod

=head1 NAME

add_subtracks.pl - Add new subtracks to a GBrowse VISTA stanza.

=head2 SYNOPSIS

add_subtracks.pl [STANZAFILE] [MAPFILE]

=head3 DESCRIPTION

add_subtracks.pl accepts a SINGLE GBrowse stanza and a MAPFILE as input.

MAPFILE is a tab-delimited plain text file specifying the details of the new
subtracks to be added to the stanza.

[Name in GBrowse]	[modENCODE Submission ID]	[Signal track ID]	[Peak track ID]
Track.1	1001	16353	16356
Track.2	1002	36136	13563
.	.	.	.
.	.	.	.
.	.	.	.

=cut

################################################################################
# A "subtrack" is a hash keyed as such:
# {
# 	"Name" => $name,
# 	"SubID" => $subID,
# 	"SignalID" => $trackID,
# 	"PeakID" => $peakID
# };
################################################################################

################################################################################
# update_stanza: \@STANZA \@SUBTRACKS
# Where:
#
# 	@STANZA is a list of strings, each string a line from a GBrowse .conf
# 	stanza. 
#
# 	The stanza should start from the track definition "[TRACK_NAME]",
# 	and contain the fields "feature", "track source", "data source", "select",
# 	and "link", IN THE ORDER GIVEN.
#
#   Use this function only to UPDATE an existing stanza, NOT CREATE a new
#   one.
#
#	@SUBTRACKS is a list of hashrefs, keyed by Name, SubID, SignalID, PeakID.
################################################################################
# Prints an updated stanza with new subtracks added to STDOUT.
################################################################################
sub update_stanza {
    my $index = 0;
    my ($stanza, $subtracks) = @_;
    #print STDERR @{$stanza};

    ######################################################
    # Generate new stanza lines here
    ######################################################

    my @vista_lines;
    my $track_ids = '';
    my $data_ids = '';
    my @select_lines;
    my @subs_lines;

    foreach (@{$subtracks}) {

        # VISTA:nnnnn lines
        push @vista_lines, sprintf "\t\tVISTA:%s\n", $_->{"SignalID"};

        # New IDs to be appended to "track source" line
        if ($_->{"SignalID"} != $_->{"PeakID"}) {
            $track_ids .= "$_->{SignalID} $_->{PeakID} ";
        } else {
            $track_ids .= "$_->{SignalID} ";
        }
        chomp $track_ids;

        # New IDs to be appended to "data source" line
        if ($_->{"SignalID"} == $_->{"PeakID"}) {
            $data_ids .= "$_->{SubID} "
        } else {
            $data_ids .= "$_->{SubID} $_->{SubID} "
        }
        chomp $data_ids;

        # "select" lines
        push @select_lines, sprintf "\t\t$_->{Name} \"$_->{Name}\" = $_->{SubID};\n";

        # "subs" hash kv-pairs
        push @subs_lines, sprintf "\t\t\t$_->{SignalID}=>$_->{SubID},\n";
    }

    ######################################################
    # End stanza lines
    ######################################################

    ## Add new VISTA:nnnnn lines.
    my $lastidx = lastidx { /VISTA:[0-9]{1,5}/ } @{$stanza};
    splice @{$stanza}, $lastidx, 0, @vista_lines;

    ## Update the "track source" field.
    chomp $stanza->[firstidx { /^track source/ } @{$stanza}];
    $stanza->[firstidx { /^track source/ } @{$stanza}] .= " $track_ids\n";

    ## Update the "data source" field.
    chomp $stanza->[firstidx { /^data source/ } @{$stanza}];
    $stanza->[firstidx { /^data source/ } @{$stanza}] .= " $data_ids\n";

    ## Update the "select" field.
    $lastidx = lastidx { /.+\s*".+"\s*=\s*[0-9]{1,4}/ } @{$stanza};
    splice @{$stanza}, $lastidx, 0, @select_lines;

    $lastidx = lastidx { /[0-9]{1,5}\s*=>\s*[0-9]{1,4}\s*\);/ } @{$stanza};
    splice @{$stanza}, $lastidx, 0, @subs_lines;

    print STDOUT @{$stanza};
}

################################################################################
# parse_mapfile \@LINES
# Where:
#
# 	@LINES is a list of strings, each string a line from the user-supplied
# 	mapfile. One line represents one NEW subtrack to be added to the stanza.
#
################################################################################
# Returns an arrayref of hashrefs, each hash containing the submission details for
# each new subtrack
################################################################################
sub parse_mapfile {
    my $lines = shift;
    my @new_subs;
    foreach (@{$lines}) {
        my @fields = split('\t', $_);
        chomp @fields;
        my $sub = {
            "Name" => $fields[0],
            "SubID" => $fields[1],
            "SignalID" => $fields[2],
            "PeakID" => $fields[3]
        };
        push @new_subs, $sub;
    }
    return \@new_subs;
}

open(my $stanzafh, "<", $ARGV[0]);
open(my $mapfh, "<", $ARGV[1]);

my @stanza_lines;
while (<$stanzafh>) {
    push @stanza_lines, $_;
}

my @mapfile_lines;
while (<$mapfh>) {
    push @mapfile_lines, $_;
}

update_stanza(\@stanza_lines, parse_mapfile(\@mapfile_lines));
