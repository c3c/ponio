#!/bin/bash

echo "################################"
echo "# How many lines did we write? #"
echo "################################"
echo ""

find . -type f \( ! \( -name "*.swf" -o -name "*.js" -o -name "stats.sh" \) \) -exec wc -l {} \; 2>/dev/null

echo ""
echo -n "For a total of: "

echo `find . -type f \( ! \( -name "*.swf" -o -name "*.js" -o -name "stats.sh" \) \) -exec cat {} \; 2>/dev/null | wc -l` lines "!!"
echo ""
echo "################################"
echo "# How many chars did we write? #"
echo "################################"
echo ""

find . -type f \( ! \( -name "*.swf" -o -name "*.js" -o -name "stats.sh" \) \) -exec wc -c {} \; 2>/dev/null

echo ""
echo -n "For a total of: "

echo `find . -type f \( ! \( -name "*.swf" -o -name "*.js" -o -name "stats.sh" \) \) -exec cat {} \; 2>/dev/null | wc -c` chars "!!"

echo "################################"
