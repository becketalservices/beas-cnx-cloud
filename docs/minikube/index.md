Create an HCL Component Pack installation on minikube
=====================================================

The installation on minikube is just for prove of concept installations or for very little environments where no high availability is needed. 

This instructions are like a cook book. You can follow them and you will get the desired result when you environment is the same as mine. This instructions were build using a EC2 instance in a payed account on AWS without any restrictions. When you are in a corporate environment the instructions should work on a virtual or physical server as well.

The infrastructure requires as little as possible resources. A Free Tier or Trial Account in AWS is not sufficient to install the whole Component Pack components. Please use a large enough server.

1. [Create your minikube environment](chapter1.html)
2. [Create your Kubernetes environment](chapter2.html)
3. [Prepare cluster](chapter3.html)
4. [Install Component Pack](chapter4.html)
5. [Integration](../integration/index.html)
6. [Customizer](../customizer/index.html)
7. [Deploy additional features](../addons/index.html)

In case you want to migrate you ElasticSearch data from EFS to EBS, you can use the process [Migrate ES Data from EFS to EBS](../AWS/migrate_es_data.html).

To stop or start single services for a longer time you can use this commands to modify the number of replicas: [Start / Stop infrastructure](../kubernetes/Start_Stop.html)