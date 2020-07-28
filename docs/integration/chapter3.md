Integrate Orient Me
===================

Follow the instructions [Configuring the Orient Me component](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_intro.html).

# 1. Configuring the HTTP server for Orient Me

Update your HTTP Server configuration: <https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_http_server.html>

# 2. Enabling profiles events for Orient Me

Update your TDI and LC-config: <https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_enable_profiles_events.html>

# 3. Configuring the Orient Me home page

Update your search and LC-config: <https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_enable_notifications.html>

# 4. Populating the Orient Me home page

The full procedure and more configuration options can be found in [Populating the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_populate_home_page.html) 


**Show your migration configuraton**

To view your migration configuration run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') -- cat /usr/src/app/migrationConfig

```

In case something is wrong, check out the [HCL documentation](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_prepare_migrate_profiles.html) on how to modify the configuration.


**Run migration command**

In case of a larger infrastructure check out the documentation [Migrating the data for the Orient Me home page](https://help.hcltechsw.com/connections/v65/admin/install/cp_config_om_migrate_profiles.html).

For smaller instances where you can do a full migration with just one command run:

```
kubectl exec -n connections -it $(kubectl get pods -n connections | grep people-migrate | awk '{print $1}') -- npm run start migrate

```
