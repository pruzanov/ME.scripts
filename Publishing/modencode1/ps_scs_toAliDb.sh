#!/bin/bash
# Upload the GFF's to the ali DB and all the files to their proper directory for sandbox testing.

for sub in "$@"
do
    cd $sub/
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d ali *.gff3
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d ali *.gff
    cp -v *.bw /browser_data/worm/wiggle_binaries/snyder/
    cp -v *.conf ~/public_html/conf/snyder_conf/
    rm -v *.bw
    cd ../
done
