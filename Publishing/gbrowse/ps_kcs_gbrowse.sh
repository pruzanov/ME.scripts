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

# Exit early if no BigWig file was found, we need one to publish these
# submissions.
if [ ! -e "sub_$sub.bw" ]
then
    echo "No BigWig file found!"
    exit -1
fi

# Remove unnecessary files.
rm -v chrom_sizes.txt
rm -v gbrowse.conf
rm -v *bam*

# Find this submission's track ID.
trackid=$(cat $HOME/Data/subs.map | grep "$sub" | cut -f2)

if [ "$trackid" == "" ]
then
    echo "No track ID for submission $sub found in $HOME/Data/subs.map!"
    exit -1
fi

echo "Found track ID: $trackid"

# Only keep the .gff we need.
mv -v "$trackid.gff" ../
rm -v *.gff
mv -v "../$trackid.gff" ./

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
cp -v "$HOME/sandbox/kcs.conf" "./$sub.conf"
sed -i "s/3953/$sub/g" "$sub.conf"
sed -i "s/15059/$trackid/g" "$sub.conf"

# Clean up directory.
rm -v tempgff*

# Upload to the modencode server.
cd ..
scp -r $sub/ modencode:~/subs/
