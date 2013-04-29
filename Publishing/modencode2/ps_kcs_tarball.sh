#!/bin/bash

for sub in "$@"
do
    cd $sub/
    rm -v *.soft
    rename -v 's/\.softer//' *.softer
    tar -cvzf modencode_$sub.tar.gz *.soft *.bz2 *.gff3
    cd ../
done
