#!/bin/bash
# Upload GFF's to the karpen DB after testing on the ali DB.

for sub in "$@"
do
    cd $sub/
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d karpen *.gff3
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d karpen *.gff
    cd ../
done
