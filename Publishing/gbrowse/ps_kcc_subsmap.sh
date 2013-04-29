#!/bin/bash

for sub in "$@"
do
    echo -n $sub
    echo -ne "\t"
    grep smoothedM "$sub.stanza" | grep -oE 'bigwig.*' | cut -d ':' -f2 | tr '\n' ',' | sed 's/,$//'
    echo -ne "\t"
    grep binding_site "$sub.stanza" | grep -v gff3 | grep key | grep -oE 'binding_site.*' | cut -d ':' -f2 | tr '\n' ',' | sed 's/,$//'
    echo -ne "\n"
done
