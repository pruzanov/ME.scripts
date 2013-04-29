#!/bin/bash

for sub in "$@"
do
    echo -ne "$sub\t"
    echo -ne "$(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f1)\t"
    echo -e "$(cat $HOME/Data/nih_spreadsheet | awk -v s=$sub 'BEGIN { FS = "\t" } $18 == s' | cut -f1)"
done
