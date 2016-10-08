package Flts::Django;

use Data::Random qw(:all);
use IO::Prompt;
use Term::ReadLine;
use Term::UI;
use Rex -base;
use Rex::Database::MySQL::Admin::User;
use Rex::Database::MySQL::Admin::Schema;
use Data::Dumper;

desc "Bootstrap the project";
task "build_site" => sub {
    my $uid = run "id -u";

    if ( $uid != "0" ) {
        say "You're not 'root', turning on 'sudo' mode.";
        sudo -on;
    }

    my $os_vars = case operating_system, {
        Debian => {
            os          => "Debian",
            www_group   => "www-data",
            python_path => "/usr/bin/python2.7"
          },
          Ubuntu => {
            os          => "Ubuntu",
            www_group   => "www-data",
            python_path => "/usr/bin/python2.7"
          },
          CentOS => {
            os          => "CentOS",
            www_group   => "apache",
            python_path => "/bin/python2.7"
          },
          default => {
            os          => "CentOS",
            www_group   => "apache",
            python_path => "/bin/python2.7"
          },
    };

    my $project = shift @_;
    my $term    = Term::ReadLine->new('sudo');

    say "Creating a group for the project.";
    create_group "$project", { system => 1 };

    say
"Creating a user for the project and adding them to $project and $os_vars->{'www_group'} groups.";
    create_user "$project",
      {
        comment     => "User for the $project project.",
        groups      => [ $project, $os_vars->{'www_group'} ],
        system      => 1,
        create_home => TRUE
      };
    run "gpasswd -a $project $os_vars->{'www_group'}";

    say "Creating directory structure for project and virtual environment...";

    # Create project and virtual environment directory structures
    my @directories_to_create = (
        "/opt/webapps/$project",        "/opt/webapps/$project/env",
        "/opt/webapps/$project/logs",   "/opt/webapps/$project/project",
        "/opt/webapps/$project/static", "/opt/webapps/$project/media"
    );
    foreach (@directories_to_create) {
        file "$_",
          ensure => "directory",
          owner  => "$project",
          group  => "$project";
    }
    chmod 2770, "/opt/webapps/$project", recursive => TRUE;

    say "Creating a virtual environment.";
    run
      "virtualenv --python=$os_vars->{'python_path'} /opt/webapps/$project/env";

};

task "django_db_create" => sub {
    my $db_user = shift @_;
    my $db_name = $db_user;
    set mysql => user => 'root';
    set mysql => password => prompt( 'Mysql root password: ', -echo => '*' );

    my @db_pass = rand_chars( set => 'alphanumeric', min => 24, max => 24 );
    my $pass = join( "", @db_pass );

    # Create the db user.
    Rex::Database::MySQL::Admin::User::create(
        {
            name     => "$db_user",
            host     => "localhost",
            password => join( "", @db_pass ),
            rights   => "ALL PRIVILEGES",
            schema   => "$db_name.*",
        }
    );

    Rex::Database::MySQL::Admin::Schema::create(
        {
            name => "$db_name"
        }
    );

    return join( "", @db_pass );
};

task "django_config" => sub {
    my $project = shift @_;
    my $domain  = shift @_;
    my $db_pass = shift @_;

    my $uid = run "id -u";

    if ( $uid != "0" ) {
        say "You're not 'root', turning on 'sudo' mode.";
        sudo -on;
    }

    file "/opt/webapps/$project/$project.vhost.conf",
      content => template(
        "templates/apache2-vhost.tpl",
        conf => {
            project => $project,
            domain  => $domain
        }
      ),
      owner        => "$project",
      group        => "$project",
      no_overwrite => TRUE;

    file "/opt/webapps/$project/db_settings.py",
      content => template(
        "templates/flts-django-db.tpl",
        conf => {
            project  => $project,
            password => $db_pass
        }
      ),
      owner        => "$project",
      group        => "$project",
      no_overwrite => FALSE;

    say 'Installing project requirements...';
    my $requirements_path =
      run "find /opt/webapps/$project/project -iname 'requirements.txt'";
    if ($requirements_path) {
        run "/opt/webapps/$project/env/bin/pip install -r $requirements_path",
          env => {
            "PATH"       => '/opt/webapps/$project/env:$PATH',
            "PYTHONPATH" => "/opt/webapps/$project/env"
          };
    }

    say "Project creation complete.";
    say "Updating django settings file...";
    my $settings_path =
      run "find /opt/webapps/$project/project -iname 'settings.py'";
    if ($settings_path) {
        append_if_no_such_line "$settings_path",
          line   => "\ntry:\n    from db_settings import *\nexcept:\n    pass",
          regexp => qr{^.*db_settings.*},
          on_change => sub {
            say "Updated settings.py with db_settings import.";
          };
    }

};

task "fetch_project" => sub {
    my $project_path = shift @_;
    my $user_home    = run 'echo $HOME';
    my $user         = run 'echo $USER';

    say "Detected user as $user and home directory as $user_home";

    my $term     = Term::ReadLine->new('sudo');
    my $repobool = $term->ask_yn(
        prompt =>
          "Is there an existing repository from which you'd like to pull?",
        default => "y"
    );

    my $repopath = '';
    if ($repobool) {
        $repopath = prompt("Repo URL/Path: ");
    }

    # Pull from the repo if we've defined one.
    if ( length($repopath) ) {
        say "Ensuring 'known_hosts' has the key for repo server.";
        file "$user_home/.ssh",
          ensure       => "directory",
          owner        => "$user",
          group        => "$user",
          no_overwrite => TRUE;
        chmod 700, "$user_home/.ssh";

        file "$user_home/.ssh/known_hosts",
          ensure       => "file",
          owner        => "$user",
          group        => "$user",
          no_overwrite => TRUE;
        chmod 600, "$user_home/.ssh/known_hosts";

        append_if_no_such_line "$user_home/.ssh/known_hosts",
'repos.bixly.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBF+GsxXtcWcv1t7KNTDEElOsPttrJ5NSpROM+N1gJ1aWh/dYGKR83F/k4Ch0PJnII7Tg5z/Z07n/louTVmtUWsg=';

        file "$user_home/.ssh/id_rsa_repos",
          content      => template("templates/flts-ssh_id.tpl"),
          owner        => "$user",
          group        => "$user",
          no_overwrite => TRUE;
        chmod 600, "$user_home/.ssh/id_rsa_repos";

        file "$user_home/.ssh/config",
          ensure       => 'file',
          owner        => "$user",
          group        => "$user",
          no_overwrite => TRUE;
        chmod 600, "$user_home/.ssh/config";

        append_if_no_such_line "$user_home/.ssh/config",
"\nHost repos.bixly.com\n\tHostname repos.bixly.com\n\tIdentityFile $user_home/.ssh/id_rsa_repos\n";

        say 'Pulling from repository. Assuming keys have been added.';
        run "git clone $repopath $project_path";
    }
    say "Finishing up with repos.";
};

