#!/bin/bash
. ~/installsettings.sh

if [ "$EKSTags" ]; then
  TAGS=" --tags $EKSTags"
fi

if [ "$EKSVersion" ]; then
  VERSION="--version $EKSVersion"
fi

if [ "$EKSAutoscale" == "1" ]; then
  ASG="  --asg-access"
  NODES="   --nodes-min $EKSNodeCount --nodes-max $EKSNodeCountMax"
else
  NODES=" --nodes $EKSNodeCount"
fi

if [ "$EKSPrivateNetworking" == "1" ]; then
  SNTYPE="  --vpc-private-subnets $SUBNETID --node-private-networking"
else
  SNTYPE="  --vpc-public-subnets $SUBNETID"
fi

cat << EOF > run_eksctl.sh
eksctl create cluster --name "$EKSName" \
  $VERSION \
  --nodegroup-name standard-workers \
  --node-type $EKSNodeType \
  $NODES \
  --node-ami auto \
  --node-volume-size $EKSNodeVolumeSize \
  --ssh-public-key $EKSNodePublicKey \
  --region $AWSRegion \
  $SNTYPE \
  $TAGS \
  $ASG
EOF
