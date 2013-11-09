package Ponio::Apache;

use parent qw(Exporter);
@EXPORT = qw(hook_functions_apache ApacheIsRunning ApachePort ApacheVersion);

use JSON;

sub hook_functions_apache {
	my $self = shift;
	
	$self->on('list websites' => sub {
		my ($sock, $msg, $cb) = @_;
		my @sites = &GetApacheSites;
		$cb->(\@sites);
	});
	
	$self->on('create website' => sub {
		my ($sock, $msg, $cb) = @_;
		&CreateWebsite($msg);
		$cb->(JSON::true);
	});
	
	$self->on('disable website' => sub {
		my ($sock, $msg, $cb) = @_;
		&DisableWebsite($msg);
		$cb->(JSON::true);
	});
}

# Folder in which websites are made
# ToDo: Should be moved to config
my $Website_Root = "/home/www";
my $Website_Prefix = "www.";
my $Website_Postfix = "";

#######################
#  Status Operations  #
#######################

sub StartApache {
	`/etc/init.d/apache2 start`;
}

sub StopApache {
	`/etc/init.d/apache2 stop`;
}

sub RestartApache {
	`/etc/init.d/apache2 restart`;
}

###################
#  Current State  #
###################

sub ApacheIsRunning {
	if(`/etc/init.d/apache2 status | grep NOT`) {
		return 0;
	} else { return 1; }
}

sub ApacheVersion {
	my $vers = `apache2 -version`;
	$vers =~ /.+?(\d+\.\d+\.\d+).+/;
	return $1;
}

sub ApachePort {
	tie my @lines, 'Tie::File', '/etc/apache2/ports.conf', mode => O_RDONLY;
	my $temp = undef;
	
	foreach (@lines) {
		if($_ =~ /^Listen\s(\d+)/) {
			$temp = $1;
			last;
		}
	}
	untie @lines;
	return $temp;
}

################
#  List Sites  #
################

sub GetApacheSites {
	my @sites;
	my $dir = "/etc/apache2/sites-enabled";
	opendir(DIR,$dir) or return 0;
	while(my $file = readdir(DIR)) {
		# only files
		next unless (-f "$dir/$file");
		# ignore default
		next if ($file eq '000-default');
		# add website
		push @sites,$file;
	}
	return @sites;
}

##################
#  Disable Site  #
##################

sub DisableWebsite {
	my $var = shift;
	my %vars = %$var;
	my $name = $vars{"Name"};
	if(-e "/etc/apache2/sites-enabled/$name") {
		`rm /etc/apache2/sites-enabled/$name`;
	}
}

########################
#  Create new website  #
########################

sub CreateWebsite {
	my $var = shift;
	my %vars = %$var;
	my $name = $vars{"Name"};
	my $serverAdmin = $vars{"ServerAdmin"};
# Create folders
	unless(-e $Website_Root) {
		`mkdir $Website_Root`;
	}
	unless(-e "Website_Root/$Website_Prefix$name$Website_Postfix") {
		`mkdir $Website_Root/$Website_Prefix$name$Website_Postfix`;
		unless(-e "$Website_Root/$Website_Prefix$name$Website_Postfix/htdocs") {
			`mkdir $Website_Root/$Website_Prefix$name$Website_Postfix/htdocs`;
		}
		unless(-e "$Website_Root/$Website_Prefix$name$Website_Postfix/logs") {
			`mkdir $Website_Root/$Website_Prefix$name$Website_Postfix/logs`;
		}
		unless(-e "$Website_Root/$Website_Prefix$name$Website_Postfix/cgi-bin") {
			`mkdir $Website_Root/$Website_Prefix$name$Website_Postfix/cgi-bin`;
		}
	}
# Create Index File
	unless(-e "$Website_Root/$Website_Prefix$name$Website_Postfix/htdocs/index.html") {
		open(FH,">","$Website_Root/$Website_Prefix$name$Website_Postfix/htdocs/index.html");
		print FH "<h1>Welcome to $Website_Prefix$name$Website_Postfix</h1>";
		close FH;
	}
# Create Config File
	unless(-e "/etc/apache2/sites-available/$Website_Prefix$name$Website_Postfix") {
		open(FH,">","/etc/apache2/sites-available/$Website_Prefix$name$Website_Postfix");
		print FH "#\n#  $name (/etc/apache2/sites-available/$Website_Prefix$name$Website_Postfix)\n#\n\n";
		print FH "<VirtualHost *:80>\n";
		# Write General Info
		print FH "\tServerAdmin $serverAdmin\n";
		print FH "\tServerName $Website_Prefix$name$Website_Postfix\n";
		print FH "\tServerAlias $name\n\n";
		# Write Indexes
		print FH "\t# Indexes + Directory Root.\n";
		print FH "\tDirectoryIndex index.html\n";
		print FH "\tDocumentRoot /home/www/$Website_Prefix$name$Website_Postfix/htdocs/\n\n";
		# Write CGI
		print FH "\t# CGI Directory\n";
		print FH "\tScriptAlias /cgi-bin/ /home/www/$Website_Prefix$name$Website_Postfix/cgi-bin/\n";
		print FH "\t<Location /cgi-bin>\n";
		print FH "\t\t#Options +ExecCHI\n";
		print FH "\t</Location>\n\n\n\n";
		# Write log
		print FH "\t# Logfiles\n";
		print FH "\tErrorLog /home/www/$Website_Prefix$name$Website_Postfix/logs/error.log\n";
		print FH "\tCustomLog /home/www/$Website_Prefix$name$Website_Postfix/logs/access.log combined\n";
		print FH "</VirtualHost>";
		close FH;
	}
# Link Config File
	unless(-e "/etc/apache2/sites-enabled/$Website_Prefix$name$Website_Postfix") {
		`ln -s /etc/apache2/sites-available/$Website_Prefix$name$Website_Postfix /etc/apache2/sites-enabled/$Website_Prefix$name$Website_Postfix`;
	}
# Reload apache
	`/etc/init.d/apache2 reload`;
}

1;
