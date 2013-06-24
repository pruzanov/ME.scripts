#!/usr/bin/perl -w

use strict;
use warnings;

use Carp qw(confess);

use Cwd;
use Data::Dumper;
use List::Util qw(max);
#use Digest::Md5 qw(md5 md5_hex md5_base64);

####################################################################################################
# Stuff for dealing with Samples.

my $input_str = "_Input";
my $chip_str = "_ChIP";
my $rep_str = "_Rep";

################################################################################
# A Sample is:
# {
#   "Name" => name					:: String => String
#   "Sourcename" => sourcename		:: String => String
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
        "Sourcename" => shift,
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
        $sample->{"Sourcename"} = $1;
    } else {
        $sample->{"Sourcename"} = undef;
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
#   "Exptype"  => exptype			:: String => String
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
        "Exptype" => shift,
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

# determine_exptype SFILE
#
# Determine if an SFILE is Input or ChIP.
sub determine_exptype {
    my $sfile = shift;
    my $sfname = lc $sfile->{"Filename"};

    if ($sfname =~ m/_input_/) {
        $sfile->{"Exptype"} = "Input";
    } else {
        $sfile->{"Exptype"} = "ChIP";
    }
}


# determine_filetype SFILE
#
# Given a Supplementary File, determine its Filetype.
sub determine_filetype {
    my $supfile = shift;
    my $ft_guess = "unknown";

    # NOTE: This regex chokes on things like .wig.combined.wig
    if ($supfile->{"Filename"} =~ m/^.*\.(.+)$/) {
        $ft_guess = lc $1;
        if ($ft_guess eq "gz") {
            $ft_guess = lc $supfile->{"Filename"} =~ m/fastq/ ? "fastq.gz" : "unknown";
        }
        $supfile->{"Filetype"} = $exts_to_ftypes{$ft_guess};
    } else {
        #print Dumper($supfile);
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

# TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO
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
    determine_exptype($sfile);
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

        my @input_files = map { #print Dumper($_);
        ($_->{"Exptype"} eq "Input" or $_->{"Filetype"} eq "GFF3") and
        ($_->{"Replicate"} == $i or
        $_->{"Replicate"} == -1) ? $_ : () } @{$sub};

        my @chip_files = map { #print Dumper($_);
        ($_->{"Exptype"} eq "ChIP" or $_->{"Filetype"} eq "GFF3") and
        ($_->{"Replicate"} == $i or
        $_->{"Replicate"} == -1) ? $_ : () } @{$sub};

        #print Dumper(\@input_files);
        #print Dumper(\@chip_files);

        my $input_sample = mk_sample($basename . $input_str . $rep_str . $i, 
            $source_basename . $input_str . $rep_str . $i,
            #"Input", $i, $sub);
            #"Input", $i, map { defined $_->{"Exptype"} and defined $_->{"Replicate"} ? ($_->{"Exptype"} eq "Input" and $_->{"Replicate"} == $i ? $_ : ()) : () } @{$sub});
            #"Input", $i, map { $_->{"Exptype"} eq "Input" and $_->{"Replicate"} == $i ? $_ : () } @{$sub});
            "Input", $i, \@input_files);
    my $chip_sample = mk_sample($basename . $chip_str . $rep_str . $i, 
        $source_basename . $chip_str . $rep_str . $i,
        #"ChIP", $i, $sub);
        #"ChIP", $i, map { $_->{"Exptype"} eq "ChIP" and $_->{"Replicate"} == $i ? $_ : () } @{$sub});
        "ChIP", $i, \@chip_files);
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

####################################################################################################
# Stuff for dealing with the SOFT file.

my $series_sample_id_str = "!Series_sample_id";
my $sample_str = "^Sample";
my $sample_title_str = "!Sample_title";
my $sample_source_name_str = "!Sample_source_name";
my $sample_description_str = "!Sample_description";
my $sample_sup_file_str = "!Sample_supplementary_file_";
my $sample_raw_file_str = "!Sample_raw_file_";
my $sample_sup_file_type_str = "!Sample_supplementary_file_type_";
my $sample_raw_file_type_str = "!Sample_raw_file_type_";
my $sample_raw_file_checksum_str = "!Sample_raw_file_checksum_";

# build_ssi_block SAMPLES
# 
# Return an array of lines that represents the "!Series_sample_id" block preceding the first
# ^Sample block.
sub build_ssi_block {
    my $samples = shift;
    my @lines;
    foreach (@{$samples}) {
        push @lines, $series_sample_id_str . " = GSM for " . $_->{"Name"} . "\n";
    }
    return @lines;
}

# build_file_block SAMPLE
# 
# Return a pair of arrays of lines that represent the "!Sample_supplementary_file_n" and 
# "!Sample_raw_file_n_" blocks.
sub build_file_block {
    my $sample = shift;
    my @sup_lines;
    my @raw_lines;
    my $rawnum = 1;
    my $supnum = 1;
    foreach (@{$sample->{"Files"}}) {
        next if m/^$/;
        my $fname_line = " = " . $_->{"Filename"} . "\n";
        my $ftype_line = " = " . $_->{"Filetype"} . "\n";
        if ($_->{"Filetype"} eq "FASTQ") {
            my $cksum_line = $sample_raw_file_checksum_str . " = " . $_->{"Checksum"} . "\n";
            $fname_line = $sample_raw_file_str . $rawnum . $fname_line;
            $ftype_line = $sample_raw_file_type_str . $rawnum . $ftype_line;
            push @raw_lines, ($fname_line, $ftype_line, $cksum_line);
            ++$rawnum;
        } else {
            $fname_line = $sample_sup_file_str . $supnum . $fname_line;
            $ftype_line = $sample_sup_file_type_str . $supnum . $ftype_line;
            push @sup_lines, ($fname_line, $ftype_line);
            ++$supnum;
        }
    }
    my @lines;
    push @lines, (@sup_lines, @raw_lines);
    return @lines;
}

# read_soft FILENAME SAMPLES
#
# Read through the SOFT file, make adjustments as necessary.
#
# We make a number of assumptions in this sub:
# 	> The following lines MUST be present in the input SOFT:
#
# 		- !Series_sample_id,	in one contiguous block before the sample blocks
#
# 		As a contiguous block, for every sample:
#
# 		- ^Sample
# 		- !Sample_title
# 		- !Sample_source_name
#
#			As a contiguous block, for all files in a sample:
# 			- !Sample_supplementary_file_n
# 			- !Sample_raw_file_n
#
# If any of the above lines are missing, we will exit.
sub read_soft {

    my $softname = shift;
    open(my $softfh, "<", $softname) or die ($!);

    my $orig_samples = shift;
    my @samples = map { $_ } @{$orig_samples};

    my @lines;
    my %seen_lines;

    my %sample_descs;

    # TODO: A bit hacky, refactor later
    while (<$softfh>) {
        if (m/^$sample_description_str/) {
            if (m/=\s+ChIP DNA;/) {
                $sample_descs{"ChIP"} = $_;
            } else {
                $sample_descs{"Input"} = $_;
            }
        }
    }

    close($softfh);
    open($softfh, "<", $softname) or die ($!);

    while (<$softfh>) {
        if (m/^$series_sample_id_str/) {
            next if $seen_lines{$series_sample_id_str};
            $seen_lines{$series_sample_id_str} = 1;
            push @lines, build_ssi_block($orig_samples);
        } elsif (m/^\Q$sample_str\E/) {
            $seen_lines{$sample_sup_file_str} = 0;
            last unless @samples;
            push @lines, $sample_str . " = GSM for " . $samples[0]->{"Name"} . "\n";
        } elsif (m/^$sample_title_str/) {
            push @lines, $sample_title_str . " = " . $samples[0]->{"Name"} . "\n";
        } elsif (m/^$sample_source_name_str/) {
            push @lines, $sample_source_name_str . " = " . $samples[0]->{"Sourcename"} . "\n";
        } elsif (m/^$sample_description_str/) {
            if ($samples[0]->{"Type"} eq "Input") {
                push @lines, $sample_descs{"Input"};
            } else {
                push @lines, $sample_descs{"ChIP"};
            }
        } elsif (m/^(${sample_sup_file_str}|${sample_raw_file_str})(type_)?(checksum_)?[0-9]+/) {
            next if $seen_lines{$sample_sup_file_str};
            $seen_lines{$sample_sup_file_str} = 1;
            push @lines, build_file_block($samples[0]);
            shift @samples;
        } else {
            push @lines, $_;
        }
    }

    # Should probably relegate this to its own sub and just have this one return @lines
    my $i = 0;
    print STDOUT @lines;
}

# dirty hack for now
sub build_softmap {
    open(my $fh, "<", shift) or die($!);
    my %struct;
    while (<$fh>) {
        chomp;
        my @fields = split("\t");
        $struct{$fields[0]} = $fields[1];
    }
    return \%struct;
}

#    while (<$softfh>) {
#
#        next unless @samples;
#        my $sample = shift @samples;
#        if (m/^!Series_sample_id/) {
#            print $series_sample_id_str . "GSM for " . $sample->{"Name"} . "\n";
#        } elsif (m/^\^Sample/) {
#            print $sample_str . "GSM for " . $sample->{"Name"} . "\n";
#        } elsif (m/^\!Sample_title/) {
#            print $sample_title_str . $sample->{"Name"} . "\n";
#        } elsif (m/^!Sample_source_name/ ) {
#            print $sample_source_name_str . $sample->{"Sourcename"} . "\n";
#        }
#    }

################################################################################
# ENTRY POINT
################################################################################
my $softmap = build_softmap(getcwd . "/sdrf-soft.map");

my $hack = 0;
foreach my $sdrf (keys %{$sdrfmap}) {
    foreach my $file (@{$sdrfmap->{$sdrf}}) {
        get_supfile_info($file);
        #print Dumper($file);#unless validate_sfile($file);
    }
    #printf "$sdrf\t%d\n", get_num_reps($sdrfmap->{$sdrf});
    #print Dumper(find_samples($sdrfmap->{$sdrf}, $sdrf));

    my $samples = find_samples($sdrfmap->{$sdrf}, $sdrf);
    read_soft(getcwd . "/" . $softmap->{$sdrf}, $samples) unless $hack;
    $hack = 1;
}


#print Dumper($sdrfmap);
