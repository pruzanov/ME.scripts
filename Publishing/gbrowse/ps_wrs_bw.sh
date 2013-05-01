#!/bin/bash

for sub in "$@"
do
    cd $sub/
    wigToBigWig.pl *raw_covg.wig chrom.sizes "$sub\_rawcovg.bw"
    wigToBigWig.pl *win_covg.wig chrom.sizes "$sub\_wincovg.bw"
    cd ../
done
