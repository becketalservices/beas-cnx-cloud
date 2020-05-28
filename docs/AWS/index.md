Create an HCL Component Pack installation on AWS
================================================

This instructions are like a cook book. You can follow them and you will get the desired result when you environment is the same as mine. This instructions were build using a payed account without any restrictions. When you are in a corporate environment there might some restrictions apply. Please check with your entitlement administrator.

The infrastructure requires quite a lot of resources. A Free Tier or Trial Account is not sufficient to install the whole Component Pack
components. Please use a payed account.

1. [Create your AWS environment](chapter1.html)
2. [Create Kubernetes infrastructure on AWS](chapter2.html)
3. [Prepare cluster and install your first application](chapter3.html)
4. [Configure your Network](chapter4.html)
5. [Install Component Pack](chapter5.html)
6. [Configure Ingress](chapter6.html)
7. - outdated - [Update Component Pack](chapter7.html)

In case you want to migrate you ElasticSearch data from EFS to EBS, you can use the process [Migrate ES Data from EFS to EBS](migrate_es_data.html).

To stop or start single services for a longer time you can use this commands to modify the number of replicas: [Start / Stop infrastructure](../kubernetes/Start_Stop.html)
