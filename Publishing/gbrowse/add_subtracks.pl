#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;

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

    # Find the "feature" field.
    until ($stanza->[$index] =~ /^feature/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }

    # Find the last VISTA: parameter.
    while ($stanza->[$index] =~ /\s*VISTA:[0-9]{1,5}/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }

    # We are at the line after the last VISTA: parameter in the stanza.
    # Insert our new lines here.
    foreach (@{$subtracks}) {
        printf STDOUT "\t\tVISTA:%s\n", $_->{"SignalID"};
    }

    # Update the "track source" field.
    chomp $stanza->[$index];
    foreach (@{$subtracks}) {
        print STDOUT "$stanza->[$index] $_->{SignalID} $_->{PeakID}\n";
    }

    # Skip over the old "track source" line.
    $index++;

    # Find "data source" field.
    until ($stanza->[$index] =~ /^data source/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }

    # Update it.
    chomp $stanza->[$index];
    foreach (@{$subtracks}) {
        print STDOUT "$stanza->[$index] $_->{SubID}\n"
    }

    # Skip over the old "data source" line.
    $index++;

    # Find "select" field.
    until ($stanza->[$index] =~ /^select/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }
    print STDOUT "$stanza->[$index]";
    $index++;

    # Find the last parameter in this field.
    while ($stanza->[$index] =~ /.+\s*".+"\s*=\s*[0-9]{1,4}/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }

    # Add our new subtrack selections.
    foreach (@{$subtracks}) {
        printf STDOUT "\t\t$_->{Name} \"$_->{Name}\" = $_->{SubID};\n";
    }

    # Find "link" field.
    until ($stanza->[$index] =~ /^link/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }
    print STDOUT "$stanza->[$index]";
    $index++;

    # Find "%subs" hash.
    until ($stanza->[$index] =~ /.*%subs.*/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }

    # Print everything out until the very last key-value pair.
    until ($stanza->[$index] =~ /[0-9]{1,5}\s*=>\s*[0-9]{1,4}\s*\);/) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }

    # Add our new subtrack links.
    foreach (@{$subtracks}) {
        printf STDOUT "\t\t\t$_->{SignalID}=>$_->{SubID},\n";
    }
    print STDOUT "$stanza->[$index]";
    $index++;

    until ($index > $#{$stanza}) {
        print STDOUT "$stanza->[$index]";
        $index++;
    }

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
