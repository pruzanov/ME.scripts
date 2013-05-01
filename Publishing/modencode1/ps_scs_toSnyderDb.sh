#!/bin/bash
# Upload GFF's to the snyder DB after testing on the ali DB.

for sub in "$@"
do
    cd $sub/
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d snyder *.gff3
    bp_seqfeature_load.pl -u modencode -p modencode+++ -d snyder *.gff
    cd ../
done
