#!/bin/bash
# Upload GFF's to the karpen DB after testing on the ali DB.
bp_seqfeature_load.pl -u modencode -p modencode+++ -d karpen *.gff3
bp_seqfeature_load.pl -u modencode -p modencode+++ -d karpen *.gff
