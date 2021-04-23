. ./installsettings.sh

ARN=$1

if [ -z "$ARN" ]; then
  echo "Usage: $0 <policy ARN>"
  exit 1 
fi


eksctl create iamserviceaccount \
  --cluster=$EKSName \
  --region=$AWSRegion \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=$ARN \
  --override-existing-serviceaccounts \
  --approve

