/*
 * Ftp
 */

exports.details = function (req, res) {
    ftpGetConfig(null,null,res);
};

function ftpGetConfig(msg,code,res) {
    conn.emit('service summary', null, function (modules, data) {
        conn.emit('ftp getconf', null, function (config, data) {
            config.Status = modules.ftp.Status;
            res.render('modules/ftp', { modules: modules, module: 'ftp', config: config, msg: msg, code: code })
        }); 
    });  
}

exports.action = function (req, res) {
    // Save config
    if (req.body.Save != null) {
        conn.emit('ftp setconf', req.body, function (code, data) {
            ftpGetConfig('configuration save',code,res);
        });
    }

    // Ftp start
    if (req.body.Start != null) {
        conn.emit('service action', 'ftp start', function (code, data) {
            ftpGetConfig('server start',code,res);
        });
    }

    // Ftp stop
    if (req.body.Stop != null) {
        conn.emit('service action', 'ftp stop', function (code, data) {
            ftpGetConfig('server stop', code,res);
        });
    }

    // Ftp restart
    if (req.body.Restart != null) {
        conn.emit('service action', 'ftp restart', function (code, data) {
            ftpGetConfig('server restart', code,res);
        });
    }
};