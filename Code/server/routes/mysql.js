
/*
 * Mysql
 */

 exports.details = function (req, res) {
    mysqlGetConfig(null,null,res);
};

function mysqlGetConfig(msg,code,res) {
    conn.emit('service summary', null, function (modules, data) {
        conn.emit('mysql getstate', null, function (config, data) {
            config.Status = modules.mysql.Status;
            config.DatabaseNames = [];
            var databases = [];

            for (i in config.Databases) {
                config.DatabaseNames.push(config.Databases[i].Name);
                var database = config.Databases[i].Name + ': ';

                for (j in config.Databases[i].Users) {
                    database += config.Databases[i].Users[j] + '; ';
                }

                databases.push(database);
            }

            config.DatabaseDescriptions = databases;

            res.render('modules/mysql', { modules: modules, module: 'mysql', config: config, msg: msg, code: code })
        });
    });  
}

exports.action = function (req, res) {
    // Add user
    if (req.body.AddUser != null) {
        var user = {Username: req.body.AddUser_Username, Password: req.body.AddUser_Password, Database: req.body.AddUser_Database};

        conn.emit('mysql create user', user, function (msg, data) {
            if (msg == true) {
                mysqlGetConfig('user creation', msg, res);
            }
            else {
                mysqlGetConfig(msg, null, res);
            }
        });
    }

    // Add database
    if (req.body.AddDatabase != null) {
        var database = {Database: req.body.AddDatabase_Database};

        conn.emit('mysql create database', database, function (msg, data) {
            if (msg == true) {
                mysqlGetConfig('database creation', msg, res);
            }
            else {
                mysqlGetConfig(msg, null, res);
            }
        });
    }

    // Delete user
    if (req.body.DelUser != null) {
        var user = {Username: req.body.DelUser_Username};

        conn.emit('mysql delete user', user, function (msg, data) {
            if (msg == true) {
                mysqlGetConfig('remove user', msg, res);
            }
            else {
                mysqlGetConfig(msg, null, res);
            }
        });
    }

    // Delete database
    if (req.body.DelDatabase != null) {
        var database = {Database: req.body.DelDatabase_Database};

        conn.emit('mysql delete database', database, function (msg, data) {
            if (msg == true) {
                mysqlGetConfig('remove database', msg, res);
            }
            else {
                mysqlGetConfig(msg, null, res);
            }
        });
    }

    // Link user to database
    if (req.body.Link != null) {
        var linkData = {Username: req.body.Link_Username, Database: req.body.Link_Database};

        conn.emit('mysql link user', linkData, function (msg, data) {
            if (msg == true) {
                mysqlGetConfig('link', msg, res);
            }
            else {
                mysqlGetConfig(msg, null, res);
            }
        });
    }

    // Unlink user to database
    if (req.body.Unlink != null) {
        var linkData = {Username: req.body.Link_Username, Database: req.body.Link_Database};

        conn.emit('mysql unlink user', linkData, function (msg, data) {
            if (msg == true) {
                mysqlGetConfig('link', msg, res);
            }
            else {
                mysqlGetConfig(msg, null, res);
            }
        });
    }

    // Mysql start
    if (req.body.Start != null) {
        conn.emit('service action', 'mysql start', function (code, data) {
            mysqlGetConfig('server start', code, res);
        });
    }

    // Mysql stop
    if (req.body.Stop != null) {
        conn.emit('service action', 'mysql stop', function (code, data) {
            mysqlGetConfig('server stop', code, res);
        });
    }

    // Mysql restart
    if (req.body.Restart != null) {
        conn.emit('service action', 'mysql restart', function (code, data) {
            mysqlGetConfig('server restart', code, res);
        });
    }
};