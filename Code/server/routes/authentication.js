
/*
 * Authentication
 */

 exports.index = function (req, res) {
    res.render('login')
};

exports.login = function (req, res) {
    if (req.body.login != null) {
        if (req.body.username == config.username && req.body.password == config.password) {
            req.session.authenticatedPonio = true;

            conn.emit('service summary', null, function (modules, data) {
                res.render('overview', { modules: modules })
            });
        }
        else {
            res.render('login');
        }
    }
};