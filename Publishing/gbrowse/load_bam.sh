#!/bin/bash

for sub in "$@"
do
    if [ ! -d "$sub" ]; then
        mkdir -v $sub
    fi
    cd $sub/
    # Karpen ChIP-chip (Affymetrix microarray)
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*IDF* .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*SDRF* .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*smoothedM.wig .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/tracks/*.gff .

    # Karpen ChIP-seq (Solexa)
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*IDF* .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*SDRF* .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/tracks/*.gff .
    #scp xfer.res.oicr.on.ca:~/scratch/$sub/*bam* .

    # Snyder ChIP-seq
    scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*/*.idf .
    scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*/*.sdrf .
    scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*/*.wig .
    scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/tracks/*.gff .

    # Waterston coverage
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*idf* .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*sdrf* .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/tracks/*bam* .
    #scp modencode-www2.oicr.on.ca:/modencode/raw/data/$sub/extracted/*wig .
    cd ../
done
