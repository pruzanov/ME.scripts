#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;

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
# Returns an updated stanza with new subtracks added as a list of strings.
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

my @lines;
while (<>) {
    push @lines, $_;
}

my @new;
push @new, {
    "Name" => "Test",
    "SubID" => 4242,
    "SignalID" => 69696,
    "PeakID" => 93939
};
update_stanza(\@lines, \@new);
