#!/bin/bash
for sub in "$@"
do
    cd $sub/
    scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*.fastq.bz2 .
    scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*.gff3 .
    cd ../
done
