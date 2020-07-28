Integrate Customizer using a 2nd IHS Server
===========================================

This scenario is for small deployments where you want to save resources, especially when you have only 1 HTTP Server and no Load Balancer.

The exiting IBM HTTP Server is moved to different ports but is still used as the internal entry point for the WebSphere Connections environment.  
The new IBM HTTP Server is listening on port 80 an 443 and is used as reverse proxy or the customizer.

# 1. Move server to different ports

1. Modify the httpd.conf of your HTTP Server to use port 81 and 444 as ports
2. Modify the LC-config.xml and change the services configurations by specifiying the new ports in the href and ssl_href entries.
3. Modify in the WAS console the http server configuration to use port 81.
4. Modify in the WAS console the environment - virtual hosts - default_host and add port 81 and 444.
5. Generate and propagate the HTTP Server Plug-in configuration, Restart HTTP Server.
3. Full Synchronize and restart the instance
4. Test. Your HCL Connections WebSphere environment should now react as normal but on different ports.

# 2. Create 2nd HTTP Server as ingress HTTP Server

1. Install a 2nd IBH HTTP Server
2. Make sure it has a valid SSL Certificate and listen on port 80 and 443
3. Add the proxy rules to forward all traffic to the internal HTTP server
4. Change your LC-config.xml to used the standard ports in the dynamicHosts configuration.
5. Full Synchronize and restart the instance
6. Test. Your HCL Connections WebSphere environment should no react as normal on the standard ports.

# 3. add proxy rules for customizer

1. Update your httpd.conf file of your ingress HTTP server to redirect traffic via customizer.
    Replace ${master_ip} with your hostname or ip of your master or k8s load balancer.

    ```
    SSLProxyEngine on
    ProxyPreserveHost On
    ProxyPass "/files/customizer" "http://${master_ip}:30301/files/customizer"
    ProxyPassReverse "/files/customizer" "http://${master_ip}:30301/files/customizer"
    ProxyPass "/files/app" "http://${master_ip}:30301/files/app"
    ProxyPassReverse "/files/app" "http://${master_ip}:30301/files/app"
    ProxyPass "/moderation/app" "http://${master_ip}:30301/moderation/app"
    ProxyPassReverse "/moderation/app" "http://${master_ip}:30301/moderation/app"
    ProxyPass "/metrics/orgapp" "http://${master_ip}:30301/metrics/orgapp"
    ProxyPassReverse "/metrics/orgapp" "http://${master_ip}:30301/metrics/orgapp"
    ProxyPass "/communities/service/html" "http://${master_ip}:30301/communities/service/html"
    ProxyPassReverse "/communities/service/html" "http://${master_ip}:30301/communities/service/html"
    ProxyPass "/forums/html" "http://${master_ip}:30301/forums/html"
    ProxyPassReverse "/forums/html" "http://${master_ip}:30301/forums/html"
    ProxyPass "/dogear/html" "http://${master_ip}:30301/dogear/html"
    ProxyPassReverse "/dogear/html" "http://${master_ip}:30301/dogear/html"
    ProxyPass "/search/web" "http://${master_ip}:30301/search/web"
    ProxyPassReverse "/search/web" "http://${master_ip}:30301/search/web"
    ProxyPass "/homepage/web" "http://${master_ip}:30301/homepage/web"
    ProxyPassReverse "/homepage/web" "http://${master_ip}:30301/homepage/web"
    ProxyPass "/social/home" "http://${master_ip}:30301/social/home"
    ProxyPassReverse "/social/home" "http://${master_ip}:30301/social/home"
    ProxyPass "/mycontacts" "http://${master_ip}:30301/mycontacts"
    ProxyPassReverse "/mycontacts" "http://${master_ip}:30301/mycontacts"
    ProxyPass "/wikis/home" "http://${master_ip}:30301/wikis/home"
    ProxyPassReverse "/wikis/home" "http://${master_ip}:30301/wikis/home"
    ProxyPass "/blogs" "http://${master_ip}:30301/blogs"
    ProxyPassReverse "/blogs" "http://${master_ip}:30301/blogs"
    ProxyPass "/news" "http://${master_ip}:30301/news"
    ProxyPassReverse "/news" "http://${master_ip}:30301/news"
    ProxyPass "/activities/service/html" "http://${master_ip}:30301/activities/service/html"
    ProxyPassReverse "/activities/service/html" "http://${master_ip}:30301/activities/service/html"
    ProxyPass "/profiles/html" "http://${master_ip}:30301/profiles/html"
    ProxyPassReverse "/profiles/html" "http://${master_ip}:30301/profiles/html"
    ProxyPass "/viewer" "http://${master_ip}:30301/viewer"
    ProxyPassReverse "/viewer" "http://${master_ip}:30301/viewer"
    ProxyPass "/" "https://${ic_internal}:445/"
    ProxyPassReverse "/" "https://${ic_internal}:445/"
    ```    
