#!/bin/sh

classpathmunge () {
	if ! echo $CLASSPATH | /bin/egrep -q "(^|:)$1($|:)" ; then
	   if [ "$2" = "after" ] ; then
	      CLASSPATH=$CLASSPATH:$1
	   else
	      CLASSPATH=$1:$CLASSPATH
	   fi
	fi
}
#set basic env
JAVA_HOME=/usr/local/java/jdk1.8.0_11

libdir="./lib"


# Build the CLASSPATH
# Look for jar files.
for f in $(find $libdir -name '*.jar' -print)
do
  classpathmunge $f
done
# Look for zip files.
for f in $(find $libdir -name '*.zip' -print)
do
  classpathmunge $f
done

classpathmunge ./config

# Set up the environment
export CLASSPATH

MAIN_CLZ=cn.bctrustmachine.fabric.sdkintegration.ChaincodePosSlip


$JAVA_HOME/bin/java \
-Dorg_name=$HFCJ_ORG_NAME \
-Dsdktest_configuration=/dapps/chaincode_jclient/config/testutils.properties \
-Dcrypto_path=/dapps/chaincode_jclient/crypto-config \
-cp $CLASSPATH  \
$MAIN_CLZ
