#!/usr/local/bin/plackup

BEGIN {
	my $login = (getpwuid $>);
	print "Root up first!\n" and exit if $login ne 'root';
}

use warnings;
use strict;

use lib "lib";
use File::Basename 'dirname';
use Cwd 'abs_path';
use Ponio;
use PocketIO;
use Twiggy::Server::TLS;
use Plack::Builder;
use Plack::App::File;
use JSON;

## Base setup

our %conf;
my $root = File::Basename::dirname(abs_path($0));
require ($0 =~ s/\.[^\.]+$/.cfg/r);

## Main router

my $app = builder {
	enable "Plack::Middleware::AccessLog", format => "combined";

	mount '/socket.io' => PocketIO->new(handler => sub {
		my ($self, $conn) = @_;
		my $ip = $conn->{"REMOTE_ADDR"};
		
		# IP check
		if ($conf{"allowed"} && !grep $ip eq $_, $conf{"allowed"}) {
			$self->close;
			print "Disallowed connection from $ip.\n";
		}
		
		# Auth
		$self->on('auth' => sub {
			my ($sock, $msg, $cb) = @_;
			if ($msg ne $conf{"auth_hash"}) {
				$self->close;
				print "Authentication failed for $ip.\n";
			} else {
				&hook_functions($self);
				$cb->(JSON::true);
			}
		});
	});

	# Socket.IO mounts
		
	mount '/socket.io/socket.io.js' =>
		Plack::App::File->new(file => "$root/public/socket.io.js");
		
	mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
		Plack::App::File->new(file => "$root/public/WebSocketMain.swf");
	
	mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
		Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");
		
	mount '/' => builder {
		enable "Static",
		path => qr/\.(?:js|css|jpe?g|gif|png|html?|swf|ico)$/,
		root => "$root/public";
		
		sub {[ 200, ['Content-Type' => 'text/html'], ['PonIO']]};
	}
};

## Start SSL instance

my $server = Twiggy::Server::TLS->new(
	host => $conf{"host"},
	port => $conf{"port"},
	tls_key => $conf{"ssl_key"},
	tls_cert => $conf{"ssl_cert"}
);

$server->register_service($app);
AE::cv->recv;
