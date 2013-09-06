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
use HTTP::Cookies;
use HTTP::Request;
use WWW::Mechanize;

=pod

=head1 NAME

geo_attach_lieb.pl - Attach GEO accession numbers provided by email.

=head1 SYNOPSIS

 geo_attach_lieb.pl EMAIL CREDENTIALSFILE [SUBIDs..]

=head1 DESCRIPTION

EMAIL is an email from GEO containing accession numbers. Be sure to remove any
intervening line-breaks due to word-wrap. We expect each line to match the pattern

	'^GS[EM][0-9]+'

Example email:

	GSE49717       seq-JA00001_HTZ1_N2_L3   Aug 10, 2013   approved  TAR GFF3 GFF3
	GSM1206280     seq-JA00001_HTZ1_N2_L3_Input_Rep1  Aug 10, 2013   approved  WIG      
	GSM1206281     seq-JA00001_HTZ1_N2_L3_Input_Rep2  Aug 10, 2013   approved  WIG      
	GSM1206282     seq-JA00001_HTZ1_N2_L3_ChIP_Rep1  Aug 10, 2013   approved  WIG      
	GSM1206283     seq-JA00001_HTZ1_N2_L3_ChIP_Rep2  Aug 10, 2013   approved  WIG      
	GSE49718       seq-AB2621_H3K79me3:361576_N2_L3  Aug 10, 2013   approved  TAR      
	GSM1206284     seq-AB2621_H3K79me3:361576_N2_L3_Input_Rep1  Aug 10, 2013  
	GSM1206285     seq-AB2621_H3K79me3:361576_N2_L3_Input_Rep2  Aug 10, 2013  
	GSM1206286     seq-AB2621_H3K79me3:361576_N2_L3_ChIP_Rep1  Aug 10, 2013  
	GSM1206287     seq-AB2621_H3K79me3:361576_N2_L3_ChIP_Rep2  Aug 10, 2013  

CREDENTIALSFILE is a two-column tab-delimited text file. The first column should
contain a modENCODE DCC username; the second should contain a password.

SUBIDs is a space-separated list of submissions for which GEOids must be attached.

=cut

################################################################################
############################## CONFIG VARS #####################################
################################################################################
#                                                                              # 

# Some of these should probably be "use constants". Meh.
my $cwd = getcwd;
my $exts = ["FASTQ(\.(gz|bz2))?", "GFF3", "WIG"];

my $modencode_www1 = "modencode-www1.oicr.on.ca";
my $modencode_datadir = "/modencode/raw/data/";
my $modencode_extractdir = "extracted/";

my $geo_url = "http://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=";

my $attach_geoids_url = "http://submit.modencode.org/submit/curation/attach_geoids/";

my %exts_to_ftypes = (
    "gff3" => "GFF3",
    "gff" => "GFF3",
    "wig" => "WIG",
    "fastq.gz" => "FASTQ",
    "fastq" => "FASTQ",
    "fq.gz" => "FASTQ",
    "fq" => "FASTQ",
    "txt.gz" => "TXT",
    "cel" => "CEL",
);
my @raw_ftypes = ("FASTQ", "TXT", "CEL");
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

####################################################################################################
# Stuff for dealing with supplementary/raw files.


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
        #$checksum = calc_checksum($filename, $subid) if $filetype ~~ @raw_ftypes;

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

# map_gsms_to_samples GEOEMAIL SAMPLES
#
# Map GSMs found in a GEOEMAIL their corresponding Samples.
sub map_gsms_to_samples {
    my ($geoemail, $samples) = @_;

    open(my $fh, '<', $geoemail) or die($!);
    my @geolines = <$fh>;
    my %gsms_to_samples;

    foreach (grep { $_ =~ m/^GSM[0-9]+/ } @geolines) {
        chomp;
        my @fields = split("\t");
        foreach (keys %{$samples}) {
            $gsms_to_samples{$fields[0]} = $fields[1] if ($fields[1] eq $_);
        }
    }

    return \%gsms_to_samples;
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
    my @matrix = (@{$orig_softmatrix}); # So we don't mess up the original
    shift @matrix;

    my @softmatrix = map { [grep { ! m/^.*\.sam$/i } @{$_}] } @matrix;

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

        # Bit of a hack so we can "invert" the mapping from an SDRF row to a GEOSample.
        my $sourcename = $name;

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
                "Sourcename" => $sourcename,
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
########################## ATTACHMENT MECHANIZATION ############################
################################################################################

# auto_login CREDENTIALSFILE USERAGENT URL
#
# Read the file specified by CREDENTIALSFILE and log in to the modENCODE
# submission pipeline, at the location provided by URL.
#
# We return the "Location" field in the response header if successful,
# undef otherwise.
#
# INPUT SPECIFICATION:
#
# Two-column tab-delimited plaintext file. Example:
# Username	Password
#
# We suggest making your credentials file readable by owner only.
#
# ARGUMENTS:
# CREDENTIALSFILE :: String
# USERAGENT :: LWP::UserAgent
# URL :: String
sub auto_login {
    print STDERR "Logging into modENCODE pipeline...\n";
    my ($credentialsfile, $ua, $url) = @_;
    open(my $fh, "<", $credentialsfile) or die($!);
    chomp(my $ln = <$fh>);
    close($fh);
    my @credentials = split("\t", $ln);

    $ua->form_with_fields("login", "password");
    $ua->field("login", $credentials[0]);
    $ua->field("password", $credentials[1]);
    my $resp = $ua->click("commit");

    return undef unless $resp->code == 200;
    print STDERR "Successfully logged into modENCODE pipeline.\n";

    # This redirects us to the attach_geoids page, which is where we want to be.
    return $resp->previous->header("Location");
}

# attach_geoids GEOIDS SUBID CREDENTIALSFILE USERAGENT
#
# Uses HTTP POST to automatically attach GEOIDs to a submission at
# http://submit.modencode.org/submit/curation/attach_geoids/
#
# ARGUMENTS:
# GEOIDS :: [ GSE[0-9]+, GSM[0-9]+, GSM[0-9]+, ..., GSM[0-9]+ ]
# SUBID :: Integer
# CREDENTIALSFILE :: String
# USERAGENT :: LWP::UserAgent
sub attach_geoids {
    print STDERR "enter attach_geoids\n";
    my ($orig_geoids, $subid, $credentialsfile, $ua) = @_;
    my @geoids = @{$orig_geoids};

    my $response = $ua->get($attach_geoids_url . $subid);

    # Redirected to login page
    if ($ua->uri() =~ m/login/i) {

        # Location field in header is where we are being redirected.
        my $login_redir = auto_login($credentialsfile, $ua, $response->header("Location"));
        die "Failed to log in to modENCODE submission pipeline" unless $login_redir;
        $response = $ua->get($login_redir);
        die "Expected 200 OK after logging in, got $response->code" unless $response->code == 200;
    }

    my $gse = shift @geoids;
    my $gsm_str = join(" ", @geoids);

    print STDERR "="x120 . "\n";
    print STDERR "We are about to attach the following to submission $subid:\n";
    print STDERR "GSE: $gse\n";
    print STDERR "GSM: $gsm_str\n";
    print STDERR "="x120 . "\n";

    die "Could not find appropriate fields in attachment form" unless $ua->form_with_fields("geo_column", "gse", "gsms");
    $ua->field("gse", $gse);
    $ua->field("gsms", $gsm_str);
    my $commit_resp = $ua->click_button(name => "commit");
    $ua->form_number(1);
    $ua->click_button(value => 'Attach GEOids');
    print STDERR "GEOids attached for submission $subid.\n";
}

################################################################################
############################## ENTRY POINT #####################################
################################################################################
my $geoemail = shift;
my $credentialsfile = shift;
my $attachments = proc_email($geoemail);
my $ua = WWW::Mechanize->new(autocheck => 1, cookie_jar => {});
$ua->add_header( Connection => 'keep-alive' );

#print STDERR Dumper($attachments);

foreach (@ARGV) {
    my $subid = $_;

    print STDERR "\tCould not find submission $subid in our GEO email, skipping...\n" unless exists $attachments->{$subid};
    next unless exists $attachments->{$subid};

    fetch_sdrf($subid);

    #print Dumper($expts);
    my @geoids;
    push @geoids, $attachments->{$subid}->{"GSE"};

    my $sdrfmatrix = sdrf_to_matrix("$_.sdrf");
    my $samples = create_samples(trim_sdrf($sdrfmatrix));

    print STDERR "<><><><><><><>\n";
    print STDERR Dumper(map_gsms_to_samples($geoemail, $samples));

    # Shift the column titles off.
    shift @{$sdrfmatrix};
    print STDERR Dumper($sdrfmatrix);

    foreach my $sourcename (map {$_->[0]} @{$sdrfmatrix}) {
        my $sample;
        foreach (keys %{$samples}) {
            $sample = $samples->{$_} if $samples->{$_}->{"Sourcename"} eq $sourcename;
        }

        push @geoids, $attachments->{$subid}->{$sample->{"Type"}}->[$sample->{"Replicate"}];
    }
    print STDERR Dumper(\@geoids);
    attach_geoids(\@geoids, $subid, $credentialsfile, $ua);
}
