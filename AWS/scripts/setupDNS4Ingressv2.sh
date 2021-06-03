#!/bin/bash
. ~/installsettings.sh

# when using nlb load balancer, the internet facing or internal only is not encoded in the name anymore.

controller="global-nginx-ingress-nginx-controller cnx-ingress-ingress-nginx-controller"

for c in $controller; do
  echo
  echo "Check for Controller: $c"
 
  erg=$(kubectl get services --namespace $namespace $c)
  if [ $? -eq 0 ]; then
    lbhost=$(kubectl get services --namespace $namespace $c --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ $? -eq 0 -a -n "$lbhost" ]; then
      echo "LB Hostname: $lbhost"
      scheme=$(aws elbv2 describe-load-balancers --region $AWSRegion --query "LoadBalancers[?DNSName=='$lbhost'].[Scheme]" --output text)
      echo "LB Scheme: $scheme"
      if [ "$scheme" == "internal" ]; then
        ZONES=$HostedZoneId
      else
        ZONES="$HostedZoneIdPublic $HostedZoneId"
      fi
      if [ "${c::3}" == "cnx" ]; then
        # it is an internal LB. User master_ip
        dnsname=$master_ip
      else
        dnsname=$ic_front_door
      fi 
      echo "Using DNS: $dnsname"
      for HostedZone in $ZONES; do
        echo "assign $lbhost to Zone ${HostedZone} to record $dnsname"
cat > /tmp/basic_dns.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$dnsname",
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
      done
    else
      echo "Controller $c not LB Hostname found."
    fi
  else
    echo "Contorller $c does not exist."
  fi
done

