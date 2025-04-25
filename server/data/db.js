const mysql = require("mysql2");
const config = require("../config.js");
let connection = mysql.createConnection(config.db);

connection.connect(function(err){
    if(err){
        return console.log(err);
    }
    console.log("mysql server connected!");
});

module.exports = connection.promise();