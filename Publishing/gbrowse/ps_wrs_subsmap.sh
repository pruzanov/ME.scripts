#!/bin/bash

cd $HOME/sandbox/cache

for sub in "$@"
do
    if [ ! -f "$sub.stanza" ];
    then
        cd ../
        echo "Grabbing .stanza for $sub..."
        merge_cites $sub > /dev/null
        cd cache/
    fi

    echo -n $sub
    echo -ne "\t"
    cat "$sub.stanza" | grep -i 'raw_normalized_covg.wig' | grep -oE 'bigwig.*' | cut -d ':' -f2 | tr '\n' ',' | sed 's/,$//'
    echo -ne "\n"
done
