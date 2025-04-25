const db = require('./data/db.js');

async function createKullaniciTable() 
{
    try {
        await db.execute(`CREATE TABLE IF NOT EXISTS kullanici (
                idkullanici int NOT NULL UNIQUE AUTO_INCREMENT,
                kullaniciAdi varchar(45) NOT NULL,
                email varchar(45) NOT NULL,
                password varchar(45) NOT NULL,
                kazanilanOyun int NOT NULL,
                toplamOyun int NOT NULL,
                PRIMARY KEY (idkullanici)
            ) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;`
        );
        console.log("Kullanici tablosu oluşturuldu.");
    }
    catch (error) {
        console.error("Error creating kullanici table:", error);
    }
}
/*
async function createGameTable() 
{
    try {
        await db.execute(`CREATE TABLE IF NOT EXISTS oyun (
                idgame int NOT NULL UNIQUE AUTO_INCREMENT,
                kullanici1ID int NOT NULL,
                kullanici2ID int NOT NULL,
                sure varchar(10) NOT NULL,

                PRIMARY KEY (idgame)
            ) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;`
        );
        console.log("Game tablosu oluşturuldu.");
    }
    catch (error) {
        console.error("Error creating game table:", error);
    }
}*/

createKullaniciTable();