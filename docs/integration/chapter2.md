Integrate Redis Traffic
=======================

Follow the instructions to [Manually configuring Redis traffic to Orient Me](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_redis_enable.html). 

In case you use EKS, your kubernetes cluster does not provide a SSH endpoint that can be used to secure the redis traffic. In this case you can either power up a special service to provide this endpoint or you don't encapsulate your Redis traffic in SSH. 
 

```
# Load settings
. ~/installsettings.sh

# Get Redis Password from secret redis-secret
redispwd=$(kubectl get secret redis-secret -n connections \
  -o "jsonpath={.data.secret}" | base64 -d)

# run command
bash microservices_connections/hybridcloud/support/redis/configureRedis.sh \
  -m  $master_ip\
  -po 30379 \
  -ic https://$ic_internal \
  -pw "$redispwd" \
  -ic_u "$ic_admin_user" -ic_p "$ic_admin_password"

```

Check the command output. When the command completed successfully, restart common and news application.

To check if redis is working as expected use [Verifying Redis server traffic](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_redis_verify.html).

To view your Redis password run:

```
kubectl get secret redis-secret -n connections   -o "jsonpath={.data.secret}" | base64 -d

```

To run redsi-cli run:

```
kubectl exec -it -n connections redis-server-0 -- redis-cli

```

Commands to verify traffic:

```
auth <redis-password>
subscribe connections.events

```
