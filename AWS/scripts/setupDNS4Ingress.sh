#!/bin/bash
. ~/installsettings.sh

controller="connections-nginx-ingress-controller connections-nginx-ingress-controller-intern global-nginx-nginx-ingress-controller global-nginx-nginx-ingress-controller-extern"

for c in $controller; do
  echo "Check for Controller: $c"
 
  erg=$(kubectl get services --namespace connections $c)
  if [ $? -eq 0 ]; then
    lbhost=$(kubectl get services --namespace connections $c --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ $? -eq 0 -a -n "$lbhost" ]; then
      echo "LB Hostname: $lbhost"
      internal=$(echo $lbhost | grep internal)
      if [ $? -eq 0 ]; then
        HostedZone=$HostedZoneId
      else
        HostedZone=$HostedZoneIdPublic
      fi
      echo "assign $lbhost to Zone ${HostedZone} to record $ic_front_door"
cat > /tmp/basic_dns.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$ic_front_door",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$lbhost"
          }
        ]
      }
    }
  ]
}
EOF
      echo
      aws route53 change-resource-record-sets --hosted-zone-id ${HostedZone} --region $AWSRegion --change-batch file:///tmp/basic_dns.json
      if [ $? -eq 0 ]; then
        echo "SUCCESS"
      else
        echo "FAILED !!!!!!!!"
      fi
      echo
      echo
    else
      echo "Controller $c not LB Hostname found."
    fi
  else
    echo "Contorller $c does not exist."
  fi
done

