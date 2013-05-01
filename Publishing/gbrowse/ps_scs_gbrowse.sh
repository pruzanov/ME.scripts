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

# Remove unneccesary WIGs.
shopt -s nocaseglob
rm -v *cleaned*.wig
rm -v *Input*.wig
rm -v *rep*.wig
shopt -u nocaseglob

wigToBigWig.pl *.wig ~/Data/worm_chrom.sizes "sub_$sub.bw"
rm -v *.wig

# Find this submission's track ID.
trackid=$(cat $HOME/sandbox/subs.map | grep "$sub" | cut -f2)

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
cp -v "$HOME/sandbox/scs.conf" "./$sub.conf"
sed -i "s/4625/$sub/g" "$sub.conf"
sed -i "s/18079/$trackid/g" "$sub.conf"

# Clean up directory.
rm -v tempgff*

# Upload to the modencode server.
cd ..
scp -r $sub/ modencode:~/subs/
