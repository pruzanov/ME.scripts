#!/bin/bash
# Upload the GFF's to the ali DB and all the files to their proper directory for sandbox testing.

for sub in "$@"
do
    cd $sub/
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d ali *.gff3
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d ali *.gff
    cp -v *.bw /browser_data/fly/wiggle_binaries/karpen/
    cp -v *.conf ~/public_html/conf/karpen_conf/
    rm -i *.bw
    cd ../
done
