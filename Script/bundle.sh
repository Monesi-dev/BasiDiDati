#!/bin/bash

files=("AreaContenuti.sql" "AreaFormato.sql" "AreaStreaming.sql" "AreaUtenti.sql" )
echo '' | cat > Bundle.sql

for value in "${files[@]}"
do
  cat ${value} >> Bundle.sql
  echo '' | cat >> Bundle.sql
  echo '' | cat >> Bundle.sql
done
