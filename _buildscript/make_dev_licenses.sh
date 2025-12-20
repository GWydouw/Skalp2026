#!/bin/sh
OUTPUT="$1"
echo '__________'
echo "Cleaning output directory:"
echo "${OUTPUT}"
rm -dfrv "${OUTPUT}"
mkdir "${OUTPUT}"
echo '__________'

LICGEN="/home/skalpadmin/rubyencoder-2.0/bin/licgen"
SKALPKEYS="--projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL"
TEMPDIR="/home/skalpadmin/rbin/"

GUIDGUY="b3cbac30-e68a-11e3-92bb-04011783dd01"
MACGUY="--mac 32:00:13:b7:fd:a0"
GUYCONSTANTS="--const "GUID=${GUIDGUY}" ${MACGUY} --const "EMAIL=guy@skalp4sketchup.com" --const "USERNAME=Guy_Wydouw" --const "COMPANY=Skalp""

GUIDJEROEN="8155843e-4d4a-11e4-bae0-04011783dd01"
MACJEROEN="--mac E0:F8:47:31:9C:CC --mac 20:C9:D0:96:A4:69 --mac c8:2a:14:02:a4:1a"
JEROENCONSTANTS="--const "GUID=${GUIDJEROEN}" ${MACJEROEN} --const "EMAIL=jeroen@skalp4sketchup.com" --const "USERNAME=Jeroen_Theuns" --const "COMPANY=Skalp""

INITSERVER="
rm -dfrv ${TEMPDIR}
mkdir ${TEMPDIR}
"

CLEANSERVER="
rm -dfrv ${TEMPDIR}
"

GETDEVLICENSES="
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=FULL" ${GUYCONSTANTS} ${TEMPDIR}Guy.lic_full ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=TRIAL" --const "SKALP_TRIAL_EXPIRE=12/01/2014" ${GUYCONSTANTS} --days 365 ${TEMPDIR}Guy.lic_trial ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=TRIAL" --const "SKALP_TRIAL_EXPIRE=09/01/2014" ${GUYCONSTANTS} --expire 10/9/2014 ${TEMPDIR}Guy.lic_trial_full_expired ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=TRIAL" --const "SKALP_TRIAL_EXPIRE=09/01/2014" ${GUYCONSTANTS} --days 365 ${TEMPDIR}Guy.lic_trial_expired ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=EDU" --const "SKALP_TRIAL_EXPIRE=12/01/2014" ${GUYCONSTANTS} --days 365 ${TEMPDIR}Guy.lic_edu ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=RESELLER" --const "SKALP_TRIAL_EXPIRE=12/01/2014" ${GUYCONSTANTS} --days 365 ${TEMPDIR}Guy.lic_reseller ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=FULL" ${JEROENCONSTANTS} ${TEMPDIR}Jeroen.lic_full ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=TRIAL" --const "SKALP_TRIAL_EXPIRE=12/01/2014" ${JEROENCONSTANTS} --days 365 ${TEMPDIR}Jeroen.lic_trial ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=TRIAL" --const "SKALP_TRIAL_EXPIRE=09/01/2014" ${JEROENCONSTANTS} --expire 10/9/2014 ${TEMPDIR}Jeroen.lic_trial_full_expired ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=TRIAL" --const "SKALP_TRIAL_EXPIRE=09/01/2014" ${JEROENCONSTANTS} --days 365 ${TEMPDIR}Jeroen.lic_trial_expired ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=EDU" --const "SKALP_TRIAL_EXPIRE=12/01/2014" ${JEROENCONSTANTS} --days 365 ${TEMPDIR}Jeroen.lic_edu ;
${LICGEN} ${SKALPKEYS} --const "LICENSE_TYPE=RESELLER" --const "SKALP_TRIAL_EXPIRE=12/01/2014" ${JEROENCONSTANTS} --days 365 ${TEMPDIR}Jeroen.lic_reseller ;
"
ssh -p 65432 skalpadmin@license.skalp4sketchup.com "$INITSERVER"
ssh -p 65432 skalpadmin@license.skalp4sketchup.com "$GETDEVLICENSES"
scp -P 65432 -r skalpadmin@license.skalp4sketchup.com:/home/skalpadmin/rbin/*.* "${OUTPUT}" # copy remote output path back to local
ssh -p 65432 skalpadmin@license.skalp4sketchup.com "$CLEANSERVER"
