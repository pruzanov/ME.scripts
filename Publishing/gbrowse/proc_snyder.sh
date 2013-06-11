#!/bin/bash

# The following bash script processes Snyder submissions.

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
TEMPLATEFILE="/home/rdevilla/Scripts/ME.scripts/Templates/Snyder/snyder_vista_template.csv"

exec 2>&1

# Processing common to ChIP-chip and ChIP-seq submissions.
prologue ()
{
  cd ~/Data
  echo "Processing submission $SUBID..."

  # Get signal and peak/binding site track IDs

  SIGID=$(merge_cites "$SUBID" &>/dev/null; grep '^key ' cache/$SUBID.stanza | grep -v 'Input' | grep 'combined' | grep 'bigwig' | cut -d':' -f2)
  PEAKID=$(merge_cites "$SUBID" &>/dev/null; grep '^key ' cache/$SUBID.stanza | grep -v 'Input' | grep 'combined' | grep 'binding_site' | cut -d':' -f2)

  # We didn't find a PEAKID; this appears to be a special case with certain Snyder submissions with different naming conventions.
  if ! [[ "$PEAKID" =~ ^[0-9]+$ ]]; then
    PEAKID=$(merge_cites "$SUBID" &>/dev/null; grep '^key ' cache/$SUBID.stanza | grep 'binding_site' | grep -iv 'rep' | grep -i 'gff3' | cut -d':' -f2)

  fi

  echo "	Found signal track $SIGID and peak track $PEAKID"

  # Map these to the submission ID; remove duplicate lines first
  sed -i "/$SUBID/d" "$MAPFILE"
  echo "$SUBID	$SIGID	$PEAKID" >> "$MAPFILE"
  echo "	Adding line: \"$SUBID	$SIGID	$PEAKID\" to $MAPFILE"

  # Remove bigwig tracks not mapped in $MAPFILE
  find "$SUBID" -type f | grep -v "$PEAKID\|$SIGID" | grep -v "$SUBID/.*$SUBID.*" | grep -vi "SDRF\|IDF" | xargs -I '{}' rm -v '{}'; rm "$SUBID"/*binding_site* -v;

  # Generate the loader GFF.
  dir2load_gff.pl "$SUBID" > "VISTA_$SUBID.gff"
  mv "VISTA_$SUBID.gff" "$SUBID/VISTA_$SUBID.gff"

  # Merge the peaks GFF and loader GFF together.
  merge_gff.sh "$SUBID" >> "$LOGFILE" 2>&1

  # Fix the "Name=" attribute in the new loader GFF.
  fix_snyder_gff_name.sh "$SUBID"

  # Try to automatically generate fields for template_filler
  # We will not actually use the template_filler generated stanza for
  # production; testing purposes only
  FIELD_NAME="$(grep 'VISTA' "$SUBID/VISTA_$SUBID.gff" | cut -f9 | cut -d';' -f1 | cut -d'=' -f2 | sed -n '1p')"
  FIELD_KEY="$(sed -n '2p' "cache/$SUBID.stanza" | cut -d' ' -f5  | sed 's/Snyder_//g' | sed 's/_GFP.*//g') Combined (GFP ChIP)"
  FIELD_DS=$SUBID
  FIELD_TS=$(grep "$SUBID" "$MAPFILE" | cut -f2- | sed 's/	/ /g')

  FIELD_CAT="Transcription Factors: GFP ChIP"
  FIELD_SEL=NA

  #if [ $BIGWIGS -eq 1 ]; then
  echo "$FIELD_NAME	$FIELD_KEY	$FIELD_DS	$FIELD_TS	$FIELD_CAT	$FIELD_SEL" > "$SUBID/$SUBID.fields"
  #fi
  echo "	Using $TEMPLATEFILE, writing to $SUBID/$SUBID.fields"

  # For use with add_subtracks.pl:
  echo "$FIELD_NAME	$SUBID	$SIGID	$PEAKID" >> "$DATADIR/add_subtracks.map"
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
