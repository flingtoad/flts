use strict;
use Rex -feature => [ 'exec_autodie', 'verbose_run', '0.31' ];
use Term::ReadLine;
use Term::UI;
use IO::Prompt;
use FileHandle;
use Rex::Commands::User;
use Rex::CMDB;
use Try::Tiny;

no warnings 'qw';

include "Flts::Bootstrap";
include "Flts::Webserver";
include "Flts::Django";

sayformat("[%D] MESG - [%h] %s");

set cmdb => {
    type           => 'YAML',
    path           => [ 'cmdb/deploy-vars.yml', ],
    merge_behavior => 'LEFT_PRECEDENT',
};

group deployto => get( cmdb("deploy_ip") ) . ":" . get( cmdb("deploy_port") );

auth for       => "deployto" => user => get( cmdb("deploy_user") ),
  private_key  => get( cmdb('deploy_key') ),
  public_key   => get( cmdb('deploy_pub') ),
  sudo_password => prompt( '[Deploy] Sudo: ', -echo => '*' );

sudo            => TRUE;

desc "Pull in new packages";
task "A000_update_pkgs",
  group => "deployto",
  sub {
    sudo -on;
    say "Updating the packages on the system...";
    update_package_db;
    update_system;
  };

desc "Bootstrap the system with users and a few default configs";
task "A001_bootstrap",
  group => "deployto",
  sub {
    my $new_user = {
        username => get( cmdb("new_user") ),
        password => get( cmdb("new_user_password") ),
        ssh_key  => get( cmdb("new_user_ssh_pub") ),
    };

    my $userid = run "id -u";

    if ( $userid != 0 ) {
        sudo -on;
    }

    my $os = case operating_system, {
          Debian  => "Debian",
          Ubuntu  => "Ubuntu",
          CentOS  => "CentOS",
          default => "CentOS",
    };

    say "OS detected as $os";

    say "Flts::Bootstrapping some basic packages.";
    Flts::Bootstrap::base_pkgs($os);

    say "Flts::Bootstrapping users and their home directories.";
    Flts::Bootstrap::create_admin_user(
        $os,
        $new_user->{'username'},
	$new_user->{'password'},
	$new_user->{'ssh_key'},
    );

    say "Flts::Bootstrapping some configs.";
    Flts::Bootstrap::editors( $new_user->{'username'} );
    Flts::Bootstrap::sudoers();

    # Check if we're on rhel derivative. If we are, configure selinux.
    if ( $os eq "CentOS" ) {
        say "Red Hat derivative detected. Configurng SELinux.";
        Flts::Bootstrap::selinux();
    }
    else {
        say "Debian derivative detected. Not configuring SELinux.";
    }

    say "Updating configuration for ssh. Moving it to port 922";
    Flts::Bootstrap::ssh();

    say "Update 'deploy-vars.yml' to reflect the newly created user.";
  };

desc "Install the base webserver/database packages";
task "A002_prepare_web_pkgs",
  group => "deployto",
  sub {
    my $userid = run "id -u";

    if ( $userid != 0 ) {
        sudo -on;
    }

    my $os = case operating_system, {
          Debian  => "Debian",
          Ubuntu  => "Ubuntu",
          CentOS  => "CentOS",
          default => "CentOS",
    };

    Flts::Webserver::deploy_webserver($os);
    Flts::Webserver::deploy_database($os);
  };

desc "Build the django project directory structure and virtual environment";
task "A003_deploy_django",
  group => "deployto",
  sub {
    my $project = prompt(
        "What is the name of the project you want to create (e.g. project01)?\n"
    );
    my $domain = prompt(
        "What is the domain where the project will live (e.g. example.com)?\n");

    my $known_hosts_entry = get( cmdb("repo_known_hosts_entry"));

    Flts::Django::build_site($project);
    Flts::Django::fetch_project("/opt/webapps/$project/project", $known_hosts_entry);
    my $db_user_pass = Flts::Django::django_db_create($project);
    Flts::Django::django_config( $project, $domain, $db_user_pass );

    # Adjust permissions on environment
    sudo -on;
    say "Adjusting permissions on new files.";
    chmod 2770, "/opt/webapps/$project", recursive => 1;
    chown "$project", "/opt/webapps/$project", recursive => 1;
    chgrp "$project", "/opt/webapps/$project", recursive => 1;

    say "MySQL User: $project";
    say "MySQL Password: $db_user_pass";
  };




