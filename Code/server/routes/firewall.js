
/*
 * Firewall
 */

 exports.details = function (req, res) {
    firewallGetConfig(null,null,req,res);
};

function firewallGetConfig(msg,code,req,res) {
    conn.emit('service summary', null, function (modules, data) {
        conn.emit('firewall getconf', null, function (config, data) {
            config.Status = modules.firewall.Status;
            config.RuleDescriptions = [];
            config.RuleIds = [];

            config.RuleDescriptions.push('id type action interface destination protocol port');
            for (i in config.rules) {
                if (config.rules[i] != null) {
                    config.RuleIds.push(config.rules[i].id);
                    var rule = config.rules[i].id + ' ';

                    switch (config.rules[i].type) {
                        case 1:
                            rule += ' INPUT'
                            break;
                        case 2:
                            rule += ' OUPUT'
                            break;
                        case 3:
                            rule += ' FORWARD'
                            break;
                        default:
                            break;
                    }

                    if (config.rules[i].action != null && config.rules[i].action == 1) {
                        rule += ' ACCEPT';
                    }
                    else {
                        rule += ' REJECT';
                    }
                  
                    rule += ' ' + (typeof config.rules[i].interface != 'undefined' ? config.rules[i].interface : 'any');
                    rule += ' ' + (typeof config.rules[i].destination != 'undefined' ? config.rules[i].destination : 'any');
                    rule += ' ' + (typeof config.rules[i].protocol != 'undefined'  ? config.rules[i].protocol : 'any');
                    rule += ' ' + (typeof config.rules[i].port != 'undefined' ? config.rules[i].port : 'any');

                    config.RuleDescriptions.push(rule);
                }
            }

            res.render('modules/firewall', { modules: modules, module: 'firewall', config: config, msg: msg, code: code })
        });
    });  
}

exports.action = function (req, res) {
    // Add rule
    if (req.body.AddRule != null) {
        var rule = { interface: req.body.AddRule_Interface, destination: req.body.AddRule_Destination, protocol: req.body.AddRule_Protocol, port: req.body.AddRule_Port };

        switch (req.body.AddRule_Type) {
            case 'INPUT':
                rule.type = 1;
                break;
            case 'OUPUT':
                rule.type = 2;
                break;
            case 'FORWARD':
                rule.type = 3;
                break;
            default:
                break;
        }

        if (req.body.AddRule_Action == 'ACCEPT') {
            rule.action = 1;
        }

        conn.emit('firewall addrule', rule, function (msg, data) {
            firewallGetConfig(null, null, req, res);
        });
    }

    // Remove rule
    if (req.body.DelRule != null) {
        var rule = { id: req.body.DelRule_RuleId };

        conn.emit('firewall removerule', rule, function (msg, data) {
            /*if (msg == true) {
            apacheGetConfig('user creation', msg, res);
            }
            else {
            apacheGetConfig(msg, null, res);
            }*/
            firewallGetConfig(null, null, req, res);
        });
    }

    // Move rule
    if (req.body.MoveRule != null) {
        var rule = { id: req.body.MoveRule_RuleId, placeId: req.body.MoveRule_RulePlaceId, before: req.body.MoveRule_Before };

        conn.emit('firewall moverule', rule, function (msg, data) {
            /*if (msg == true) {
            apacheGetConfig('user creation', msg, res);
            }
            else {
            apacheGetConfig(msg, null, res);
            }*/
            firewallGetConfig(null, null, req, res);
        });
    }

    // Save firewall config
    if (req.body.Save != null) {
        if (req.body.Established) {
            conn.emit('firewall setestablished', true, function (code, data) {
                conn.emit('firewall savechanges', null, function (code, data) {
                    firewallGetConfig(null, null, req, res);
                })
            });
        }
        else {
            conn.emit('firewall setestablished', false, function (code, data) {
                conn.emit('firewall savechanges', null, function (code, data) {
                    firewallGetConfig(null, null, req, res);
                })
            });
        }
    }

    // Undo changes firewall config
    if (req.body.Undo != null) {
        conn.emit('firewall undochanges', null, function (code, data) {
            firewallGetConfig(null, null, req, res);
        });
    }

    // Firewall start
    if (req.body.Start != null) {
        conn.emit('service action', 'firewall start', function (code, data) {
            firewallGetConfig('server start', code, req, res);
        });
    }

    // Firewall stop
    if (req.body.Stop != null) {
        conn.emit('service action', 'firewall stop', function (code, data) {
            firewallGetConfig('server stop', code, req, res);
        });
    }

    // Firewall restart
    if (req.body.Restart != null) {
        conn.emit('service action', 'firewall restart', function (code, data) {
            firewallGetConfig('server restart', code, req, res);
        });
    }
};