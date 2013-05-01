#!/bin/bash

EXPECTED=4
if [ $# -ne $EXPECTED ]
then
    echo "Need four parameters. Look at code."
    exit -1
fi

# Parameters
# $1 - Submission ID
# $2 - BigWig track ID
# $3 - GFF track ID
# $4 - Track name

# Check for neccessary files.
if [ ! -e ../my.conf ]
then
    echo "../my.conf not found!"
    exit -1
fi

# Remove unnecessary files.
rm -v *cleaned*
rm -v *Mvalues*
rm -v *.gff3

# Removed unnecessary GFF files.
mv "$3.gff" ..
rm -v *.gff
mv "../$3.gff" .

# Remove all chr prefixes from the WIG file, convert it to a BigWig then delete the original WIG.
sed -i 's/chr//g' *.wig
wigToBigWig.pl *.wig ~/Data/fly_chrom.sizes "$2.bw"
rm -v *.wig

# Generate the VISTA GFF3 file and edit it as required.
cd ../
dir2load_gff.pl $1 > "VISTA:$2.gff3"
mv "VISTA:$2.gff3" $1/
cd $1/
sed -i "s/VISTA:/binding_site:/g" "VISTA:$2.gff3"
sed -i "s/Name[^;]*/Name=$4/g" "VISTA:$2.gff3"

# Copy the cheap placeholder .conf file and edit it as required.
cp ../my.conf "$1.conf"
sed -i "s/CHROMPROT_3954/CHROMPROT_$1/g" "$1.conf"
sed -i "s/VISTA\:16020/VISTA\:$2/g" "$1.conf"
sed -i "s/16020 16021/$2 $3/g" "$1.conf"
sed -i "s/3952/$1/g" "$1.conf"
sed -i "s/16020/$2/g" "$1.conf"

# Clean up directory.
rm -v tempgff*

# Upload to the modencode server.
cd ..
scp -r $1/ modencode:~/tmp/
