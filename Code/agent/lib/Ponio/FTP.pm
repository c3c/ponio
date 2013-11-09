package Ponio::FTP;

use parent qw(Exporter);
@EXPORT = qw(hook_functions_ftp ftp_status ftp_version ftp_parse_conf);

use Tie::File;
use Fcntl 'O_RDONLY';
use JSON;

sub hook_functions_ftp {
	my $self = shift;

	$self->on('ftp getconf' => sub {
		my ($sock, $msg, $cb) = @_;
		my %cfg = &ftp_parse_conf;
		$cb->(\%cfg);
	});
	
	$self->on('ftp setconf' => sub {
		my ($sock, $msg, $cb) = @_;
		my $res = &ftp_write_conf($msg);
		$cb->($res ? JSON::true : JSON::false);
	});
}

sub ftp_status {
	my $status = `service proftpd status`;
	if ($status =~ /currently(( not)?) running/m) {
		my $stat = $1;
		return $stat eq " not" ? "stopped" : "started";
	} else {
		return undef;
	}
}

sub ftp_version {
	my $out = `proftpd -v 2>&1`;
	if ($out =~ /ProFTPD\s+(?:Version\s+)?(\d+\.[0-9\.]+[a-z]?)/i) {
		return $1;
	}
	return undef;
}

sub ftp_parse_conf {
	tie my @lines, 'Tie::File', '/etc/proftpd/proftpd.conf', mode => O_RDONLY;
	my %hash = ();

	foreach my $dtv (@lines) {
		if ($dtv =~ /^\s*([^#]\S*)\s+"?([^"]+)"?\s*/) {
			my ($key, $val) = ($1, $2);
			$val =~ s/(\s)+/$1/g;
			$hash{$key} = $val;
		}
	}
	untie @lines;

	my $sep = $/;	
	local $/ = undef;
	open(FILE, '/etc/proftpd/welcome.msg');
	$hash{"WelcomeMessage"} = <FILE>;
	$/ = $sep;
	chomp($hash{"WelcomeMessage"});
	close(FILE);
	
	return %hash;
}

sub ftp_write_conf {
	my $dirs = shift;
	my %directives = %$dirs;
	
	tie my @lines, 'Tie::File', '/etc/proftpd/proftpd.conf' or return 0;
	foreach my $line (@lines) {
		if ($line =~ /^\s*([^#]\S*)\s+(\S+.*?)\s*/) {
			my ($key, $val) = ($1, $2);
			if ($key eq "DisplayLogin") {
				$val = '/etc/proftpd/welcome.msg';
				open(FILE, '>/etc/proftpd/welcome.msg');
				print FILE $directives{'WelcomeMessage'};
				close(FILE);
			} elsif (grep { /\Q$key\E/i } keys %directives) {
				print "$key\n";
				$val = $directives{$key};
			} else {
				next;
			}
			$line =~ s/^\s*([^#]\S*\s+)("?)[^"]+("?)/$1$2$val$3/;
		}
	}
	untie @lines;
	return 1;
}

1;
