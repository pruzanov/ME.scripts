#!/bin/bash

for sub in "$@"
do
    cd $sub/
    CMD=$(cat ~/.bash_history | grep $sub | grep ps_karpen_gbrowse.sh | grep -v grep | tail -n 1 | sed 's/gbrowse/vista/')
    $CMD
    cd ../
done
