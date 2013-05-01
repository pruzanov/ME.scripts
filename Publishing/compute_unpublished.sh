#!/bin/bash
# Assumes that ~/Data/nih_spreadsheet is the latest NIH spreadhseet and that the ~/Data/modencode-gbrowse_conf/
# directory contains the latest GBrowse conf files.
date=$(date +%m%d)
nihdir=$HOME/Data
listdir=$HOME/Data/lists

# Generate the list of released, published, unpublished and weird submissions as of the latest NIH spreadsheet.
# Submissions classified as weird are submissions that have been published, but have not been released somehow.
cat $nihdir/nih_spreadsheet | grep released | cut -f18 > $listdir/released_$date.txt
grep -R 'data source' $HOME/Data/modencode-gbrowse_conf/ | grep -v \# | cut -d '=' -f2 | grep -vi multiple | sed 's/ /\n/g' | sort -nu > $listdir/published_$date.txt
diff $listdir/released_$date.txt $listdir/published_$date.txt | grep '<' | cut -d ' ' -f2 | sort -nu > $listdir/unpublished_$date.txt
diff $listdir/published_$date.txt $listdir/released_$date.txt | grep '<' | cut -d ' ' -f2 | sort -nu > $listdir/weird_$date.txt

# Find the date that this script was previously effectively run for the purposes of comparing submissions.
#olddate=$(ls -tr $listdir | grep released | cut -d '_' -f2 | cut -d '.' -f1)
olddate=$(ls $listdir | grep released | sort | tail -n 2 | head -n 1 | cut -d '_' -f2 | cut -d '.' -f1)

# Compute the total and change in submissions since the last time this script was run, presumably on the previous
# version of the NIH spreadsheet.
total_released=$(wc -l < $listdir/released_$date.txt)
total_published=$(wc -l < $listdir/published_$date.txt) 
total_unpublished=$(wc -l < $listdir/unpublished_$date.txt)
total_weird=$(wc -l < $listdir/weird_$date.txt) 
delta_released=$(($total_released - $(wc -l < $listdir/released_$olddate.txt)))
delta_published=$(($total_published - $(wc -l < $listdir/published_$olddate.txt)))
delta_unpublished=$(($total_unpublished - $(wc -l < $listdir/unpublished_$olddate.txt)))
delta_weird=$(($total_weird - $(wc -l < $listdir/weird_$olddate.txt)))

# Print in a nice table!
printf "+-------------+-------+------+\n"
printf "| Category    | Delta | Total|\n"
printf "+-------------+-------+------+\n"
printf "| Released    | %5s | %4s |\n" "$delta_released" "$total_released"
printf "| Published   | %5s | %4s |\n" "$delta_published" "$total_published"
printf "| Unpublished | %5s | %4s |\n" "$delta_unpublished" "$total_unpublished"
printf "| Weird       | %5s | %4s |\n" "$delta_weird" "$total_weird"
printf "+-------------+-------+------+\n"
