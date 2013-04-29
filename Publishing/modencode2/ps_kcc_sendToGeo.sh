#!/bin/bash

for sub in "$@"
do
    perl /u/aramadhan/reporter_seq/chado2GEO.pl -unique_id $sub -out $sub/ -use_existent_metafile 1 -use_existent_tarball 1 -send_to_geo 1
done
