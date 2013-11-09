var socket;

function onDeviceReady() {
  socket = io.connect('https://ponio.us:5051');
  socket.on('connect', function() {
    socket.emit('auth', '25fde83fe332950856d21619cf7794848c5a2a9cb5cc53bf5759034601f46cd00add0e0c589e657284761e6272ef8496', getStatus);
  });
}

function getStatus() {
  socket.emit('service summary', null, function (data) {
    console.log(data);
    var lbl = $('#ftp_status');
    $(lbl).removeClass("label-success");
    $(lbl).removeClass("label-important");
    $(lbl).addClass(data["ftp"]["Status"] == "started" ? "label-success" : "label-important");
    $(lbl).text(ucfirst(data["ftp"]["Status"]));

    var lbl = $('#apache_status')
    $(lbl).removeClass("label-success");
    $(lbl).removeClass("label-important");
    $(lbl).addClass(data["apache"]["Status"] == "started" ? "label-success" : "label-important");
    $(lbl).text(ucfirst(data["apache"]["Status"]));

    var lbl = $('#firewall_status')
    $(lbl).removeClass("label-success");
    $(lbl).removeClass("label-important");
    $(lbl).addClass(data["firewall"]["Status"] == "started" ? "label-success" : "label-important");
    $(lbl).text(ucfirst(data["firewall"]["Status"]));

    var lbl = $('#mysql_status')
    $(lbl).removeClass("label-success");
    $(lbl).removeClass("label-important");
    $(lbl).addClass(data["mysql"]["Status"] == "started" ? "label-success" : "label-important");
    $(lbl).text(ucfirst(data["mysql"]["Status"]));
  });
}

function init() {
    onDeviceReady();
    document.addEventListener("deviceready", onDeviceReady, false);
}

function ucfirst (str) {str += '';var f = str.charAt(0).toUpperCase();return f + str.substr(1);}