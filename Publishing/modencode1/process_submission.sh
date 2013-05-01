#!/bin/bash
#bp_seqfeature_load.pl -u modencode -p modencode+++ -d celniker_dpse *.gff3
cp -v *.bw /browser_data/fly/wiggle_binaries/celniker/
cp -v *.bam /browser_data/fly/sam_binaries/Celniker/
cp -v *.bai /browser_data/fly/sam_binaries/Celniker/
rm -i *.bw
rm -i *.bam
rm -i *.bai
