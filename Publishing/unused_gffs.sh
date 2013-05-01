#!/bin/bash

EXPECTED_ARGS=2
if [ $# -ne $EXPECTED_ARGS ]
then
    echo "This script requires exactly two parameters!"
    echo "SYNTAX: unused_gffs.sh <nih_spreadsheet> <modencode_raw_data_dir>"
    exit -1
fi

nih_spreadsheet=$1
raw_data_dir=$2

# Find and store the submission ID of all released submissions.
subs=$(cat $nih_spreadsheet | sed 1d | grep 'released' | cut -f18 | grep -vE 'superseded|deprecated' | sort -n | uniq)

for sub in "$subs"
do
    # Find and store the file names of all gff files in the submission's extracted/ folder.
    gffs_extracted=$(find "$sub/extracted/" -iname *gff* -printf '%f\n')
    num_gffs_extracted=$(echo "$gffs_extracted" | wc -l)

    # Find the submission's SDRF. It might find multiple SDRF files if they exist!
    sdrf=$(find "$sub/" -iname '*sdrf*.txt' -o -iname '*.sdrf')

    # Find and store the file names of all gff files mentioned in the submission's SDRF.
    gffs_sdrf=$(cat $sdrf | sed 1d | tr '\t' '\n' | grep 'gff' | uniq)
    num_gffs_sdrf=$(echo "$gffs_sdrf" | wc -l)

    if [ $num_gffs_extracted -gt $num_gffs_sdrf ]
    then
        echo "[$sub] $(($num_gffs_extracted - $num_gffs_sdrf)) gff file(s) not used in SDRF!"
        for gff in "$gffs_extracted"
        do
            if [[ ! $gffs_sdrf =~ $gff ]]
            then
                echo "[$sub] |- $gff"
            fi
        done
    elif [ $num_gffs_extracted -lt $num_gffs_sdrf ]
    then
        echo "[$sub] $(($num_gffs_sdrf - $num_gffs_extracted)) gff file(s) not in extracted/ directory!"
        for gff in "$gffs_sdrf"
        do
            if [[ ! $gffs_extracted =~ $gff ]]
            then
                echo "[$sub] |- $gff"
            fi
        done
    fi
done
