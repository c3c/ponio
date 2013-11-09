
/*
 * Apache
 */

 exports.details = function (req, res) {
    apacheGetConfig(null,null,res);
};

function apacheGetConfig(msg,code,res) {
    var config = {};
    conn.emit('service summary', null, function (modules, data) {
        conn.emit('list websites', null, function (websites, data) {
            config.Status = modules.apache.Status;
            config.Websites = websites;
            res.render('modules/apache', { modules: modules, module: 'apache', config: config, msg: msg, code: code })
        });
    });  
}

exports.action = function (req, res) {
    // Add website
    if (req.body.AddWebsite != null) {
        var website = {Name: req.body.AddWebsite_Name, ServerAdmin: req.body.AddWebsite_ServerAdmin};

        conn.emit('create website', website, function (msg, data) {
            /*if (msg == true) {
                apacheGetConfig('user creation', msg, res);
            }
            else {
                apacheGetConfig(msg, null, res);
            }*/
            apacheGetConfig(null,null,res);
        });
    }

    // Disable website
    if (req.body.DisableWebsite != null) {
        var website = {Name: req.body.DisableWebsite_Name};

        conn.emit('disable website', website, function (msg, data) {
            /*if (msg == true) {
                apacheGetConfig('user creation', msg, res);
            }
            else {
                apacheGetConfig(msg, null, res);
            }*/
            apacheGetConfig(null,null,res);
        });
    }

    // Apache start
    if (req.body.Start != null) {
        conn.emit('service action', 'apache start', function (code, data) {
            apacheGetConfig('server start', code, res);
        });
    }

    // Apache stop
    if (req.body.Stop != null) {
        conn.emit('service action', 'apache stop', function (code, data) {
            apacheGetConfig('server stop', code, res);
        });
    }

    // Apache restart
    if (req.body.Restart != null) {
        conn.emit('service action', 'apache restart', function (code, data) {
            apacheGetConfig('server restart', code, res);
        });
    }
};