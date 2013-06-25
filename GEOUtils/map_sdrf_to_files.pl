#!/usr/bin/perl -w

use strict;
use warnings;

use Cwd;
use Data::Dumper;
use List::Util qw(max);
#use Digest::Md5 qw(md5 md5_hex md5_base64);

####################################################################################################
# Stuff for dealing with the SOFT file.

my $input_str = "_Input";
my $chip_str = "_ChIP";
my $rep_str = "_Rep";

################################################################################
# A Sample is:
# {
#   "Name" => name					:: String => String
#   "SourceName" => sourcename		:: String => String
# 	"Type" => type					:: String => String
# 	"Replicate" => replicate		:: String => Number
#   "Files" => [SFILE, SFILE, ...]	:: String => Arrayref of Supplementary Files
# }
################################################################################

# mk_sample NAME SOURCENAME TYPE REPLICATE FILES
#
# Constructor for the Sample "object". All arguments optional; omitted
# ones will have a corresponding undefined field in the returned object;
# the Files field will instead have the empty arrayref.
sub mk_sample {
    return {
        "Name" => shift,
        "SourceName" => shift,
        "Type" => shift,
        "Replicate" => shift,
        "Files" => shift || [],
    };
}

# sample_name_from_sdrf SAMPLE SDRFNAME
#
# Self-explanatory.
sub sample_name_from_sdrf {
    my $sample = shift;

    # We just use $(basename [SDRF]).
    my $sdrfname = shift;
    if ($sdrfname =~ m/^(Snyder_.+)\.sdrf$/) {
        $sample->{"Name"} = $1;
    } else {
        $sample->{"Name"} = undef;
    }
}

# source_name_from_sample SAMPLE
#
# Self-explanatory.
sub get_source_name {
    my $sample = shift;
    die "Attempt to get source name from unnamed Sample!\n" unless defined $sample->{"Name"};

    if ($sample->{"Name"} =~ m/^Snyder_(.+)$/) {
        $sample->{"SourceName"} = $1;
    } else {
        $sample->{"SourceName"} = undef;
    }
}

# set_type SAMPLE TYPE
#
# Setter for Type field.
sub set_type {
    shift->{"Type"} = shift;
}

# set_rep SAMPLE TYPE
#
# Setter for Type field.
sub set_rep {
    shift->{"Replicate"} = shift;
}

# add_sfiles SAMPLE (SFILE, SFILE, ...)
#
# Setter for "Files" field.
sub add_sfiles {
    my $sample = shift;
    foreach (@_) {
        push @{$sample->{"Files"}}, shift;
    }
}

####################################################################################################
# Stuff for dealing with supplementary/raw files.

my %exts_to_ftypes = (
    "gff3" => "GFF3",
    "wig" => "WIG",
    "fastq.gz" => "FASTQ",
    "unknown" => "UNKNOWN",
);

################################################################################
# A Supplementary File (SFILE) is:
# {
# 	"Filename" => filename			:: String => String
# 	"Replicate" => replicate		:: String => Integer
# 	"Filetype" => filetype			:: String => String
#   "Checksum" => checksum			:: String => String
# }
################################################################################

# mk_sfile FILENAME REPLICATE FILETYPE CHECKSUM
#
# Creates and returns an SFILE "object". All arguments are optional.
# If an argument is omitted, the returned object will have undefined
# (but existent) fields.
sub mk_sfile {
    return {
        "Filename" => shift,
        "Replicate" => shift,
        "Filetype" => shift,
        "Checksum" => "FOOBAR",
    };
}

# validate_sfile SFILE
#
# Returns True if there are no "problematic" or "undefined" values in an
# SFILE's fields; False otherwise.
sub validate_sfile {
    my $sfile = shift;
    foreach (keys %{$sfile}) {
        return 0 unless defined $sfile->{$_};
        return 0 if $sfile->{"Replicate"} == 0;
        return 0 if $sfile->{"Filetype"} eq "UNKNOWN";
    }
    return 1;
}


# determine_filetype SFILE
#
# Given a Supplementary File, determine its Filetype.
sub determine_filetype {
    my $supfile = shift;
    my $ft_guess = "unknown";

    if ($supfile->{"Filename"} =~ m/^.*\.(.+)$/) {
        $ft_guess = lc $1;
        if ($ft_guess eq "gz") {
            $ft_guess = lc $supfile->{"Filename"} =~ m/fastq/ ? "fastq.gz" : "unknown";
        }
        $supfile->{"Filetype"} = $exts_to_ftypes{$ft_guess};
    }
}

# determine_replicate SFILE
#
# Given a Supplementary File, determine its Replicate number. A Replicate number 
# of 0 indicates there was a problem with our heuristic; -1 indicates that
# we have a "combined" file.
sub determine_replicate {
    my $sfile = shift;
    my $fname = lc $sfile->{"Filename"};

    # We will just enumerate all the possible cases here; there appears to be no
    # prevailing convention for naming replicates.

    if ($fname =~ m/^.*rep_([0-9]).*$/) {
        $sfile->{"Replicate"} = $1;
    } elsif ($fname =~ m/^.*rep([0-9]).*$/) {
        # This looks funny, but we really just need the if-then-else for the match op's side effect.
        $sfile->{"Replicate"} = $1;
    } elsif ($fname =~ m/combined/) {
        $sfile->{"Replicate"} = -1;
    } else {
        $sfile->{"Replicate"} = 0;
    }
}

# get_md5sum SFILE
#
# Given an SFILE, calculate its md5 checksum.
sub get_md5sum {
    my $sfile = shift;
    die "Tried to get_md5sum an SFILE with no name!\n" unless defined $sfile->{"Filename"};

    opendir(my $dh, getcwd) or die($!);

    my $found_file = 0;
    while (readdir $dh) {
        $found_file = 1 if m/$sfile/;
    }

    # TODO:
    # Some SCP subroutine here.

}

# get_supfile_info SFILE
#
# Given a Supplementary File, try to fill in its Replicate and Type fields,
# based on its name alone.
sub get_supfile_info {
    my $sfile = shift;

    determine_filetype($sfile);
    determine_replicate($sfile);
}


####################################################################################################

################################################################################
# A Submission is a single value in an SDRFMap. That is, it is an arrayref
# of SFILEs.
################################################################################

################################################################################
# An SDRFMap is:
# {
# 	"SDRF1" => [SFILE, SFILE, ...]
# 	"SDRF2" => [SFILE, SFILE, ...]
#	.
#	.
#	.
#	"SDRFN" => [SFILE, SFILE, ...]
# }
################################################################################

# get_num_reps SUBMISSION
#
# Return the number of replicates in this submission.
sub get_num_reps {
    my $sub = shift;
    #print Dumper($sub);
    return max(map { $_->{"Replicate"}; } @{$sub});
}

# find_samples SUBMISSION SDRFNAME
#
# Determines what Sample entries need to be recorded in the SOFT. Returns
# an arrayref of Samples.
# name, samplename, type, replicate, files
sub find_samples {
    my $sub = shift;
    my @samples;
    my $num_reps = get_num_reps($sub);

    my $sdrfname = shift;

    for (my $i = 1; $i <= $num_reps; $i++) {
        my $source_basename;
        my $basename;
        # We just use $(basename [SDRF]).
        if ($sdrfname =~ m/^(Snyder_.+)\.sdrf$/) {
            $basename = $1;
        } else {
            $basename = undef;
        }

        if ($basename =~ m/^Snyder_(.+)$/) {
            $source_basename = $1;
        } else {
            $source_basename = undef;
        }

        my $input_sample = mk_sample($basename . $input_str . $rep_str . $i, 
            $source_basename . $input_str . $rep_str . $i,
            "Input", $i, $sub);
        my $chip_sample = mk_sample($basename . $chip_str . $rep_str . $i, 
            $source_basename . $chip_str . $rep_str . $i,
            "ChIP", $i, $sub);
        push @samples, ($input_sample, $chip_sample);
    }

    return \@samples;
}

# sfiles_from_sdrf
#
# From STDIN/ARGV, reads in a two-column tab separated file where
# the first column contains SDRF files and the second contains
# files within the SDRFs.
#
# SIDE EFFECTS:
# Creates a new Supplementary File "object", mapped to by the SDRF
# in which the Supplementary File is found.

sub sfiles_from_sdrf {
    my %struct;
    while (<>) {
        chomp;
        my @fields = split("\t");
        $struct{$fields[0]} = [] unless exists $struct{$fields[0]};
        push @{$struct{$fields[0]}}, mk_sfile($fields[1]);
    }

    return \%struct;
}

my $sdrfmap = sfiles_from_sdrf();

################################################################################
# ENTRY POINT
################################################################################
foreach my $sdrf (keys %{$sdrfmap}) {
    foreach my $file (@{$sdrfmap->{$sdrf}}) {
        get_supfile_info($file);
        #print Dumper($file) unless validate_sfile($file);
    }
    #printf "$sdrf\t%d\n", get_num_reps($sdrfmap->{$sdrf});
    print Dumper(find_samples($sdrfmap->{$sdrf}, $sdrf));
}

#print Dumper($sdrfmap);
