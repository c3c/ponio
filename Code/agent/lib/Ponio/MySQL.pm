package Ponio::MySQL;

use parent qw(Exporter);
@EXPORT = qw(hook_functions_mysql mysqlRunning mysqlVer mysqlPort stopMysql startMysql getMysqlServerState);

use DBI;
use File::Slurp;
use JSON;

my $DB_HOST = "DBI:mysql:mysql:localhost";
my $DB_USER = "debian-sys-maint";
my $sqlconf = read_file("/etc/mysql/debian.cnf") =~ s/\r?\n/|/rg;
my $DB_PASS = $sqlconf =~ s/.*\|password[^=]*=\s*([^\|\s]+).*/$1/imr;

sub hook_functions_mysql {
	my $self = shift;

	$self->on('mysql create database' => sub {
		my ($sock, $msg, $cb) = @_;
		my @res = &createDatabase($msg);
		$cb->($res[0]? JSON::true : $res[1]);
	});
	
	$self->on('mysql create user' => sub {
		my ($sock, $msg, $cb) = @_;
	    my @res = &createDbUser($msg);
		$cb->($res[0]? JSON::true : $res[1]);
	});
	
	$self->on('mysql link user' => sub {
		my ($sock, $msg, $cb) = @_;
		my @res = &linkDbUser($msg);
		$cb->($res[0]? JSON::true : $res[1]);
	});
	
	$self->on('mysql delete database' => sub {
		my ($sock, $msg, $cb) = @_;
		my @res = &delDatabase($msg);
		$cb->($res[0]? JSON::true : $res[1]);
	});
	
	$self->on('mysql delete user' => sub {
		my ($sock, $msg, $cb) = @_;
		my @res = &delDbUser($msg);
		$cb->($res[0]? JSON::true : $res[1]);
	});
	
	$self->on('mysql unlink user' => sub {
		my ($sock, $msg, $cb) = @_;
		my @res = &unlinkDbUser($msg);
		$cb->($res[0]? JSON::true : $res[1]);
	});
	
	$self->on('mysql getstate' => sub {
		my ($sock, $msg, $cb) = @_;
		my %state = &getMysqlServerState;
		$cb->(\%state);
	});
}

# - Create Database - #
sub createDatabase {
	unless(mysqlRunning()) {
		return(0,"Mysql server is stopped");
	}

	my $var = shift;
	my %vars = %$var;
	my $dbName = $vars{"Database"};
	if(dbExists($dbName)) {
		return (0,"Database $dbName already exists");
	} else {
		my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
		my $add = $db->prepare('create database ' . $dbName);
		$add->execute() or return (0,"could not create database $dbName");
		$add->finish();
		return (1,"Created database $dbName");
	}
}


# - Create User - #
sub createDbUser {
	unless(mysqlRunning()) {
		return(0,"Mysql server is stopped");
	}
	                      
    my $var = shift;
    my %vars = %$var;
	my $userName = $vars{"Username"};
	my $dbName = $vars{"Database"};
	my $pass = $vars{"Password"};
	if(userExists($userName)) {
		return (0,"User $userName already exists");
	} else {
		if(!dbExists($dbName)) {
			return (0,"The database $dbName does not exist");
		} else {
			my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
			my $add = $db->prepare("grant ALL on $dbName.* to $userName\@localhost identified by ?");
			$add->execute($pass);
			if($add) {
				return (1,"Created user $userName\[$pass\] with all priveliges to $dbName");
			} else {
				return (0,"could not create user $userName");
			}
		}
	}
}


# - Link User - #
sub linkDbUser {
	unless(mysqlRunning()) {
	    return(0,"Mysql server is stopped");
	}    

	my $var = shift;
	my %vars = %$var;
	my $userName = $vars{"Username"};
	my $dbName = $vars{"Database"};
	if(!userExists($userName)) {
		return (0,"the user $userName does not exist");
	} else {
		if(!dbExists($dbName)) {
			return (0,"the database $dbName does not exist");
		} else {
			my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
			my $add = $db->prepare("grant ALL on $dbName.* to $userName\@localhost");
			$add->execute() or return (0,"could not give user $userName permissions to database $dbName");
			$add->finish();
			return (1,"give user $userName all priveliges to database $dbName");
		}
	}
}


# - Delete Database - #
sub delDatabase {
	unless(mysqlRunning()) {
	    return(0,"Mysql server is stopped");
	}
	    
	my $var = shift;
	my %vars = %$var;
	my $dbName = $vars{"Database"};
	if(!dbExists($dbName)) {
		return (0,"the database $dbName does not exist");
	} else {
		my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
		my $del = $db->prepare("drop database $dbName");
		$del->execute() or return (0,"could not delete database $dbName");
		$del->finish();
		return (1,"successfully delete database $dbName");
	}
}


# - Delete User - #
sub delDbUser {
	unless(mysqlRunning()) {
	    return(0,"Mysql server is stopped");
	}
	    
	my $var = shift;
	my %vars = %$var;
	my $userName = $vars{"Username"};
	if(!userExists($userName)) {
		return (0,"the user $userName does not exist")
	} else {
		my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
		my $del = $db->prepare("drop user $userName\@localhost");
		$del->execute() or return(0,"could not drop user $userName");
		$del->finish();
		return (1,"successfully deleted user $userName");
	}
}


# - Unlink User - #
sub unlinkDbUser {
	unless(mysqlRunning()) {
	    return(0,"Mysql server is stopped");
	}
	    
	my $var = shift;
	my %vars = %$var;
	my $userName = $vars{"Username"};
	my $dbName = $vars{"Database"};
	if(!userExists($userName)) {
		return (0,"user $userName does not exist");
	} else {
		if(!dbExists($dbName)) {
			return (0,"database $dbName does not exist");
		} else {
			my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
			my $revoke = $db->prepare("revoke ALL on $dbName.* from $userName\@localhost");
			$revoke->execute() or return (0,"could not revoke rights of user $userName to database $dbName");
			$revoke->finish();
			return (1,"successfully revoked rights of user $userName to database $dbName");
		}
	}
}


# - Check if running - #
sub mysqlRunning {
	if(`service mysql status | grep running`) {
		return 1;
	} else { return 0; }
}


# - Get Port number - #
sub mysqlPort {
	tie my @lines, 'Tie::File', '/etc/mysql/my.cnf', mode => O_RDONLY;
	my $temp = undef;
	foreach (@lines) {
		if($_ =~ /^port\s*=\s*([0-9]{1,5})/i) {
			$temp = $1;
			last;
		}
	}
	untie @lines;
	return $temp;
}


# - Get version - #
sub mysqlVer {
	my $ver = `mysql -V`;
	$ver =~ /^mysql\s+Ver\s+.+(\d{1,3}\.\d{1,3}\.\d{1,3}).+/;
	return $1;
}


# - Start / Stop - #
sub stopMysql {
	`service mysql stop`;
}

sub startMysql {
	`service mysql start`;
}




####################
#   Get DB State   #
####################

sub getMysqlServerState {
	unless(mysqlRunning()) {
	    return(0,"Mysql server is stopped");
	}    
	
	my %state;
	my @users;
	my @dbs;
	{
		my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
		my $check = $db->prepare('select distinct user from user');
		$check->execute();
		my @row;
		while(@row = $check->fetchrow_array) {
			push @users, $row[0];
		}
	}
	$state{"Users"} = \@users;
	{
		my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
		my $check = $db->prepare('show databases');
		$check->execute();
		my @row;
		while(@row = $check->fetchrow_array) {
			my %db;
			my @usrs;
			$db{"Name"} = $row[0];
			my $getUsers = $db->prepare('select grantee from information_schema.schema_privileges where table_schema = ? group by grantee');
			$getUsers->execute($row[0]);
			my @usr;
			while (@usr = $getUsers->fetchrow_array) {
				$usr[0] =~ /^'([^']+)'\@'localhost'/;
				push @usrs, $1;
			}
			$db{"Users"} = \@usrs;
			push @dbs, \%db;
		}
	}
	$state{"Databases"} = \@dbs;
    return %state;
}



# Helper functions
sub dbExists {
	unless(mysqlRunning()) {
	    return(0,"Mysql server is stopped");
	}    
	
	my $dbName = shift;
	my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
	my $check = $db->prepare('show databases');
	$check->execute;
	my @row;
	while(@row = $check->fetchrow_array) {
		if($dbName eq $row[0]) {
			return 1;
		}
	}
	$check->finish();
	return 0;
}

sub userExists {
	unless(mysqlRunning()) {
	    return(0,"Mysql server is stopped");
	}
	    
	my $userName = shift;
	my $db = DBI->connect($DB_HOST,$DB_USER,$DB_PASS);
	my $check = $db->prepare('select user from user where user=?');
	$check->execute($userName);
    my @row;
    while(@row = $check->fetchrow_array) {
    	if($userName eq $row[0]) {
    		return 1;
    	}
    }
    $check->finish();
    return 0;
}

1;
