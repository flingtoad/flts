package Flts::Bootstrap;
use Rex -base;
use Rex::Commands::Iptables;

task base_pkgs => sub {

=pod
Install some base packages on a centos/rhel/debian/ubuntu machine
=cut

    my $os = shift @_;

    if ( $os eq "CentOS" ) {
        say "Red Hat derivative detected. Proceeding.";
        install package => [
            "sudo",    "perl",
            "vim",     "emacs-nox",
            "git",     "htop",
            "setools", "policycoreutils-python"
        ];
        run 'yum groupinstall -y "Perl Support"';
        run 'yum groupinstall -y "Development Tools"';
    }
    else {
        say "Debian derivative detected. Proceeding.";
        install package =>
          [ "sudo", "perl", "vim", "emacs", "git", "htop", "build-essential", "postgresql-server-dev-all", "python2.7-dev", "tmux"];
    }
};

task create_admin_user => sub {

=pod
Create and admin user with sudo privileges
=cut

    my ( $os, $username, $user_pass, $user_ssh_pub ) = @_;

    say "Creating a group for '$username'.";
    create_group "$username";

    say "Creating a user for '$username'.";
    create_user "$username",
      {
        ensure         => "present",
        home           => "/home/$username",
        comment        => 'New user created by Rex',
        groups         => [ "$username", 'sys', 'users', 'adm' ],
        crypt_password => $user_pass,
        create_home    => TRUE,
        shell          => '/bin/bash',
        ssh_key        => $user_ssh_pub
      };

    if ( $os ne "CentOS" ) {
        say "Fixing keymap so CAPS acts an additional control key.";
        append_or_amend_line "/etc/default/keyboard",
          line   => 'XKBOPTIONS="ctrl:nocaps"',
          regexp => qr{^XKBOPTIONS=.*};
    }
};

task editors => sub {
    my $username = shift @_;
    say "Adding configs for a few editors for '$username'.";
    file "/home/$username/.emacs",
      source => "templates/emacs.tpl",
      owner  => $username,
      group  => $username,
      mode   => 640;
};

task sudoers => sub {
    say "Adding the 'adm' group to '/etc/sudoers'";
    append_if_no_such_line "/etc/sudoers",
      line      => '%adm        ALL=(ALL)        ALL',
      regexp    => '^%adm',
      on_change => sub {
        say "The 'adm' group was not found in the sudoers file. Adding it.";
      };

    append_if_no_such_line "/etc/sudoers",
      line   => "Defaults always_set_home",
      regexp => qr{^Defaults always_set_home};

};

task ssh => sub {
    my $sshd_name = case operating_system, {
        Debian    => "ssh",
          Ubuntu  => "ssh",
          CentOS  => "sshd",
          default => "sshd",
    };

    say
      "Changing port for SSH and restarting. Update your setting file for rex.";
    sed '.*Port \d*', 'Port 922', '/etc/ssh/sshd_config';

    if ( service $sshd_name => "status" ) {
        say "SSH is running. Restarting.";
        service $sshd_name => "restart";
    }
    else {
        say "SSHD not running. Starting.";
        service $sshd_name => "start";
    }

    if ( $sshd_name eq "sshd" ) {
        say "Setting some firewall options";
        open_port [ 53, 80, 443, 922 ];
        close_port "all";
    }
};

task selinux => sub {
    my $reboot = 0;

    say "Ensuring that SELinux is enabled";
    append_or_amend_line '/etc/sysconfig/selinux',
      line      => 'SELINUX=enabled',
      regexp    => qr{^SELINUX=(permissive)|(disabled)},
      on_change => sub {
        say "SELinux was enabled. You'll need to reboot.";
        $reboot = 1;
      };

    say "Adding configuration for new ssh port to selinux.";
    my $sshport_p = run 'semanage port -l | grep ssh_port_t';

    if ( $sshport_p !~ '922' ) {
        run "semanage port -a -t ssh_port_t -p tcp 922", auto_die => FALSE;
    }
};
