#!/bin/bash

EXPECTED_ARGS=1
if [ $# -ne $EXPECTED_ARGS ]
then
    echo "This script requires exactly one parameters!"
    echo "SYNTAX: ps_kcs_gbrowse.sh <track_name>"
    exit -1
fi

sub=$(basename $(pwd))
name=$1

# Rename BAM file.
mv -v *.bam "submission_$sub.sorted.bam"
mv -v *.bai "submission_$sub.sorted.bam.bai"

mkdir -v "rawnorm" # Raw normalized.
cd "rawnorm/"

# Find track ID for raw normalized bigWig.
track=$(grep "$sub" ~/sandbox/subs.map | cut -f2)

if [ "$track" == "" ]
then
    echo "No track ID for submission $sub found in $HOME/Data/subs.map!"
    exit -1
fi

echo "Found raw normalized track ID: $track"
cp -v "../$track.bw" .

# ---

# Create and edit VISTA gff3 appropriately.
echo "Creating VISTA gff3..."
cd ../
dir2load_gff.pl $sub > "VISTA:$trackid.gff3"
mv -v "VISTA:$trackid.gff3" $sub/
cd $sub/

sed -i "s/Name[^;]*/Name=$name/g" "VISTA:$trackid.gff3"
sed -i "s/peak_type=\"\"/peak_type=binding_site:${trackid}_details/g" "VISTA:$trackid.gff3"

# Copy the placeholder .conf and edit it as required.
echo "Creating GBrowse .conf file..."
cp -v "$HOME/sandbox/scs.conf" "./$sub.conf"
sed -i "s/4625/$sub/g" "$sub.conf"
sed -i "s/18079/$trackid/g" "$sub.conf"

# Clean up directory.
rm -v tempgff*

# Upload to the modencode server.
cd ..
scp -r $sub/ modencode:~/subs/
