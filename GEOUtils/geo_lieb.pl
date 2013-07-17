#!/usr/bin/perl -w

=pod

=head1 NAME

geo_lieb.pl - Proofread chado2GEO.pl SOFT files from Lieb submissions

=head1 SYNOPSIS

	geo_lieb.pl [SUBID] [SDRF] [SOFT]

=head1 DESCRIPTION

Your current working directory should have the following structure:
[CWD]
----> 8001
--------> 8001.sdrf
--------> 8001.soft
----> 8002
--------> 8002.sdrf
--------> 8002.soft
----> ....
----> 9000
--------> 9000.sdrf
--------> 9000.soft

=cut

# CAVEAT: !Sample_description lines for ChIP samples will need fixing.
# I will revise this script later to add in the proper lines if needed.

use strict;
use warnings;

use Cwd;

use Data::Dumper;
use Digest::MD5;
use Net::SCP qw(scp);
use List::Util qw(first);

## TODO LIST:
#
# Lift out large procedures into their own sub.
# Possibly move GEOSample/GEOFile into their own module?
# 	But, we don't need inheritance/polymorphism
# 	Can we define subs which would be commonly required for all labs?

################################################################################
########################### "READ-ONLY" CONFIG VARS ############################
################################################################################
#                                                                              # 

my $cwd = getcwd;

my %exts_to_ftypes = (
    "gff3" => "GFF3",
    "gff" => "GFF3",
    "wig" => "WIG",
    "fastq.gz" => "FASTQ",
    "fastq" => "FASTQ",
    "fq.gz" => "FASTQ",
    "fq" => "FASTQ",
    "txt.gz" => "TXT",
);

my @raw_ftypes = ("FASTQ", "TXT");

#                                                                              # 
################################################################################

# is_member STR ARRAYREF
#
# Determines if STR is a member of ARRAYREF.
#
# How is this not in the standard library? Smart match is terrible, and sometimes
# we don't want to set $_ in grep.
sub str_is_member {
    my ($str, $arr) = @_;
    foreach(@{$arr}) {
        return 1 if $str eq $_;
    }
    return 0;
}

# transpose MATRIX
# transpose MATRIX _ACCUMULATOR
#
# MATRIX :: arrayref of arrayrefs
# _ACCUMULATOR :: arrayref of arrayrefs (INTERNAL USE, defaults to empty list)
sub transpose {
    my $mref = shift;
    my $acc = shift || []; 

    my @matrix = map { [@$_] } @{$mref};

    # This is our recursive base case.
    return $acc unless scalar(@{$matrix[0]});

    push(@{$acc}, [map { $_->[0] } @matrix]);
    return transpose([map { shift $_; $_ } (my @matrix_ = @matrix)], $acc);
}

# trim_sdrf SDRFMATRIX
#
# Return a submatrix of SDRFMATRIX consisting of the first column
# and all file columns.
#
# ARGUMENTS:
# SDRFNAME :: String
sub trim_sdrf {
    my $sdrfmatrix = shift;

    my $sdrftranspose = transpose($sdrfmatrix);
    # This is the submatrix of SDRFMATRIX that only contains
    # those columns necessary for building a SOFT file out
    # of the entire SDRF.
    my @softmatrix = grep { $_->[0] =~ m/Result File \[.+\]/ } @{$sdrftranspose};
    splice(@softmatrix, 0, 0, $sdrftranspose->[0]);

    return transpose(\@softmatrix);

}

# sdrf_to_matrix SDRFNAME
#
# Open the file specified by SDRFNAME and read it into
# an arrayref of arrayref of Strings.
#
# Return value: Arrayref of arrayref of Strings (An SDRFMATRIX)
#
# ARGUMENTS:
# SDRFNAME :: String
sub sdrf_to_matrix {
    my $sdrfname = shift;
    my @matrix;

    open(my $fh, "<", $sdrfname) or die($!);
    chomp(my @rows = <$fh>);
    close($fh);

    foreach (@rows) {
        push @matrix, [split("\t")];
    }
    return \@matrix;
}

# calc_checksum FILENAME SUBID
#
# Given a FILENAME, calculate the file's md5 checksum.
#
# RETURN VALUE: String
#
# ARGUMENTS:
# FILENAME :: String
# SUBID :: Integer
sub calc_checksum {
    my $sub_prefix = "modencode-www1.oicr.on.ca:/modencode/raw/data/";
    my $sub_postfix = "/extracted/";

    my ($fname, $subid) = @_;


    die "Tried to calc_checksum a GEOFILE with no name!\n" unless defined $fname;

    opendir(my $dh, "$cwd/$subid") or die($!);

    my $found_file = 0;
    while (readdir $dh) {
        $found_file = 1 if m/\Q$fname\E/;
    }

    unless ($found_file) {
        #scp($sub_prefix . $subid . $sub_postfix . $fname, $cwd . "/" . $subid . "/" . $fname) or die ($!);
        scp($sub_prefix . $subid . $sub_postfix . $fname, "$cwd/$subid/$fname") or die ($!);
    }

    open(my $sfh, "<", "$cwd/$subid/$fname") or die($!);

    my $md5 = Digest::MD5->new;
    $md5->addfile($sfh) or die($!);
    my $hexdigest = $md5->hexdigest or die($!);

    unlink "$cwd/$subid/$fname";
    return $hexdigest;

}

################################################################################
########################### SOFT FILE MANIPULATIONS ############################
################################################################################

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

# build_ssid_block SAMPLES
#
# Return an arrayref of strings representing the "!Series_sample_id = *" lines
# in a SOFT file.
#
# ARGUMENTS:
# SAMPLES :: Hashref of GEOSamples keyed by Strings
sub build_ssid_block {
    my $samples = shift;

    my @lines;
    foreach (sort { $samples->{$a}->{"Replicate"} <=> $samples->{$b}->{"Replicate"} } keys %{$samples}) {
        push @lines, "!Series_sample_id = GSM for $_";
    }

    return \@lines;
}

# build_sample_header SAMPLE
#
# Return an arrayref of strings representing the following lines in a SOFT:
# ^Sample = GSM for *
# !Sample_title = *
# !Sample_source_name = *
sub build_sample_header {
    my $sample = shift;

    return ["^Sample = GSM for $sample->{Name}", "!Sample_title = $sample->{Name}", "!Sample_source_name = $sample->{Sourcename}"];
}

# proofread_sampleblock SAMPLEBLOCK
#
# Return an arrayref of strings representing a sample block,
# by modifying the lines given by SAMPLEBLOCK.
#
# ARGUMENTS:
# SAMPLEBLOCK: Arrayref of Strings
sub proofread_sampleblock {
    my $firstdraft = shift;

    my $sample_desc = first { m/^!Sample_description\s+=\s+(\w)\s+DNA/ } @{$firstdraft};
    my $sampletype = $1;

    print STDERR Dumper($firstdraft) unless ($sampletype =~ m/chip/i or $sampletype =~ m/input/i);
    die "Could not determine sample type! Dumping block" unless ($sampletype =~ m/chip/i or $sampletype =~ m/input/i);

}

# proofread_soft SOFTLINES SAMPLES
#
# Return an arrayref of strings representing an entire SOFT file, generated
# by modifying the lines given by SOFTLINES.
#
# ARGUMENTS:
# SOFTLINES: Arrayref of Strings
sub proofread_soft {
    my ($firstdraft, $orig_samples) = @_;

    my %samples = %{$orig_samples};
    my $num_inputs = 0;
    my $num_chips = 0;
    foreach (keys %samples) {
        ++$num_inputs if uc $samples{$_}->{"Type"} eq "INPUT";
        ++$num_chips if uc $samples{$_}->{"Type"} eq "CHIP";
    }

    my @finaldraft;

    # TODO: This sub has way too much state, we need a more elegant method of
    # doing SOFT processing.

    # TODO: It's also too large.

    # cur_block		= "SSID" | "SAMPLE" | "FILES" | "NONE";
    my $cur_block = "NONE";
    my $cur_sample_name = undef;

    # Traditional for loop so we can "seek" around the file.
    for (my $i = 0; $i <= $#{$firstdraft}; $i++) {
        my $line = $firstdraft->[$i];

        # We should probably split each case into a sub. Meh.

        if ($line =~ m/^!Series_sample_id/) {

            push @finaldraft, @{build_ssid_block(\%samples)} unless $cur_block eq "SSID";
            $cur_block = "SSID";

        } elsif ($line =~ m/^\^Sample/) {

            # Remove this sample from our hash so we don't process it again.
            delete $samples{$cur_sample_name} if defined $cur_sample_name;
            last unless scalar(keys %samples);
            $cur_block = "SAMPLE";

            my $sampletype = undef;

            if ($num_inputs) {
                $sampletype = "INPUT";
                --$num_inputs;
            } else {
                $sampletype = "CHIP";
                --$num_chips;
            }

            # This approach doesn't seem to work for the chado2GEO.pl generated Lieb SOFTs.
            ## Find the !Sample_description line within this block.
            #for (my $j = $i+1; $j <= $#{$firstdraft}; $j++) {
            #    if ($firstdraft->[$j] =~ m/^!Sample_description\s+=\s+(\w+)\s+DNA/) {
            #        $sampletype = uc $1;
            #        last;
            #    }
            #}

            # We failed to find a valid sample type, die.
            print STDERR Dumper($firstdraft) unless (defined $sampletype and $sampletype ~~ @{["INPUT", "CHIP"]});
            die "Could not get sample type! We found $sampletype, dumping SOFT file" unless (defined $sampletype and $sampletype ~~ @{["INPUT", "CHIP"]});

            # Create a new sample block of the same experimental type as the one we found above.

            # Numerically sort samples by replicate.
            foreach (sort { $samples{$a}->{"Replicate"} <=> $samples{$b}->{"Replicate"} } keys %samples) {
                print STDERR "foobar $samples{$_}->{Type} $sampletype\n";
                print STDERR Dumper(keys %samples);
                if (uc $samples{$_}->{"Type"} eq $sampletype) {
                    $cur_sample_name = $_;
                    push @finaldraft, @{build_sample_header($samples{$_})};
                    last;
                }
            }
        } elsif ($line =~ m/^!Sample_\w+_file/) {
            next if $cur_block eq "FILES";
            $cur_block = "FILES";
            my $cur_raw_num = 0;
            my $cur_sup_num = 0;

            print STDERR "We are in the file block for $cur_sample_name. Dumping files:\n";
            print STDERR Dumper($samples{$cur_sample_name}->{"Files"});

            # We expect supplementary files first in the arrayref, and raw files
            # at the end.
            foreach (@{$samples{$cur_sample_name}->{"Files"}}) {
                if ($_->{"Filetype"} ~~ @raw_ftypes) {
                    push @finaldraft, @{geofile_to_str($_, ++$cur_raw_num)};
                } else {
                    push @finaldraft, @{geofile_to_str($_, ++$cur_sup_num)};
                }
            }

        } elsif ($line =~ m/^!Sample_title\s+=/ or $line =~ m/^!Sample_source_name\s+=/) {
            next;
        } elsif ($line =~ m/^!Sample_description/) {
            push @finaldraft, "!Sample_description = $samples{$cur_sample_name}->{Type} DNA";
        } else {
            push @finaldraft, $line;
        }
    }

    return \@finaldraft;
}

################################################################################
# A GEOFile (GEOFILE) is:
# {
# 	"Filename" => filename			:: String => String
# 	"Replicate" => replicate		:: String => Integer
#   "Exptype"  => exptype			:: String => String
# 	"Filetype" => filetype			:: String => String
#   "Checksum" => checksum			:: String => String
# }
################################################################################

# create_geofiles FILENAMES REPLICATE EXPTYPE SUBID
#
# Create a bunch of GEOFile instances representing the files given
# in FILENAMES.
#
# RETURN VALUE: An arrayref of GEOFiles.
#
# ARGUMENTS:
# FILENAMES: Arrayref of Strings
# REPLICATE: Integer
# EXPTYPE: String
sub create_geofiles {
    my ($fnames, $replicate, $exptype, $subid) = @_;
    my @geofiles;

    foreach (@{$fnames}) {
        my $filename = $_;
        my $filetype = undef;

        foreach my $ext (keys %exts_to_ftypes) {
            $filetype = $exts_to_ftypes{$ext} if $filename =~ m/$ext/i;
        }
        die "Could not determine filetype for file $_" unless defined $filetype;

        my $checksum = undef;
        $checksum = calc_checksum($filename, $subid) if $filetype ~~ @raw_ftypes;

        push @geofiles, {
            "Filename" => $filename,
            "Replicate" => $replicate,
            "Exptype" => $exptype,
            "Filetype" => $filetype,
            "Checksum" => $checksum,
        };

    }

    return \@geofiles;
}

# geofile_to_str GEOFILE FILENUM
#
# Return an arrayref of lines that should represent this GEOFile
# in a SOFT file.
#
# ARGUMENTS:
# GEOFILE: GEOFile
# FILENUM: Integer
sub geofile_to_str {
    my ($geofile, $filenum) = @_;
    my $prefix;
    my $equals = " = ";

    my @lines;

    my $fcksm_ln = undef;
    if ($geofile->{"Filetype"} ~~ @raw_ftypes) {
        $prefix = "!Sample_raw_file_";
        $fcksm_ln = $prefix . "checksum_" . $filenum . $equals . $geofile->{"Checksum"};
    } else {
        $prefix = "!Sample_supplementary_file_";
    }

    # TODO: Abstract this out later.
    my $fname_ln = $prefix . $filenum . $equals . $geofile->{"Filename"};
    my $ftype_ln = $prefix . "type_" . $filenum . $equals . $geofile->{"Filetype"};

    push @lines, ($fname_ln, $ftype_ln);
    push @lines, $fcksm_ln if defined $fcksm_ln;
    return \@lines;
}

################################################################################
# A Sample is:
# {
#   "Name" => name					:: String => String
#   "Sourcename" => sourcename		:: String => String
#   "modENCODE_ID" => modencode_id	:: String => String
# 	"Type" => type					:: String => String
# 	"Replicate" => replicate		:: String => Number
#   "Files" => [GEOFILE, GEOFILE, ...]	:: String => Arrayref of GEOFiles
# }
################################################################################

#my %exts_to_ftypes = (
#    "gff3" => "GFF3",
#    "wig" => "WIG",
#    "fastq.gz" => "FASTQ",
#    "fastq" => "FASTQ",
#    "unknown" => "UNKNOWN",
#);

# sort_files GFILELIST
#
# Sorts the entries in GFILELIST, such that supplementary files come first.
#
# RETURN VALUE: Arrayref of GEOFiles
#
# ARGUMENTS:
# GFILELIST: Arrayref of GEOFiles
sub sort_files {
    my $files = shift;
    return [sort { 
        return 0 if (($a->{"Filetype"} ~~ @raw_ftypes) and ($b->{"Filetype"} ~~ @raw_ftypes));
        return 0 if (!($a->{"Filetype"} ~~ @raw_ftypes) and !($b->{"Filetype"} ~~ @raw_ftypes));
        return 1 if (($a->{"Filetype"} ~~ @raw_ftypes) and !($b->{"Filetype"} ~~ @raw_ftypes));
        return -1;
        } @{$files}];
}

# create_samples SOFTMATRIX SUBID
#
# Create GEOSample objects for all samples in this submission.
#
# Return value: Hashref of Strings to GEOSamples
# 	in which GEOSamples are keyed by their Name attribute
#
# ARGUMENTS:
# SOFTMATRIX :: Return value of trim_sdrf
# SUBID		 :: Integer
sub create_samples {
    my ($orig_softmatrix, $subid) = @_;

    # Strip the first row - we don't need column headings.
    my @softmatrix = (@{$orig_softmatrix}); # So we don't mess up the original
    shift @softmatrix;

    print STDERR "="x80 . "\n";
    print STDERR "SDRF Summary:\n";
    print STDERR "="x80 . "\n";
    print STDERR Dumper(\@softmatrix);

    my %samples;
    foreach my $sdrfrow (@softmatrix) {
        my $name = $sdrfrow->[0];

        print STDERR "="x80 . "\n";
        print STDERR "Found sample $name\n";
        print STDERR "="x80 . "\n";

        my ($type, $replicate);
        if ($name =~ m/Input/i) {
            $type = "Input"
        } else {
            $type = "ChIP"
        }

        if ($name =~ m/_([0-9]+)$/) {
            $replicate = $1;
            if ($name =~ m/Input/i) {
                $name =~ s/_([0-9]+)$/_Rep${replicate}/;
            } else {
                $name =~ s/_([0-9]+)$/_${type}_Rep${replicate}/;
            }
        }

        if (exists $samples{$name}) {
            # This is not strictly necessary but it is good to verify the
            # robustness of our approach -
            # verify that if we encounter two rows in the SDRF with the same
            # sample name, that their modENCODE_ID, Type, and
            # Replicate match.

            die "Subid mismatch, sample $name: $subid, $samples{$name}->{modENCODE_ID}" unless $subid == $samples{$name}->{"modENCODE_ID"};
            die "Type mismatch, sample $name: $type, $samples{$name}->{Type}" unless $type eq $samples{$name}->{"Type"};
            die "Rep mismatch, sample $name: $replicate, $samples{$name}->{Replicate}" unless $replicate == $samples{$name}->{"Replicate"};

            # For the purposes of this script we don't distinguish between rows - only samples. So, let's merge
            # the filelists of both rows.

            # We take the existing GEOSample file list and push all GEOFiles that do not already exist in the list.
            # Maybe we should do this in-place.
            my @newflist = (@{$samples{$name}->{"Files"}}, grep { not str_is_member($_->{"Filename"}, [map { $_->{"Filename"} } @{$samples{$name}->{"Files"}}]) } @{create_geofiles([(@{$sdrfrow}[1..$#{$sdrfrow}])], $replicate, $type, $subid)});
            $samples{$name}->{"Files"} = sort_files(\@newflist);

        } else {
            $samples{$name} = {
                "Name" => $name,
                "Sourcename" => $name,
                "modENCODE_ID" => $subid,
                "Type" => $type,
                "Replicate" => $replicate,
                # Slice the first element out - it's the sample name, not a file.
                "Files" => sort_files(create_geofiles([(@{$sdrfrow}[1..$#{$sdrfrow}])], $replicate, $type, $subid)),
            };
        }

        print STDERR "="x80 . "\n";
        print STDERR "Found $type sample $name, replicate $replicate\n";
        print STDERR "Dumping associated files:\n";
        print STDERR Dumper($samples{$name}->{"Files"});
        print STDERR "="x80 . "\n";
    }
    print STDERR "="x80 . "\n";
    print STDERR "SAMPLE SUMMARY:\n";
    print STDERR Dumper(\%samples);
    print STDERR "="x80 . "\n";
    return \%samples;
}

################################################################################
############################# ENTRY POINT ######################################
################################################################################

# Usage: geo_lieb.pl [SUBID] [SDRF] [SOFT]
my ($subid, $sdrf, $soft) = @ARGV;
print STDERR "="x200 . "\n";
print STDERR "Processing $subid\n";
print STDERR "Invocation: $0 " . join(" ", @ARGV) . "\n";
print STDERR "="x200 . "\n";

#print STDERR Dumper(trim_sdrf(sdrf_to_matrix(shift)));
print join("\n", @{proofread_soft(read_soft($soft), create_samples(trim_sdrf(sdrf_to_matrix($sdrf)), $subid))});
