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
    cat "$sub.stanza" | grep -i 'gff3' | grep 'combined' | grep -oE 'binding_site.*' | cut -d ':' -f2 | tr '\n' ',' | sed 's/,$//'
    echo -ne "\n"
done
