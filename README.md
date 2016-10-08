Flingtoad Flts
==============

This Rex script is used to deploy a client's Django project on a clean server.

Install the required Rex plugins. Run the following in the same directory as the Rexfile:
```
[user@localhost]$ rexify --use Rex::Database::MySQL
```

To install the rest of the package dependencies:
```
[user@localhost]$ cpan Carton
[user@localhost]$ carton install
```
Note: You can also install Rex and Carton with CPANMINUS ('cpanm') or CPANPLUS ('cpanp'), whichever you prefer.

Tasks
 * A000_update_pkgs	Pull in new packages
 * A001_bootstrap 	Bootstrap the system with users and a few default configs
 * A002_prepare_web_pkgs	Install the base webserver/database packages
 * A003_deploy_django	Build the django project directory structure and virtual environment

The tasks are intended to be run in order A000-A004.

Before beginning, create an initial variables file. For example,
```
# cmdb/deploy-vars.yml
deploy_ip: 192.168.10.10 # IP to deploy to
deploy_port: 22 # Port running SSH
deploy_user: mikeo # User to begin bootstrapping project
deploy_key: '/home/mikeo/.ssh/id_rsa' # Path to private key used for authentication
deploy_pub: '/home/mikeo/.ssh/id_rsa.pub' # Path to public key used for authentication
deploy_mysqluser: root # The root user for the mysql database
deploy_mysqlpass: ReallyGoodPassword # The desired password for the 'root' db user
```

View all tasks: 
`[user@localhost]$ carton exec rex -T`

Run a task:
`[user@locahost]$ carton exec rex task_name`

Process for running deployment:
1. `[user@localhost]$ carton exec rex A000_update_pkg`
2. `[user@localhost]$ carton exec rex A001_bootstrap`
3. Update 'cmdb/deploy-vars.yml' to reflect the new SSH port (922 by default).
4. `[user@localhost]$ carton exec rex A002_prepare_web_pkgs`
5. `[user@localhost]$ carton exec rex A003_deploy_django`
