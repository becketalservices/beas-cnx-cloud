Modifications for Customizer
============================

The integration of the customizer component can be done in 3 ways:

1. [Install a separate proxy server in front of Kubernetes.](chapter1.html)  
This setup is described in the HCL Connections installation guide.
2. [Install a ingress controller as part of your kubernetes infrastructure.](chapter2.html)  
This setup is my peferred solution as no separate server is necessary.
3. [Install a 2nd HTTP server on your existing HTTP Server.](chapter3.html)  
This setup has the smallest hardware foodprint but requires some more configurations.   
I recommend this setup only for proove of concept installations which should cost as less as possible.


