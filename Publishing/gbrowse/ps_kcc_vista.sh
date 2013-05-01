#!/bin/bash

EXPECTED=4
if [ $# -ne $EXPECTED ]
then
    echo "Need four parameters. Look at code."
    exit
fi

# Parameters
# $1 - Submission ID
# $2 - BigWig track ID
# $3 - GFF track ID
# $4 - Track name

# Generate the VISTA GFF3 file and edit it as required.
cd ../
dir2load_gff.pl $1 > "VISTA:$2.gff3"
mv "VISTA:$2.gff3" $1/
cd $1/
sed -i "s/VISTA:/binding_site:/g" "VISTA:$2.gff3"
sed -i "s/Name[^;]*/Name=$4/g" "VISTA:$2.gff3"

# Clean up directory.
rm -v tempgff*

# Upload to the modencode server.
scp "./VISTA:$2.gff3" modencode:~/tmp/$1/
