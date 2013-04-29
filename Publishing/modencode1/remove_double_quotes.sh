#!/bin/bash

for sub in "$@"
do
    cd $sub/
    sed -i 's/Name="/Name=/g' VISTA*gff3
    sed -i 's/";/;/g' VISTA*gff3
    cd ../
done
