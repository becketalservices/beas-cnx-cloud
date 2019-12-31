Create an HCL Component Pack installation on managed Kubernetes
==============================================================

HCL has updated the HCL Connections Component Pack to work on a native Kubernetes installation without IBM Cloud private. This gives everyone the chance to deploy the solution on a managed Kubernetes infrastructure.

HCL has documented the installation of HCL Connections Component Pack on a reference installation which will probably reside in a private data center.

As many companies are now using cloud services, using Kubernetes services out of the cloud should also be an option to host the HCL Connections Component Pack.

This documentation provides information and installation guidelines to get HCL Connections Component Pack running on a managed Kubernetes service on one of the main cloud providers.

__Amazon Web Services AWS__  

Instructions based on HCL Connections Component Pack Version 6.5  
[Installation instructions for Amazon Web Services](AWS/index.md)  
The installation uses as less as possible load balancer and does not use the classic HTTP Servers as proxy for the new Kubernetes services.
  
__Microsoft Azure__

Instructions are base on IBM Connections Component Pack Version 6.0.0.6  
[Installation instructions for Microsoft Azure](Azure/index.md)


After following the __Amazon Web Services guide__ an infrastructure similar to this picture is running:

![Connections Infrastructure AWS](images/HCL_Connections_Infratructure_AWS.png "Connections Infrastructure AWS")


After following the __Microsoft Azure guide__ an infrastructure similar to this picture is running:

![Connections Infrastructure Azure](images/ConnectionsInfrastructureAzure.png "Connections Infrastructure Azure")


