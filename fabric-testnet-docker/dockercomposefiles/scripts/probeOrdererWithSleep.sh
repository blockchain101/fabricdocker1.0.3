#!/bin/bash

probeServicePort(){
  hostname=$1
  port=$2
  
  echo "" | nc $hostname $port
  
  if [ $? -eq 0 ];then
    return 0
  else
    return 1
  fi
  
}

#return code 0: pass
#return code 1: not pass
#return code 2: not suitable
probeOrderer(){
  echo "probe $1"
  isExistingValidUrlVar=`expr index $1 ':'`
  if [[ $isExistingValidUrlVar -eq 0 ]]; then
     return 2
  fi
  
  urls=${1}
  urls=${urls//,/ }

  for url in $urls; do
    hostname=`echo $url |cut -d ':' -f 1`
    port=`echo $url |cut -d ':' -f 2`
    probeServicePort $hostname $port
    if [ $? -ne 0 ];then
      return 1
    fi
  done
  
  return 0
  
}

echo "orderers: $1"
allalive=false
while [ -n $allalive ]; do
  probeOrderer $1
  if [ $? -eq 0 ];then
	  allalive=true;
		break;
	fi
  
  echo "`date` not all orderers alive, sleep 3s and trying probe again ..."
	sleep 3
done

echo "`date` all orderers $1 are live! sleep 10 and waiting initialization blockchain!"
echo "################################################################################"
echo "############################FINISHED ORDERER PROBING!###########################"
echo "################################################################################"
sleep 10

exit 0