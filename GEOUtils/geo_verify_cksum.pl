#!/usr/bin/perl -w

use strict;
use warnings;

use syntax 'junction';

use Data::Dumper;
use File::Path;

=pod

=head1 NAME

geo_verify_cksum.pl - Verify the integrity of GEO tarballs

=head1 SYNOPSIS

geo_verify_cksum.pl [SOFT] [TARBALL]

=head1 DESCRIPTION

geo_verify_cksum.pl will read through the specified SOFT file and verify that the
checksums specified within match the actual computed checksums of files within
the specified TARBALL.

=cut

use constant SCRATCH_DIR => "/tmp/geo_verify_cksum";

# read_soft SOFTNAME
#
# Read the SOFT file given by SOFTNAME into an arrayref and return it.
#
# ARGUMENTS:
# SOFTNAME :: String
sub read_soft {
    my $softname = shift;
    open(my $fh, "<", $softname) or die($!);
    chomp(my @lines = <$fh>);
    close($fh);
    return \@lines;
}

# get_cksums SOFTLINES
#
# Find all '*_checksum =' lines in a SOFT and return a hashref
# of filenames to their checksums.
sub get_cksums {
    my $soft = shift;
    my %cksums;

    foreach my $i (0 .. $#{$soft}) {
        my $ln = $soft->[$i];
        if ($ln =~ m/^!Sample_\w+_file_[0-9]+\s*=\s*(.*)$/) {
            my $fname = $1;
            $i += 2;
            $ln = $soft->[$i];
            if ($ln =~ m/checksum/) {
                $cksums{$fname} = (split(" = ", $ln))[1];
            }
        }
    }
    return \%cksums;
}

# unpack_tar TARBALL
#
# Unpacks TARBALL into SCRATCH_DIR so that we can compute checksums for
# the files within. Returns the name of the directory we extracted to.
sub unpack_tar {
    my $tarball = shift;
    my $dirn = SCRATCH_DIR . "/$tarball";
    print STDERR "$dirn\n";

    mkpath($dirn) or die($!);
    my @cmd = ("tar", "xvzf", $tarball, "-C", $dirn);
    system(@cmd) == 0 or die($!);
    return $dirn;
}

# clean_dir DIRNAME
#
# Removes the directory specified by DIRNAME.
sub clean_dir {
    my $dirn = shift;
    print STDERR "$dirn\n";
    #remove_tree($dirn, {
    #        safe => 1,
    #        verbose => 1,
    #    });
}

# calc_cksums EXPECTED DIRNAME
#
# Opens DIRNAME and calculates checksums for files keyed into EXPECTED.
# Will return false if we find a mismatch and print a message to STDERR.
# Returns true otherwise.
sub calc_cksums {
    my ($expected, $dirn) = @_;

    opendir(my $dh, $dirn) or die($!);
    while (readdir $dh) {
        if ($_ eq any(keys %{$expected})) {
            # Assertion: All checksums are calculated using MD5.
            my $cksum = (split(' ', `md5sum $dirn/$_`))[0];
            unless ($cksum eq $expected->{$_}) {
                print STDERR "Found mismatch for $_, expected $expected->{$_} but got $cksum\n";
                clean_dir($dirn);
                return 0;
            }
        }
    }
    closedir($dh);
    print "Everything looks good!\n";
    return 1;
}

calc_cksums(get_cksums(read_soft(shift)), unpack_tar(shift));
