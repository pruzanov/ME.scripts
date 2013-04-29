#!/bin/bash

for sub in "$@"
do
    cd $sub/
    bamToGBrowse.pl . ~/Data/D.\ Melanogaster/dmel-all-chromosome-r5.22.fasta
    mv -v *.bw "sub_$sub.bw"
    cd ../
done
