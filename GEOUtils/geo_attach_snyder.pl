#!/usr/bin/perl -w

use strict;
use warnings;

use Cwd;
use Data::Dumper;
use Net::SCP qw(scp);
use LWP::Simple;
use List::MoreUtils qw(uniq);
use File::Slurp qw(read_file);
use Test::Deep::NoTest qw(eq_deeply);

=pod

=head1 NAME

geo_attach_snyder.pl - Attach GEO accession numbers provided by email.

=head1 SYNOPSIS

 geo_attach_snyder.pl EMAIL [SUBIDs..]

=cut

################################################################################
############################## CONFIG VARS #####################################
################################################################################
#                                                                              # 
my $cwd = getcwd;
my $exts = ["FASTQ(\.(gz|bz2))?", "GFF3", "WIG"];

my $modencode_www1 = "modencode-www1.oicr.on.ca";
my $modencode_datadir = "/modencode/raw/data/";
my $modencode_extractdir = "extracted/Sny*/";

my $geo_url = "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=";
#                                                                              # 
################################################################################

# transpose MATRIX
# transpose MATRIX _ACCUMULATOR
#
# MATRIX :: arrayref of arrayrefs
# _ACCUMULATOR :: arrayref of arrayrefs (internal use)
sub transpose {
    my $mref = shift;
    my $acc = shift || []; 

    my @matrix = map { [@$_] } @{$mref};

    # This is our recursive base case.
    return $acc unless scalar(@{$matrix[0]});

    push(@{$acc}, [map { $_->[0] } @matrix]);
    return transpose([map { shift $_; $_ } (my @matrix_ = @matrix)], $acc);
}

# read_sdrf SDRFNAME
#
# Returns an arrayref of all the lines in the file SDRFNAME.
sub read_sdrf {
    my $sdrfname = shift;

    my @lines;

    open(my $sdrffh, "<", $sdrfname) or die($!);
    while (<$sdrffh>) {
        chomp;
        push @lines, $_;
    }
    return \@lines;
}

# pick_file_cols SDRFLINES EXTS
#
# Given an arrayref of lines in an SDRF, return an arrayref of
# columns in the SDRF that contain filenames. Each column is itself
# an arrayref of Strings.
#
# We only pick out columns with file extensions
# specified by the elements of EXT, by case
# insensitive match.
#
# SDRFLINES :: arrayref of arrayrefs
# EXTS :: arrayref of Strings
#      do not include the leading dot "."
sub pick_file_cols {
    my $lines = shift;
    my $exts = shift;

    # Strip the column headings.
    shift @{$lines};

    my @matrix;

    # Here we take each line and split it into an array of columns;
    # thus we now have a matrix of entries in the SDRF.
    my $matrix = [map { [split("\t")] } @{$lines}];
    $matrix = transpose($matrix);

    my @result;
    my $pattern = join("|", (map { $_ . "\$" } @{$exts}));

    foreach my $col (@{$matrix}) {
        push @result, $col if grep { /$pattern/i } @{$col};
    }

    return \@result;
}

####################################################################################################
# Stuff for dealing with supplementary/raw files.

my %exts_to_ftypes = (
    "gff3" => "GFF3",
    "wig" => "WIG",
    "fastq.gz" => "FASTQ",
    "fastq" => "FASTQ",
    "fastq.bz2" => "FASTQ",
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
        "Checksum" => shift,
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

    if ($sfname =~ m/input/) {
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
        if ($ft_guess eq "gz" or $ft_guess eq "bz2") {
            $ft_guess = lc $supfile->{"Filename"} =~ m/fastq/ ? "fastq.gz" : "unknown";
        }
        $supfile->{"Filetype"} = $exts_to_ftypes{$ft_guess};
    } else {
        print Dumper($supfile);
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
    } elsif ($sfile->{"Filetype"} eq "WIG" and $fname =~ m/input/) {
        $sfile->{"Replicate"} = -1;
    } else {
        print STDERR "Could not determine replicate number for $fname!\n";
        $sfile->{"Replicate"} = undef;
    }
}

# get_supfile_info SFILE
#
# Given a Supplementary File, try to fill in its Replicate and Type fields,
# based on its name alone and the modENCODE submission ID.
sub get_supfile_info {
    my $sfile = shift;

    determine_filetype($sfile);
    determine_exptype($sfile);
    determine_replicate($sfile);
}

#                                                                                                  #
####################################################################################################

# fetch_sdrf SUBID
# 
# Get the SDRF associated with a modENCODE submission.
#
# SUBID :: Integer
sub fetch_sdrf {
    my $subid = shift;
    #((scp("$modencode_www1:${modencode_datadir}$subid/$modencode_extractdir/*{sdrf,SDRF}*", "$cwd/$subid.sdrf") or scp("$modencode_www1:${modencode_datadir}$subid/extracted/*{sdrf,SDRF}*", "$cwd/$subid.sdrf")) or die($!)) unless -e "$subid.sdrf";
    my $scp = Net::SCP->new($modencode_www1);
    #($scp->get("${modencode_datadir}$subid/$modencode_extractdir/*{sdrf,SDRF}*", "$cwd/$subid.sdrf") || $scp->get("${modencode_datadir}$subid/extracted/*{sdrf,SDRF}*", "$cwd/$subid.sdrf")) || die $scp->{"errstr"} unless -e "$subid.sdrf";
    unless ((-e "$subid.sdrf") || $scp->get("${modencode_datadir}$subid/$modencode_extractdir/*{sdrf,SDRF}*", "$cwd/$subid.sdrf")) {
        die $scp->{"errstr"} if ($scp->get("${modencode_datadir}$subid/extracted/*{sdrf,SDRF}*", "$cwd/$subid.sdrf"));
    }
}

# ids_from_email EMAIL
#
# Get the modENCODE submission IDs from a GEO accession email.
#
# EMAIL :: String
sub ids_from_email {
    my $email = shift;
    my @ids;
    foreach (grep { /^GSE/ } read_file($email)) {
        my $acc_num = $1 if m/^(GSE[0-9]+)/;
        my $content = get "${geo_url}$acc_num" or die ($!);
        push @ids, $1 if ($content =~ m/modENCODE_submission_([0-9]+)/);
    }
    return \@ids;
}


# proc_email_block BLOCK
#
# Process a "block" from a GEO accession email - that is,
# a series of lines starting from a line beginning with "GSE[0-9]+", running
# to the next line starting with "GSE[0-9]+".
# 
# BLOCK :: Arrayref of Strings
#
# Return type:
# { 
#	"GSE" => GSE[0-9]+
# 	"Input" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
#	"ChIP" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
# }
sub proc_email_block {
    my $lines = shift;
    my %attachment;
    my $subid;
    foreach (@{$lines}) {
        if (m/^(GSE[0-9]+)/) {
            my $acc_num = $1;
            $attachment{"GSE"} = $acc_num;
            my $content = get "${geo_url}$acc_num" or die ($!);
            if ($content =~ m/modENCODE_submission_([0-9]+)/) {
                $subid = $1;
            } else {
                print STDERR Dumper($lines);
                die "Could not determine submission ID!\n";
            }
        } elsif (m/^(GSM[0-9]+).*Input.*Rep([0-9])/) {
            $attachment{"Input"} = [] unless exists $attachment{"Input"};
            $attachment{"Input"}->[$2] = $1;
        } elsif (m/^(GSM[0-9]+).*ChIP.*Rep([0-9])/) {
            $attachment{"ChIP"} = [] unless exists $attachment{"ChIP"};
            $attachment{"ChIP"}->[$2] = $1;
        }
    }
    return ($subid, \%attachment);
}

# proc_email EMAIL
#
# Process a GEO accession email.
#
# EMAIL :: String
#
# Return type:
# {
# 	"SUBID_1" => { 
# 		"Input" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
#		"ChIP" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
# 	}
# 	"SUBID_2" => { 
# 		"Input" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
#		"ChIP" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
# 	}
#   ...
# 	"SUBID_n" => { 
# 		"Input" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
#		"ChIP" => [ GSM[0-9]+ GSM[0-9]+ ... GSM[0-9]+ ]
# 	}
# }
sub proc_email {
    my $email = shift;
    my @block;
    my %attachments;
    foreach (read_file($email)) {
        if (m/^(GSE[0-9]+)/) {
            my ($subid, $attachment) = proc_email_block(\@block) if @block;
            $attachments{$subid} = $attachment if @block;
            @block = ();
            push @block, $_;
        } elsif (m/^(GSM[0-9]+)/) {
            push @block, $_;
        }
    }
    my ($subid, $attachment) = proc_email_block(\@block) if @block;
    $attachments{$subid} = $attachment;
    return \%attachments;
}

# An expt_info is:
# {
# 	"Type" => One of "Input" or "ChIP"
#   "Replicate" => Some integer
# }


################################################################################
############################## ENTRY POINT #####################################
################################################################################
my $geoemail = shift;
my $attachments = proc_email($geoemail);
print STDERR Dumper($attachments);
#$attachments->{"3846"} = { 
#    'GSE' => 'GSE999999',
#    'Input' => [ undef, 'GSM00001', 'GSM00002' ],
#    'ChIP' => [ undef, 'GSM00003', 'GSM00004' ],
#};

foreach (@ARGV) {
    my $subid = $_;
    fetch_sdrf($subid);
    my $sdrf = read_sdrf("$_.sdrf");
    my $sdrf_fcols = pick_file_cols($sdrf, $exts);
    my $expts = transpose($sdrf_fcols);

    #print Dumper($expts);
    my @geoids;
    foreach my $expt (@{$expts}) {
        my @sfiles;
        my %expt_info;

        foreach my $file (@{$expt}) {
            my $new_sfile = mk_sfile($file);
            push @sfiles, $new_sfile;
            get_supfile_info($new_sfile);
        }

        if (grep { $_->{"Exptype"} eq "Input" } @sfiles) {
            $expt_info{"Type"} = "Input";
        } else {
            $expt_info{"Type"} = "ChIP";
        }

        my @rep_nums = uniq (map { $_->{"Replicate"} } (grep { $_->{"Replicate"} != -1 } @sfiles));

        if (@rep_nums == 1) {
            $expt_info{"Replicate"} = $rep_nums[0];
        } else {
            print STDERR "Something went wrong determining an experiment's replicate\n";
            #print STDERR Dumper(\@sfiles);
            #print STDERR Dumper(\%expt_info);
        }
        #print STDERR "\t$subid\t$expt_info{Type}\t$expt_info{Replicate}\n";
        push @geoids, $attachments->{$subid}->{$expt_info{"Type"}}->[$expt_info{"Replicate"}];
    }
    print STDERR Dumper(\@geoids);
}
