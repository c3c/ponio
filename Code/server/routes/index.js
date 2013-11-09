exports.overview = function (req, res) {
    conn.emit('service summary', null, function (modules, data) {
        res.render('overview', { modules: modules })
    })
};

exports.error = function (req, res, error) {
    req.session = null;
    res.render('error', { error: error })
};