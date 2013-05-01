#!/bin/bash

for sub in "$@"
do
    cd $sub/
    rm *.soft
    rename -v 's/\.softer//' *.softer
    tar -cvzf modencode_$sub.tar.gz *.soft *.zip *.wig
    cd ../
done
