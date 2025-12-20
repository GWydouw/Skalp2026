#!/bin/sh
INPUT="$2"
OUTPUT="$1"
echo '__________'
echo "Cleaning output directory:"
echo "${OUTPUT}"
rm -dfrv "${OUTPUT}"
mkdir "${OUTPUT}"
echo '__________'

INITSERVER="
rm -dfrv /home/skalpadmin/rbin/
mkdir /home/skalpadmin/rbin/
"
CLEANSERVER="
rm -dfrv /home/skalpadmin/rbin/
"

ENCODEFILES="
INPUTDIR=/home/skalpadmin/rbin;
/home/skalpadmin/rubyencoder-3.0/bin/rubyencoder \
--ruby 3.2 -r \
--external ./Skalp.lic \
--rails \
--const "SKALP_EXPIRE=12/30/2099" \
--projid s353DaIOwXj3SZIRoqtA \
--projkey 91buLYpxAjWPjrbyw0UL \
-p '# Copyright (C) 2014 - 2025 Skalp, All rights reserved.;
Skalp::remove_wrong_rgloader;Dir.chdir(Skalp::SKALP_PATH);' \
-j '_f = (\"./eval/loader.rb\"); load _f and break;' \
-b- \
"\$INPUTDIR/*.rb"
"

ssh skalpadmin@builder.skalp4sketchup.com "$INITSERVER"

scp -r "${INPUT}"*.rb skalpadmin@builder.skalp4sketchup.com:/home/skalpadmin/rbin/ # copy local dir mypath to remote

ssh skalpadmin@builder.skalp4sketchup.com "$ENCODEFILES"

scp -r skalpadmin@builder.skalp4sketchup.com:/home/skalpadmin/rbin/*.rb "${OUTPUT}" # copy remote output path back to local

ssh skalpadmin@builder.skalp4sketchup.com "$CLEANSERVER"

rm -dfrv "${INPUT}"
mkdir "${INPUT}"
