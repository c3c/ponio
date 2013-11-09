
/**
 * Module dependencies.
 */

var express = require('express')
  , connect = require('connect')
  , routes = require('./routes')
  , io = require('socket.io-client')
  , jade = require('jade')
  , ftp = require('./routes/ftp')
  , mysql = require('./routes/mysql')
  , apache = require('./routes/apache')
  , firewall = require('./routes/firewall')
  , authentication = require('./routes/authentication')
  , connected_to_agent = false;

var app = module.exports = express.createServer();
config = require('./config');
// Configuration

app.configure(function () {
    app.set('views', __dirname + '/views');
    app.set('view engine', 'jade');
    app.set('view options', { layout: false });
    app.use(express.logger());
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express.cookieParser());
    app.use(connect.cookieSession({ secret: 'my little pony', cookie: { maxAge: 60 * 60 * 1000 }}));
    app.use(app.router);
    app.use(express.static(__dirname + '/public'));
});

app.configure('development', function(){
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
});

app.configure('production', function(){
  app.use(express.errorHandler());
});

conn = null;

var route = function (req, res) {
    if (connected_to_agent) {
        if ((!req.session.authenticatedPonio) && req.route.path != '/login/action') {
            authentication.index(req, res);
            return;
        }

        switch (req.route.path) {
            case '/login':
                authentication.index(req, res);
                break;
            case '/login/action':
                authentication.login(req, res);
                break;
            case '/error':
                routes.error(req, res);
                break;
            case '/modules/ftp':
                ftp.details(req, res);
                break;
            case '/modules/ftp/action':
                ftp.action(req, res);
                break;
            case '/modules/mysql':
                mysql.details(req, res);
                break;
            case '/modules/mysql/action':
                mysql.action(req, res);
                break;
            case '/modules/apache':
                apache.details(req, res);
                break;
            case '/modules/apache/action':
                apache.action(req, res);
                break;
            case '/modules/firewall':
                firewall.details(req, res);
                break;
            case '/modules/firewall/action':
                firewall.action(req, res);
                break;
            default:
                routes.overview(req, res);
                break;
        }
    }
    else {
        conn = io.connect(config.agent, { 'connect timeout': 3000, 'force new connection': true });

        conn.on('connect', function () {
            console.log("connection with agent established");
            connected_to_agent = true;

            conn.emit('auth', config.authenticationhash, function (success, data) {
                console.log("Authentication to agent was: " + success);
            });

            route(req, res);
        });

        conn.on('error', function () {
            console.log("connection with agent failed");
            connected_to_agent = false;
            routes.error(req, res,"connection with agent failed");
        });
    }
}

// Routes
app.get('/', route);
app.get('/overview', route);
app.get('/error', route);
app.get('/login', route);
app.post('/login/action', route);

app.get('/modules/ftp', route );
app.post('/modules/ftp/action', route);
app.get('/modules/mysql', route);
app.post('/modules/mysql/action', route); 
app.get('/modules/apache', route);
app.post('/modules/apache/action', route);
app.get('/modules/firewall', route);
app.post('/modules/firewall/action', route);

app.listen(process.env.port || 3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);