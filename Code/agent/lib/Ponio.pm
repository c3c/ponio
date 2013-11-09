package Ponio;

use parent qw(Exporter);
@EXPORT = qw(hook_functions);

use Ponio::Apache;
use Ponio::FTP;
use Ponio::MySQL;
use Ponio::Firewall;

sub hook_functions {
	my $self = shift;
	
    ## Module loading
    
	&hook_functions_ftp($self);
	&hook_functions_apache($self);
	&hook_functions_mysql($self);
	&hook_functions_firewall($self);
	
	## Utils
	
	$self->on('uptime' => sub {
		my ($sock, $msg, $cb) = @_;
		$cb->(`uptime`);
	});
	
	$self->on('exec' => sub {
		my ($sock, $msg, $cb) = @_;
		my @ret = `$msg 2>&1`;
		$cb->(\@ret);
	});
		
	## Global
	
	$self->on('service summary' => sub {
		my ($sock, $msg, $cb) = @_;
		my $service = !defined($msg) || !$msg ? 0 : $msg;
		my %summary = ();
	
		if (!$service || $service eq "ftp") {
			my %ftp = ();
			my %cfg = &ftp_parse_conf;
			$ftp{"ServerName"} = $cfg{"ServerName"} if exists $cfg{"ServerName"};
			$ftp{"Port"} = $cfg{"Port"} if exists $cfg{"Port"};
			$ftp{"Status"} = &ftp_status;
			$ftp{"Version"} = &ftp_version;
			$cb->(\%ftp) if $service;
			$summary{"ftp"} = \%ftp;
		}
	
		if (!$service || $service eq "mysql") {
			my %mysql = ();
			$mysql{"Status"} = &mysqlRunning ? "started" : "stopped";
			$mysql{"Port"} = &mysqlPort if &mysqlPort;
			$mysql{"Version"} = &mysqlVer if &mysqlVer;
			$cb->(\%mysql) if $service;
			$summary{"mysql"} = \%mysql;
		}
	
		if (!$service || $service eq "apache") {
			my %apache = ();
			$apache{"Status"} = &ApacheIsRunning ? "started" : "stopped";
			$apache{"Port"} = &ApachePort if &ApachePort;
			$apache{"Version"} = &ApacheVersion if &ApacheVersion;
			$cb->(\%apache) if $service;
			$summary{"apache"} = \%apache;
		}
		
		if (!$service || $service eq "firewall") {
			my %firewall = ();
			my %state = &getFirewallState;
			$firewall{"Status"} = $state{"status"} ? "started" : "stopped";
			$cb->(\%firewall) if $service;
			$summary{"firewall"} = \%firewall;
		}
	
		$cb->(\%summary);	
	});

	$self->on('service action' => sub {
		my ($sock, $msg, $cb) = @_;
		my ($service, $action) = split(/ /, $msg);
		if ($service eq 'ftp') {
			`service proftpd start` if ($action eq 'start');
			if ($action eq 'stop') {
				`service proftpd stop`;
				sleep 1;
			}
			$cb->(JSON::true);
		}
		if ($service eq 'mysql') {
			`service mysql start` if ($action eq 'start');
			`service mysql stop` if ($action eq 'stop');
			$cb->(JSON::true);
		}
		if ($service eq 'apache') {
			`service apache2 start` if ($action eq 'start');
			`service apache2 stop` if($action eq 'stop');
			$cb->(JSON::true);
		}
		if ($service eq 'firewall') {
			&restoreFirewall if($action eq 'start');
			&disableFirewall if($action eq 'stop');
			$cb->(JSON::true);
		}
		$cb->(JSON::false);
	});
}

1;
