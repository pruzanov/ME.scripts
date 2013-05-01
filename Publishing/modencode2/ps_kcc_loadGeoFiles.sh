#!/bin/bash
for sub in "$@"
do
    cd $sub/
    scp modencode-www1.oicr.on.ca:/modencode/raw/data/$sub/extracted/*.zip .
    scp modencode-www1.oicr.on.ca:/modencode/raw/data/$sub/extracted/*.smoothedM.wig .
    scp modencode-www1.oicr.on.ca:/modencode/raw/data/$sub/extracted/*.Mvalues.wig .
    cd ../
done
