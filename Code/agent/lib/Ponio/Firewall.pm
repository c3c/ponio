package Ponio::Firewall;

use parent qw(Exporter);
@EXPORT = qw(hook_functions_firewall disableFirewall restoreFirewall getFirewallState);

use Tie::File;
use Fcntl 'O_RDONLY';
use List::MoreUtils qw(uniq);
use JSON;

my $firewallConfigPath = '/etc/iptables-ponio';
my $firewallLoaded = undef;
my %firewallConfig;

sub hook_functions_firewall {
	my $self = shift;
	
	&loadFirewallConf;
	
	$self->on('firewall getconf' => sub {
		my ($sock, $msg, $cb) = @_;
		my %state = &getFirewallState;
		$cb->(\%state);
	});
	
	$self->on('firewall addrule' => sub {
		my ($sock, $msg, $cb) = @_;
		
		# type: 1-INPUT, 2-OUTPUT, 3-FORWARD
		# action: 1-ACCEPT, undef-REJECT
		# interface: string
		# destination: string
		# protocol: string
		# port: string
		$cb->(&addFirewallRule($msg));
	});
	
	$self->on('firewall removerule' => sub {
		my ($sock, $msg, $cb) = @_;
		
		# id: int
		$cb->(&removeFirewallRule($msg));
	});
	
	$self->on('firewall setestablished' => sub {
		my ($sock, $msg, $cb) = @_;
		
		# established: bool
		$cb->(&setEstablished($msg));
	});
	
	$self->on('firewall savechanges' => sub {
		my ($sock, $msg, $cb) = @_;
		$cb->(&writeFirewallConf);
	});
	
	$self->on('firewall undochanges' => sub {
		my ($sock, $msg, $cb) = @_;
		$cb->(&loadFirewallConf);
	});
	
	$self->on('firewall moverule' => sub {
		my ($sock, $msg, $cb) = @_;
		
		# id: int
		# placeId: int
		# before: bool
		$cb->(&moveRule($msg));
	});
	
}

#######################
#  Temporary Disables #
#######################

sub disableFirewall {
	`service ufw stop`;
	`iptables -P INPUT ACCEPT` or return undef;
	`iptables -P OUTPUT ACCEPT` or return undef;
	`iptables -P FORWARD ACCEPT` or return undef;
	`iptables -F` or return undef;
	return 1;
}

sub restoreFirewall {
	`service ufw start`;
	`iptables-restore < $firewallConfigPath` or return undef;
	return 1;
}

######################
#  Config Functions  #
######################

sub getFirewallStatus {
#	my $saves = `iptables-save`;
#	my $lines = $saves =~ tr/\n//;
#	my $accept = () = $x =~ /ACCEPT/g;
#	return ($accept == 6 && $lines < 12 && $lines > 6) ? 1 : 0;
	return `service ufw status` =~ /start/ ? 1 : 0;
}

sub getFirewallState {
	$firewallConfig{'status'} = &getFirewallStatus;
	return %firewallConfig;
}

sub loadFirewallConf {
	%firewallConfig = ();
	$firewallConfig{'rules'} = &getFirewallRules;
	$firewallConfig{'established'} = &establishedAllowed;
	$firewallLoaded = 1;
	return 1;
}

sub writeFirewallConf {
	open(FILE, '>' . $firewallConfigPath) or return undef;
	print FILE "*filter\n:INPUT ACCEPT [0:0]\n:FORWARD ACCEPT [0:0]\n:OUTPUT ACCEPT [0:0]\n";
	my $rules = $firewallConfig{'rules'};
	if($firewallConfig{'established'}) {
		print FILE "-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT\n";
	}
	foreach(@$rules) {
		my %rule = %$_;
		if($rule{'id'}) { 
			my $line = '-A ';
			if($rule{'type'}  == 1) {
				$line .= 'INPUT ';
			}
			if($rule{'type'} == 2) {
				$line .= 'OUTPUT ';
			}
			if($rule{'type'} == 3) {
				$line .= 'FORWARD ';
			}
			if($rule{'interface'}) {
				$line .= "-i $rule{'interface'} ";
			}
			if($rule{'destination'}) {
				$line .= "-d $rule{'destination'} ";
			}
			if($rule{'protocol'}) {
				$line .= "-p $rule{'protocol'} ";
			}
			if($rule{'port'}) {
				$line .= "--dport $rule{'port'} ";
			}
			if($rule{'action'}) {
				$line .= "-j ACCEPT\n";
			} else {
				$line .= "-j REJECT\n";
			}
			print FILE $line;
		}
	}
	print FILE "COMMIT\n";
	close(FILE);
	&loadFirewallConf;
	return &restoreFirewall;
}







#####################
#  Change Settings  #
#####################

sub addFirewallRule {
	if($firewallLoaded) {
		my $var = shift;
		my %vars = %$var;
		my $type = $vars{'type'};
		my $action = $vars{'action'};
		my $interface = $vars{'interface'};
		my $destination = $vars{'destination'};
		my $protocol = $vars{'protocol'};
		my $port = $vars{'port'};
		my %rule = ();
		$rule{'type'} = $type;
		$rule{'action'} = $action;
		$rule{'id'} = (&getTopID + 1);
		if($interface) {
			$rule{'interface'} = $interface;
		}
		if($destination) {
			$rule{'destination'} = $destination;
		}
		if($protocol) {
			$rule{'protocol'} = $protocol;
		}
		if($port) {
			$rule{'port'} = $port;
		}
		push $firewallConfig{'rules'}, \%rule;
		return 1;
	} else {
		return undef;
	}
}

#sub removeFirewallRule {
#	if($firewallLoaded) {
#		my $var = shift;
#		my %vars = %$var;
#		my $type = $vars{'type'};
#		my $action = $vars{'action'};
#		my $interface = $vars{'interface'};
#		my $destination = $vars{'destination'};
#		my $protocol = $vars{'protocol'};
#		my $port = $vars{'port'};
#		my $index = 0;
#		my $removed = undef;
#		my $rules = $firewallConfig{'rules'};
#		foreach (@$rules) {
#			my %rule = %$_;
#			if(
#				$rule{'type'} == $type &&
#				(($rule{'action'} && $action) || (!$rule{'action'} && !$action)) &&
#				(($rule{'interface'} && $interface && $rule{'interface'} eq $interface) || (!$rule{'interface'} && !$interface)) &&
#				(($rule{'destination'} && $destination && $rule{'destination'} eq $destination) || (!$rule{'destination'} && !$destination)) &&
#				(($rule{'protocol'} && $protocol && $rule{'protocol'} eq $protocol) || (!$rule{'protocol'} && !$protocol)) &&
#				(($rule{'port'} && $port && $rule{'port'} eq $port) || (!$rule{'port'} && !$port))
#			) {
#				splice($firewallConfig{'rules'}, $index, 1);
#				$removed = 1;
#				last;
#			}
#			print "index: $index\n";
#			$index++;
#		}
#		return $removed;
#	} else {
#		return undef;
#	}
#}

sub removeFirewallRule {
	if ($firewallLoaded) {
		my $var = shift;
		my %vars = %$var;
		my $ind = $vars{'id'};
		my $removed = undef;
		my $rules = $firewallConfig{'rules'};
		my $index = 0;
		foreach (@$rules) {
			my %rule = %$_;
			if ($rule{'id'} == $ind) {
				splice($firewallConfig{'rules'}, $index, 1);
				$removed = 1;
				last;
			}
			$index++;
		}
		return $removed;
	} else {
		return undef;
	}
}

sub setEstablished {
	if($firewallLoaded) {
		my $allowed = shift;
		$firewallConfig{'established'} = $allowed;
		return 1;
	} else {
		return undef;
	}
}

sub moveRule {
	if($firewallLoaded) {
		# parameters
		my $var = shift;
		my %vars = %$var;
		my $id = $vars{'id'};
		my $beforeId = $vars{'placeId'};
		my $before = $vars{'before'};
		my $rls = $firewallConfig{'rules'};
		my @rules = @$rls;
		# holders
		my $index = undef;
		my $rule;
		
		my @out = @rules;
		my $arrInd = 0;
		foreach (@out) {
			my %ruleVars = %$_;
			if ($ruleVars{'id'} == $id) {
				$index = $arrInd;
				$rule = $_;
				splice(@out, $arrInd, 1);
				last;
			}
			$arrInd++;
		}
		unless ($index) {
			return undef;
		}
		
		$arrInd = 0;
		foreach (@out) {
			my %ruleVars = %$_;
			if ($ruleVars{'id'} == $beforeId) {
				my @ret;
				if ($before) {
					@ret = (@t[0..$arrInd-1], $rule, @out[$arrInd..scalar(@out)]);
				} else {
					@ret = (@out[0..$arrInd], $rule, @out[$arrInd+1..scalar(@out)]);
				}
				$firewallConfig{'rules'} = \@ret;
				return 1;
			}
			$arrInd++;
		}
		
		# place was not found
		return undef;
	} else {
		return undef;
	}
}







##############################
#  Private Config Functions  #
##############################

sub getFirewallRules {
	my @rules;
	tie my @lines, 'Tie::File', $firewallConfigPath, mode => O_RDONLY or return undef;
	my $index = 1;
	foreach(@lines) {
		# check if line contains rule
		if($_ =~ /^-A/ && !($_ =~ /-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT/)) {
			my %rule = ();
			$rule{'id'} = $index;
			$index++;
			if($_ =~ /^-A\s(INPUT|OUTPUT|FORWARD)/) {
				$rule{'type'} = $1 eq 'INPUT'? 1 : $1 eq 'OUTPUT'? 2 : 3;
			}
			if($_ =~ /^-A.+?-j\s(ACCEPT|REJECT)/) {
				$rule{'action'} = $1 eq 'ACCEPT'? 1 : undef;
			}
			if($_ =~ /^-A.+?-i\s([^\s]+)/) {
				$rule{'interface'} = $1;
			}
			if($_ =~ /^-A.+?-d\s([^\s]+)/) {
				$rule{'destination'} = $1;
			}
			if($_ =~ /^-A.+?-p\s([^\s]+)/) {
				$rule{'protocol'} = $1;
			}
			if($_ =~ /^-A.+?--dport\s([0-9]+)/) {
				$rule{'port'} = $1;
			}
			push @rules, \%rule;
		}
	}
	untie @lines;
	return \@rules;
}

sub establishedAllowed {
	tie my @lines, 'Tie::File', $firewallConfigPath, mode => O_RDONLY or return undef;
	my $temp = undef;
	foreach(@lines) {
		if($_ =~ /-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT/) {
			$temp = 1;
			last;
		}
	}
	untie @lines;
	return $temp;
}

sub getTopID {
	my $index = 0;
	my $rules = $firewallConfig{'rules'};
	foreach(@$rules) {
		my %rule = %$_;
		if ($rule{'id'} > $index) {
			$index = $rule{'id'};
		}
	}
	return $index;
}

1;
