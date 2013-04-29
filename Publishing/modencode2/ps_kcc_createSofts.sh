#!/bin/bash

for sub in "$@"
do
    mkdir -v $sub/
    perl chado2GEO.pl -unique_id $sub -out $sub/
done
