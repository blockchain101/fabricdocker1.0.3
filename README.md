# dockerfiles
docker file create blockchain101/fabric-ca:1.0.3 based on hyperledger/fabric-ca:x86_64-1.0.3 which is built using source code
docker file create blockchain101/fabric-peer:1.0.3 based on hyperledger/fabric-peer:x86_64-1.0.3 which is built from source code
docker file create blockchain101/fabric-orderer:1.0.3 based on hyperledger/fabric-orderer:x86_64-1.0.3 which is built from source code
docker file create blockchain101/fabric-couchdb:1.0.3 based on hyperledger/fabric-couchdb:x86_64-1.0.3 which is built from source code
docker file create blockchain101/fabric-kafka:1.0.3 based on hyperledger/fabric-kafka:x86_64-1.0.3 which is built from source code
docker file create blockchain101/fabric-zookeeper:1.0.3 based on hyperledger/fabric-zookeeper:x86_64-1.0.3 which is built from source code
docker file create hyperledger/fabric-ccenv:latest based on hyperledger/fabric-ccenv:x86_64-1.0.3 which is built from source code
docker file create blockchain101/fabric-cli:1.0.3 based on  hyperledger/fabric-baseimage:x86_64-0.3.2 which is built from source code
docker files create blockchain101/fabric-hfc:1.0.3 based on blockchain101/ubuntu16.04-dev:node6.9-python2.7-makegcc-git which is built from scrach using ubuntu:16.04 image in docker hub
docker files create blockchain101/fabric-hfcj:1.0.3 based on blockchain101/ubuntu16.04-dev:jdk8-maven3-gradle2-git which is built from scrach using ubuntu:16.04 image in docker hub

# fabric-testnet-docker
docker compose file to run docker containers using above blockchain101/fabric-ca:1.0.3, blockchain101/fabric-orderer:1.0.3, blockchain101/fabric-peer:1.0.3, blockchain101/fabric-couchdb:1.0.3, hyperledger/fabric-ccenv:x86_64-1.0.3, blockchain101/fabric-zookeeper:1.0.3, blockchain101/fabric-kafka:1.0.3, blockchain101/fabric-cli:1.0.3, blockchain101/fabric-hfc:1.0.3, blockchain101/fabric-hfcj:1.0.3 images.

22 fabric nodes containers: ca0.org1.bctrustmachine.cn, ca0.org2.bctrustmachine.cn, zookeeper0~2.bctrustmachine.cn, kafka0~2.bctrustmachine.cn, orderer.bctrustmachine.cn, peer0~1.org1.bctrustmachine.cn, peer0~1.org2.bctrustmachine.cn, couchdb0~1.org1.bctrustmachine.cn, couchdb0~1.org2.bctrustmachine.cn, cli, hfc0.org1.bctrustmachine.cn, hfc0.org2.bctrustmachine.cn, hfcj0.org1.bctrustmachine.cn, hfcj0.org2.bctrustmachine.cn.

An auto-config script will be invoked to create channel wich channel name "ch1" and one TwoOrgs with msp id "OrdererMSP", "Org1Msp", "Org2Msp", 
orderer.bctrustmachine.cn using msp "OrdererMSP"; peer0~1.org1.bctrustmachine.cn belong to org1 domain using msp "Org1Msp", peer0~1.org2.bctrustmachine.cn belong to org2 domain using msp "Org2Msp".

cli will be used to create channel, join channel, install example02/marble02/posslip chaincodes and invoke/query chaincodes from command line interface.
hfc0.org1.bctrustmachine.cn, a node.js app which authorized by ca0.org1.bctrustmachine.cn to access peer0~1.org1.bctrustmachine.cn, is installed with marbles app and running with 3001 port.
hfc0.org2.bctrustmachine.cn, a node.js app which authorized by ca0.org2.bctrustmachine.cn to access peer0~1.org2.bctrustmachine.cn, is installed with marbles app and running with 3002 port.
hfcj0.org1.bctrustmachine.cn, a java app which authorized by ca0.org1.bctrustmachine.cn to access peer0~1.org1.bctrustmachine.cn, is installed with posslip app and running in java main application when startup.
hfcj0.org2.bctrustmachine.cn, a java app which authorized by ca0.org2.bctrustmachine.cn to access peer0~1.org2.bctrustmachine.cn, is installed with marbles app and running in java main application when startup.
you could also using local marbles app to access docker contained apps.

port detect scripts are packed in images and scripts to make sure all necessary resources created and installed/instantiated before executing chaincode invocation.

