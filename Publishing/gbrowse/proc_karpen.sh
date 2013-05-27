#!/bin/bash

# The following bash script processes Karpen ChIP-chip and ChIP-seq submissions.
# It takes as arguments a space-separated list of submission IDs, and then descends into
# each submission's directory, generating a GBrowse conf, a loader (VISTA) GFF,
# and merges BAM files if necessary. This script can also upload the necessary
# files to the modENCODE host.

# ATTN: CONFIGURE THE LOGFILE VAR AT THE BOTTOM OF THIS SCRIPT.
# TODO: MOVE THE LOGFILE VAR UP HERE.

# DATADIR should be the directory in which the raw modENCODE data is stored;
# Directory structure should be as follows:
#
# > DATADIR
# 	-> 1001
#	-> 1002
#	-> ...
#
# Where each submission is stored in a directory named after its pipeline submission ID.
DATADIR="/home/rdevilla/Data"

# MAPFILE is a tab-delimited table expecting the following 3 fields:
# [SUBMISSION ID]	[SIGNAL TRACK ID]	[PEAK TRACK ID]
MAPFILE="/home/rdevilla/Data/sub-sig-peak.map"

# Template to use for template_filler.
TEMPLATEFILE="/home/rdevilla/Scripts/ME.scripts/Templates/Karpen/karpen_vista_template.csv"

exec 2>&1

# Processing common to ChIP-chip and ChIP-seq submissions.
prologue ()
{
  cd ~/Data
  echo "Processing submission $SUBID..."

  # Get signal and peak/binding site track IDs

  SIGID=$(merge_cites "$SUBID" &>/dev/null; grep '^key ' "cache/$SUBID.stanza" | grep 'smoothedM.wig' | sed 's/.*bigwig/bigwig/' | cut -d':' -f2)
  echo $SIGID | grep -q '^[0-9]\+$'
  if [ $? -ne 0 ]; then
    echo "	No bigwigs for this submission!"
    PEAKID=$(merge_cites "$SUBID" &>/dev/null; grep '^key ' "cache/$SUBID.stanza" | grep 'repset' | sed 's/.*binding_site/binding_site/' | cut -d':' -f2)
    SIGID=$PEAKID
    BIGWIGS=0
  else
    PEAKID=$(merge_cites "$SUBID" &>/dev/null; grep '^key ' "cache/$SUBID.stanza" | grep 'binding_site' | grep -v 'smoothedM' | sed 's/.*binding_site/binding_site/' | cut -d':' -f2)
    BIGWIGS=1
  fi

  echo "	Found signal track $SIGID and peak track $PEAKID"

  # Map these to the submission ID; remove duplicate lines first
  sed -i "/$SUBID/d" "$MAPFILE"
  echo "$SUBID	$SIGID	$PEAKID" >> "$MAPFILE"
  echo "	Adding line: \"$SUBID	$SIGID	$PEAKID\" to $MAPFILE"

  if [ $BIGWIGS -eq 0 ]; then
    chipseq_subroutine
  fi

  epilogue
}

# Subroutine to do additional processing on ChIP-seq submissions
chipseq_subroutine ()
{
    process_subs "$SUBID" >> "$LOGFILE" 2>&1
    find "$SUBID" -type f \( -iname '*bam*' ! -iname 'sub*' \) -print0 | xargs -0 rm -v
    ps_kcs_bw.sh "$SUBID"
}

# For ChIP-chip, runs immediately after the prologue(). For ChIP-seq,
# execution will move from prologue() -> chipseq_subroutine -> epilogue().
epilogue ()
{
  # Remove bigwig tracks not mapped in $MAPFILE
  find "$SUBID" -type f | grep -v "$PEAKID\|$SIGID" | grep -v "$SUBID/.*$SUBID.*" | grep -vi "SDRF\|IDF" | xargs -I '{}' rm -v '{}'; rm "$SUBID"/*binding_site* -v;

  # Generate the loader GFF.
  dir2load_gff.pl "$SUBID" > "VISTA_$SUBID.gff"
  mv "VISTA_$SUBID.gff" "$SUBID/VISTA_$SUBID.gff"

  # Merge the peaks GFF and loader GFF together.
  merge_gff.sh "$SUBID" >> "$LOGFILE" 2>&1

  # Try to automatically generate fields for template_filler
  # We will not actually use the template_filler generated stanza for
  # production; testing purposes only
  FIELD_NAME=$(sed -n '2p' "cache/$SUBID.stanza" | cut -d' ' -f5)
  FIELD_KEY=$FIELD_NAME
  FIELD_DS=$SUBID
  FIELD_TS=$(grep "$SUBID" "$MAPFILE" | cut -f2- | sed 's/	/ /g')

  # TODO: Don't hardcode this!
  if [ $BIGWIGS -eq 0 ]; then
    FIELD_CAT="Chromatin Structure: Chromatin Proteins:ChIP-seq (Grouped by Cell Line)"
  else
    FIELD_CAT="Chromatin Structure: Chromatin Proteins:ChIP-chip (Grouped by Cell Line)"
  fi
  FIELD_SEL=NA

  #if [ $BIGWIGS -eq 1 ]; then
  echo "$FIELD_NAME	$FIELD_KEY	$FIELD_DS	$FIELD_TS	$FIELD_CAT	$FIELD_SEL" > "$SUBID/$SUBID.fields"
  #fi
  echo "	Using $TEMPLATEFILE, writing to $SUBID/$SUBID.fields"
  template_filler "$TEMPLATEFILE" "$SUBID/$SUBID.fields" > "$SUBID/$SUBID.conf"
}

# Uploads GBrowse config, bigwigs, and loader GFF to modencode host.
# Also, loads the GFF into the SeqFeature DB.
#upload ()
#{
#  #echo "	Copying $SUBID/$SUBID.conf to rdevilla@modencode.oicr.on.ca:~/public_html/conf/karpen_conf/$SUBID.conf"
#  #scp "$SUBID/$SUBID.conf" "rdevilla@modencode.oicr.on.ca:/home/rdevilla/public_html/conf/karpen_conf/$SUBID.conf"
#  #echo "	Copying $SUBID/$SIGID.bw to rdevilla@modencode.oicr.on.ca:/browser_data/fly/wiggle_binaries/karpen/$SIGID.bw"
#  #scp "$SUBID/$SIGID.bw" "rdevilla@modencode.oicr.on.ca:/browser_data/fly/wiggle_binaries/karpen/$SIGID.bw"
#  #echo "	Copying $SUBID/VISTA_$SUBID.gff to rdevilla@modencode.oicr.on.ca:~/Data/VISTA_$SUBID.gff"
#  #scp "$SUBID/VISTA_$SUBID.gff" "rdevilla@modencode.oicr.on.ca:/home/rdevilla/Data/VISTA_$SUBID.gff"
#  #
#  #echo "	Loading $SUBID/VISTA_$SUBID.gff into SeqFeatures DB"
#  #ssh rdevilla@modencode.oicr.on.ca "bp_seqfeature_load.pl -d ryantesting -u modencode -p modencode+++ /home/rdevilla/Data/VISTA_$SUBID.gff"
#}


for sub in "$@"
do
  SUBID="$sub"
  LOGFILE="/home/rdevilla/var/log/$(date +%Y-%m-%dT%H:%M:%S)_$SUBID.log"
  prologue
done
