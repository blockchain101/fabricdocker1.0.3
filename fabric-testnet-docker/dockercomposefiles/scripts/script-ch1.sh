#!/bin/bash

CHANNEL_NAME="$1"
ORGS_PROFILE="$2"
PRODUCTION_PATH="$3"
: ${CHANNEL_NAME:="mychannel"}
: ${ORGS_PROFILE:="TwoOrgs"}
: ${PRODUCTION_PATH:="/var/hyperledger/production"}
: ${TIMEOUT:="60"}
COUNTER=0
MAX_RETRY=5
CORE_ORDERER_ADDRESS=orderer.bctrustmachine.cn:7050
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bctrustmachine.cn/orderers/orderer.bctrustmachine.cn/msp/tlscacerts/tlsca.bctrustmachine.cn-cert.pem

echo "Channel name : "$CHANNEL_NAME

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
   		exit 1
	fi
}

setGlobals () {
        
	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		peerorg_name="org1.bctrustmachine.cn"
		peer_seq=` expr $1 `
		CORE_PEER_ADDRESS=peer${peer_seq}.${peerorg_name}:7051
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$peerorg_name/users/Admin@${peerorg_name}/msp"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$peerorg_name/peers/peer${peer_seq}.${peerorg_name}/tls/ca.crt
	else
		peerorg_name="org2.bctrustmachine.cn"
		peer_seq=` expr $1 - 2 `
	  CORE_PEER_ADDRESS=peer${peer_seq}.${peerorg_name}:7051
		CORE_PEER_LOCALMSPID="Org2MSP"
    CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$peerorg_name/users/Admin@${peerorg_name}/msp
	  CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$peerorg_name/peers/peer${peer_seq}.${peerorg_name}/tls/ca.crt
	fi
	env |grep CORE
}

setOrdererGlobals () {
    ordorg_name="bctrustmachine.cn"
		CORE_PEER_ADDRESS=orderer.bctrustmachine.cn:7050
		CORE_PEER_LOCALMSPID="OrdererMSP"
		CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bctrustmachine.cn/users/Admin@bctrustmachine.cn/msp"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/bctrustmachine.cn/orderers/orderer.bctrustmachine.cn/tls/ca.crt

	env |grep CORE
}

createChannel() {
	setGlobals 0

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o $CORE_ORDERER_ADDRESS -c $CHANNEL_NAME -t 30 -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel/channel-$ORGS_PROFILE-$CHANNEL_NAME.tx >&log.txt
	else
		peer channel create -o $CORE_ORDERER_ADDRESS -c $CHANNEL_NAME -t 30 -f /opt/gopath/src/github.com/hyperledger/fabric/peer/channel/channel-$ORGS_PROFILE-$CHANNEL_NAME.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
        echo "cp $CHANNEL_NAME.block $PRODUCTION_PATH"
        cp $CHANNEL_NAME.block $PRODUCTION_PATH 
        echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 3
		joinWithRetry $1
	else
		COUNTER=0
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in $*; do
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep 3
		echo
	done
}

updateAnchorPeers() {
	for anchorPeer in $*; do
		updateAnchorPeer $anchorPeer
		sleep 3
		echo
	done
}

updateAnchorPeer() {
  PEER=$1
  setGlobals $PEER

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o $CORE_ORDERER_ADDRESS -c $CHANNEL_NAME -t 30 -f ./channel/channel-$ORGS_PROFILE-$CHANNEL_NAME-anchor${CORE_PEER_LOCALMSPID}.tx >&log.txt
  else
		peer channel create -o $CORE_ORDERER_ADDRESS -c $CHANNEL_NAME -t 30 -f ./channel/channel-$ORGS_PROFILE-$CHANNEL_NAME-anchor${CORE_PEER_LOCALMSPID}.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	echo
}

retrieveConfigBlock(){
  config_block_path=$1
  PEER=0
  SYSCHAINCODEID="testchainid"
  setOrdererGlobals
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		echo "peer channel fetch config $config_block_path -o $CORE_ORDERER_ADDRESS -c $SYSCHAINCODEID >&log.txt"
		peer channel fetch config $config_block_path -o $CORE_ORDERER_ADDRESS -c $SYSCHAINCODEID >&log.txt 
	else
		echo "peer channel fetch config -o $CORE_ORDERER_ADDRESS --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -c $SYSCHAINCODEID >&log.txt"
		peer channel fetch config  -o $CORE_ORDERER_ADDRESS --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA  >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "retrieve genesis config block failed"
	echo "===================== Config block using org \"$CORE_PEER_LOCALMSPID\" on \"$SYSCHAINCODEID\" is retrieved successfully ===================== "
	echo	

}

updateConfigBlock(){
  config_update_block_as_envelope=$1
  
  PEER=0
  SYSCHAINCODEID="testchainid"
  setOrdererGlobals
  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		echo "peer channel update -f $config_update_block_as_envelope -o $CORE_ORDERER_ADDRESS -c $SYSCHAINCODEID >&log.txt"
		peer channel update -f $config_update_block_as_envelope -o $CORE_ORDERER_ADDRESS -c $SYSCHAINCODEID >&log.txt
	else
		echo "peer channel update -f $config config_update_block_as_envelope -o $CORE_ORDERER_ADDRESS --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -c $SYSCHAINCODEID >&log.txt"
		peer channel update -f $config_update_block_as_envelope -o $CORE_ORDERER_ADDRESS --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -c $SYSCHAINCODEID >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "retrieve genesis config block failed"
	echo "===================== Config block update using org \"$CORE_PEER_LOCALMSPID\" on \"$SYSCHAINCODEID\" is updated successfully ===================== "
	echo	


}
installChaincode () {
	PEER=$1
        CHAINCODE=$2
        CHAINCODE_ID=$3
        CHAINCODE_VER=$4
        setGlobals $PEER
	echo "peer chaincode install -n $CHAINCODE_ID -v $CHAINCODE_VER -p github.com/hyperledger/fabric/examples/chaincode/go/$CHAINCODE >&log.txt"
	peer chaincode install -n $CHAINCODE_ID -v $CHAINCODE_VER -p github.com/hyperledger/fabric/examples/chaincode/go/$CHAINCODE >&log.txt 
        res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
        CCINIT_ARGS=$2
        CHAINCODE_ID=$3
        CHAINCODE_VER=$4
	setGlobals $PEER
        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		echo "peer chaincode instantiate -o $CORE_ORDERER_ADDRESS -C $CHANNEL_NAME -n $CHAINCODE_ID -v $CHAINCODE_VER -c $CCINIT_ARGS -P \"OR('Org1MSP.member','Org2MSP.member')\" >&log.txt "
		peer chaincode instantiate -o $CORE_ORDERER_ADDRESS -C $CHANNEL_NAME -n $CHAINCODE_ID -v $CHAINCODE_VER -c $CCINIT_ARGS -P "OR('Org1MSP.member','Org2MSP.member')" >&log.txt
	else
		echo "peer chaincode instantiate -o $CORE_ORDERER_ADDRESS --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_ID -v $CHAINCODE_VER -c $CCINIT_ARGS -P \"OR('Org1MSP.member','Org2MSP.member')\" >&log.txt"
		peer chaincode instantiate -o $CORE_ORDERER_ADDRESS --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_ID -v $CHAINCODE_VER -c $CCINIT_ARGS -P "OR('Org1MSP.member','Org2MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
  CCQUERY_ARGS=$2 
  CHAINCODE_ID=$3
  EXPECTED_RSLT=$4
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     echo "peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_ID -c $CCQUERY_ARGS >&log.txt "
     peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_ID -c $CCQUERY_ARGS >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$EXPECTED_RSLT" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
  fi
}

chaincodeQueryPrintResult () {
  PEER=$1
  CCQUERY_ARGS=$2 
  CHAINCODE_ID=$3
  
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     echo "peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_ID -c $CCQUERY_ARGS >&log.txt "
     peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_ID -c $CCQUERY_ARGS >&log.txt
     test $? -eq 0 && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
  fi
}

chaincodeInvoke () {
        PEER=$1
        CCINVOKE_ARGS=$2
        CHAINCODE_ID=$3
        echo "===================== invoking chaincode $3 on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
        setGlobals $PEER
        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		echo "peer chaincode invoke -o $CORE_ORDERER_ADDRESS -C $CHANNEL_NAME -n $CHAINCODE_ID -c $CCINVOKE_ARGS >&log.txt"
		peer chaincode invoke -o $CORE_ORDERER_ADDRESS -C $CHANNEL_NAME -n $CHAINCODE_ID -c "$CCINVOKE_ARGS" >&log.txt
	else
		echo "peer chaincode invoke -o $CORE_ORDERER_ADDRESS  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_ID -c $CCINVOKE_ARGS >&log.txt"
		peer chaincode invoke -o $CORE_ORDERER_ADDRESS  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_ID -c "$CCINVOKE_ARGS" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

# Probe orderer service with sleep
./scripts/probeOrdererWithSleep.sh $CORE_ORDERER_ADDRESS

if [ $? -ne 0 ]; then
  echo "orderer service not started correctly, exist blockchain initialization." 
  exit 1
fi
echo ""
echo ""
echo ""
echo "################################################################################"
echo "#######################STARTING INITIALIZATION BLOCKCHAIN!######################"
echo "################################################################################"

# Create channel
createChannel

## Join all the peers to the channel
joinChannel 0 1 2 3 

## Update anchor peers for 
updateAnchorPeers 0 2 

## Install chaincode on Peer0/Org0 and Peer2/Org1
#installChaincode 0 chaincode_example02 mycc 1.0
#installChaincode 2 chaincode_example02 mycc 1.0
#
##Instantiate chaincode on Peer2/Org1
#echo "Instantiating chaincode ..."
#instantiateChaincode 2 '{"Args":["init","a","100","b","200"]}' mycc 1.0
#
##Query on chaincode on Peer0/Org0
#chaincodeQuery 0 '{"Args":["query","a"]}' mycc 100
#
##Invoke on chaincode on Peer0/Org0
#echo "send Invoke transaction ..."
#chaincodeInvoke 0 '{"Args":["invoke","a","b","10"]}' mycc
#
### Install chaincode on Peer3/Org1
#installChaincode 3 chaincode_example02 mycc 1.0
#
##Query on chaincode on Peer3/Org1, check if the result is 90
#chaincodeQuery 3 '{"Args":["query","a"]}' mycc 90
#
#echo
#echo "===================== All GOOD, End-2-End chaincode_example02 test completed ===================== "
#echo
#echo "waiting 5s to start marbles02 deploying and invoke..."
#sleep 5 
#echo "===================== Start deploying marbles02 ===================== "
#echo "Installing chaincode ..."
#installChaincode 0 marbles02 marbles02 1.0
#installChaincode 2 marbles02 marbles02 1.0
#
#echo "Instantiating chaincode ..."
#instantiateChaincode 2 '{"Args":["init","100"]}' marbles02 1.0
#
#echo "Querying chaincode ..."
#chaincodeQuery 0 '{"Args":["read","selftest"]}' marbles02 100
#
#echo "Invoking chaincode init_owner o0..."
#chaincodeInvoke 0 '{"Args":["init_owner","o0","dummy0","United Marbles"]}' marbles02
#
#echo "Invoking chaincode init_owner o1 ..."
#chaincodeInvoke 2 '{"Args":["init_owner","o1","dummy1","eMarbles"]}' marbles02
#
#echo "sleeping 3s"
#sleep 3
#
#echo "Invoking chaincode init_marble m01~05..."
#chaincodeInvoke 0 '{"Args":["init_marble","m01","red","1","o0","United Marbles"]}' marbles02
#chaincodeInvoke 0 '{"Args":["init_marble","m02","red","1","o0","United Marbles"]}' marbles02
#chaincodeInvoke 0 '{"Args":["init_marble","m03","red","1","o0","United Marbles"]}' marbles02
#chaincodeInvoke 0 '{"Args":["init_marble","m04","red","1","o0","United Marbles"]}' marbles02
#chaincodeInvoke 0 '{"Args":["init_marble","m05","red","1","o0","United Marbles"]}' marbles02
#
#echo "sleeping 3s"
#sleep 3
#
#echo "Invoking chaincode init_marble m11~m15..."
#chaincodeInvoke 2 '{"Args":["init_marble","m11","blue","30","o1","eMarbles"]}' marbles02
#chaincodeInvoke 2 '{"Args":["init_marble","m12","blue","30","o1","eMarbles"]}' marbles02
#chaincodeInvoke 2 '{"Args":["init_marble","m13","blue","30","o1","eMarbles"]}' marbles02
#chaincodeInvoke 2 '{"Args":["init_marble","m14","blue","30","o1","eMarbles"]}' marbles02
#chaincodeInvoke 2 '{"Args":["init_marble","m15","blue","30","o1","eMarbles"]}' marbles02
#
#echo "sleeping 3s"
#sleep 3
#echo "Invoking chaincode set_owner m01->o1..."
#chaincodeInvoke 2 '{"Args":["set_owner","m01","o1","United Marbles"]}' marbles02
#
#echo "sleeping 3s"
#sleep 3 
#echo "Invoking chaincode init_marble m11->o0..."
#chaincodeInvoke 2 '{"Args":["set_owner","m11","o0","eMarbles"]}' marbles02
#
#echo "============================= Deployed marbles02 and invoked OK ============================= "  
#
#echo "waiting 3s to start pos_slip deploying and invoke..."
#sleep 3 
#echo "===================== Start deploying pos_slip ===================== "

echo "Installing chaincode ..."
installChaincode 0 pos_slip pos_slip 1.0
installChaincode 2 pos_slip pos_slip 1.0

echo "Instantiating chaincode ..."
instantiateChaincode 2 '{"Args":["init","200"]}' pos_slip 1.0

echo "Querying chaincode ..."
chaincodeQuery 0 '{"Args":["read","selftest"]}' pos_slip 200

echo "Invoking chaincode ..."
chaincodeInvoke 2 '{"Args":["initPosSlip","t20","ChinaUnionPayMerchantServices","1234567890","120.00"]}' pos_slip 1.0
chaincodeInvoke 2 '{"Args":["initPosSlip","t21","ChinaUnionPayMerchantServices","1234567891","220.00"]}' pos_slip 1.0
chaincodeInvoke 2 '{"Args":["initPosSlip","t22","ChinaUnionPayMerchantServices","9999999999","320.00"]}' pos_slip 1.0
chaincodeInvoke 2 '{"Args":["initPosSlip","t23","ChinaMobile","9999999999","1000.00"]}' pos_slip 1.0

chaincodeQueryPrintResult 0 '{"Args":["readPosSlip","t22"]}' pos_slip   

chaincodeQueryPrintResult 0 '{"Args":["queryPosSlipsByMerId","ChinaUnionPayMerchantServices"]}' pos_slip     

chaincodeQueryPrintResult 0 '{"Args":["queryPosSlipsByCardNo","9999999999"]}' pos_slip

#updateConfigBlock channel/config_update_as_envelope.pb
#retrieveConfigBlock channel/updated_config.block



exit 0
