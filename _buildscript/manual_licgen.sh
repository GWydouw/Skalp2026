#!/bin/sh

# rm -f "../licenses/${GUID}.lic"
#/home/skalpadmin/rubyencoder-2.0/bin/licgen --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL --const "LICENSE_TYPE=FULL" --const "GUID=${GUID}" --const "EMAIL=${EMAIL}" --const "USERNAME=${USERNAME}" --const "COMPANY=${COMPANY}" --const ${MAC} "../licenses/${USERNAME}.lic"



CREATELIC="
rm -f "../licenses/$1.lic"
/home/skalpadmin/rubyencoder-2.0/bin/licgen --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL --const "LICENSE_TYPE=FULL" --const "GUID=$1" --const "EMAIL=$2" --const "USERNAME=$3" --const "COMPANY=$4" --mac "$5" "/var/www/html/licenses/$1.lic"
"

ssh -p 65432 skalpadmin@license.skalp4sketchup.com "$CREATELIC"


#VOLLEDIG MANUEEL LICENTIE MAKEN:  (op server te runnen)

./licgen --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL --const "LICENSE_TYPE=FULL" --const "GUID=47ea2efb-e655-11e3-92bb-04011783dd01" --const "EMAIL=georg.lindorfer@servus.at" --const 'USERNAME=Georg Lindorfer' --const "COMPANY=Bühnenbildner" --mac 84:2B:2B:B7:C5:93 "/var/www/html/licenses/MAN_47ea2efb-e655-11e3-92bb-04011783dd01.lic"
./licgen --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL --const "LICENSE_TYPE=FULL" --const "GUID=d20e9b0e-141e-11e5-a04a-04011783dd01" --const "EMAIL=robert.powell@arup.com" --const 'USERNAME=Robert Powell' --const "COMPANY=Arup" --mac 9C:B7:0D:EE:E1:B0 "/var/www/html/licenses/MAN_d20e9b0e-141e-11e5-a04a-04011783dd01.lic"

#MANUEEL LICENTIE NAKIJKEN:     (op server te runnen)
/home/skalpadmin/rubyencoder-2.0/bin/
./rginfo --projid s353DaIOwXj3SZIRoqtA "/var/www/html/licenses/5dc0c8b0-ebfc-11e3-b976-04011783dd01.lic"
./rginfo --projid s353DaIOwXj3SZIRoqtA "/var/www/html/licenses/MAN_d20e9b0e-141e-11e5-a04a-04011783dd01.lic"
/home/skalpadmin/rubyencoder-2.0/bin/rginfo --projid s353DaIOwXj3SZIRoqtA "/var/www/html/licenses/47ea2efb-e655-11e3-92bb-04011783dd01.lic"

Trial voor Guy:
./licgen --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL --const "LICENSE_TYPE=TRIAL" --const "GUID=5dc0c8b0-ebfc-11e3-b976-04011783dd01" --const "EMAIL=guy@wydouw.be" --const "USERNAME=guywydouw" --const "COMPANY=wydouw" --days 365 --mac 32:00:13:b7:fd:a0 ../guytrialeenjaar.lic
./licgen --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL --const "LICENSE_TYPE=TRIAL" --const "GUID=5dc0c8b0-ebfc-11e3-b976-04011783dd01" --const "EMAIL=guy@wydouw.be" --const "USERNAME=guywydouw" --const "COMPANY=wydouw" --expire 10/09/2014 --mac 32:00:13:b7:fd:a0 ../guytrialexpired.lic

FUll voor Guy:
./licgen --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL --const "LICENSE_TYPE=FULL" --const "GUID=b3cbac30-e68a-11e3-92bb-04011783dd01" --const "EMAIL=guy@wydouw.be" --const 'USERNAME=Guy Wydouw' --const "COMPANY=Architectuurburo Wydouw bvba" --mac b8:f6:b1:12:c4:b5 --mac 32:00:13:B7:FD:A0 "/var/www/html/licenses/Guynew.lic"