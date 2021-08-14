#!/usr/bin/env bash
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd "$SCRIPTPATH"/../static/*
ls | grep png | sed 's/.png//' | while read fileName; do 
    if [ ! -f "$fileName".webp ]; then 
        cwebp "$fileName".png -o "$fileName".webp
    fi
done
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd "$SCRIPTPATH"/../static/*
ls | grep jpg | sed 's/.jpg//' | while read fileName; do 
    if [ ! -f "$fileName".webp ]; then 
        cwebp "$fileName".jpg -o "$fileName".webp
    fi
done