#!/usr/bin/env bash
SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd "$SCRIPTPATH"/../docs/css/
rm home.min.css
rm page.min.css
cd "$SCRIPTPATH"/../
hugo