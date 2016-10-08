RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]

WSGIProcessGroup <%= $conf->{"project"} %>
WSGIDaemonProcess <%= $conf->{"project"} %> python-path=/opt/webapps/<%= $conf->{"project"} %>/project:/opt/webapps/<%= $conf->{"project"} %>/env/lib/python2.7/site-packages
WSGIScriptAlias / /opt/webapps/<%= $conf->{"project"} %>/project/<%= $conf->{"project"} %>/wsgi.py
WSGIPythonPath /opt/webapps/<%= $conf->{"project"} %>/env

Alias /media/ /opt/webapps/<%= $conf->{"project"} %>/media/
Alias /static/ /opt/webapps/<%= $conf->{"project"} %>/static/
Alias /robots.txt /opt/webapps/<%= $conf->{"project"} %>/static/robots.txt

# This needs to get moved to HTTPS when we get a cert. We should probably also only
# respond to the domain name (not the IP), but that can get sorted out when DNS is
# setup
<VirtualHost *:443>
    ServerName <%= $conf->{"domain"} %>
    KeepAlive Off

    # This needs tweaking before we finish moving to production
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/<%= $conf->{"domain"} %>.crt
    SSLCertificateKeyFile /etc/ssl/private/<%= $conf->{"domain"} %>.key
    SSLCipherSuite HIGH:!aNULL:!MD5

    # Put the logs in a more useful/accessible location
    CustomLog /opt/webapps/<%= $conf->{"project"} %>/logs/<%= $conf->{"domain"} %>.access.log combined
    ErrorLog /opt/webapps/<%= $conf->{"project"} %>/logs/<%= $conf->{"domain"} %>.error.log 
		
    # Settings for running the actual application
    <Directory /opt/webapps/<%= $conf->{"project"} %>/project>
	<Files wsgi.py>
	Require all granted
	</Files> 
    </Directory>

    # Set the permissions for media and static directories (aliased above)
    <Directory /opt/webapps/<%= $conf->{"project"} %>/static>
	Require all granted
    </Directory>	
    <Directory /opt/webapps/<%= $conf->{"project"} %>/media>
	Require all granted
    </Directory>	
</VirtualHost>


