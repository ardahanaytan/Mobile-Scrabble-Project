const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();
const port = process.env.PORT | 3010;
const db_uri = process.env.URI;
var server = http.createServer(app);
const Room = require('./models/room');
var io = require('socket.io')(server);

app.use(express.json());


const DB = db_uri;
mongoose.connect(DB).then(() => {
    console.log("mongo tmm");
}).catch((e) => {
    console.log(e);
});

const db = require('./data/db');
require('./createtable');

const drawLettersFromBag = (letterBag, count) => {
    const drawn = [];
    for (let i = 0; i < count; i++) {
      if (letterBag.length === 0) break;
      const index = Math.floor(Math.random() * letterBag.length);
      drawn.push(letterBag[index]);
      letterBag.splice(index, 1); // torbadan çekilen harfi çıkar
    }
    return drawn;
};

io.on('connection', (socket) => {
    console.log('✅ Sunucu: Yeni bağlantı');

    socket.on('createRoom', async ({ nickname, selectedMode }) => {
        try {
          let room = new Room();
          room.roomName = `oda-${socket.id}`;
      
          // Oyun süresi modu (saniye cinsinden)
          const modeMap = {
            '2dk': 120,
            '5dk': 300,
            '12saat': 43200,
            '24saat': 86400
          };
      
          room.turnTimeLimit = modeMap[selectedMode] || 300; // varsayılan 5dk
      
          const player = {
            socketID: socket.id,
            nickname,
            rack: drawLettersFromBag(room.letterBag, 7),
          };
      
          room.players.push(player);
          room.turnIndex = 0;
          room.gameStarted = false;
      
          await room.save();
      
          const roomId = room._id.toString();
          socket.join(roomId);
      
          console.log(`✅ Oda oluşturuldu (${selectedMode}): ${roomId}`);
          console.log(room);
    
          io.to(roomId).emit('createRoomSuccess', room);
        } catch (err) {
          console.error("❌ Oda oluşturulurken hata:", err);
        }
    });  
});



server.listen(port, "0.0.0.0", () => {
    console.log(`Server started and running on port ${port}`);
});

function emailGecerliMi(email) {
    const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    return emailRegex.test(email);
}

function sifreGecerliMi(sifre) {
    const sifreRegex = /^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$/;
    return sifreRegex.test(sifre);
}

app.post('/api/register', async (req, res) => {
    const { username, email, password } = req.body;

    if(!username || !email || !password) {
        return res.status(400).json({
            message: 'Tüm alanların doldurulması zorunludur.'
        });
    }

    try {
        const [username_control,] = await db.execute('SELECT kullaniciAdi FROM kullanici WHERE kullaniciAdi = ?', [username]);
        const [email_control,] = await db.execute('SELECT email FROM kullanici WHERE email = ?', [email]);

        if(username_control.length > 0) {
            return res.status(400).json({
                message: 'Bu kullanıcı adı zaten mevcut.'
            });
        }

        else if(email_control.length > 0) {
            return res.status(400).json({
                message: 'Bu e-posta adresi zaten mevcut.'
            });
        }

        else if(!emailGecerliMi(email)) {
            return res.status(400).json({
                message: 'Geçersiz e-posta adresi.'
            });
        }
        
        else if(password.length < 8 || !sifreGecerliMi(password)) {
            return res.status(400).json({
                message: 'Şifre en az 8 karakter uzunluğunda olmalı ve en az bir büyük harf, bir küçük harf, bir rakam ve bir özel karakter içermelidir.'
            });
        }

        await db.execute('INSERT INTO kullanici (kullaniciAdi, email, password, kazanilanOyun, toplamOyun) VALUES (?, ?, ?, 0, 0)', [username, email, password]);
        return res.status(200).json({
            message: 'Kayıt başarılı.'
        });
    }
    catch (e)
    {
        res.status(500).json({
            message: 'Kayıt işlemi sırasında bir hata oluştu.'
        });
        console.error(e);
    }
});

app.post('/api/login', async (req, res) => {
    const { email, password } = req.body;
  
    const [email_control,] = await db.execute('SELECT * FROM kullanici WHERE email = ?', [email]);
    if (email_control.length === 0 || email_control[0].password !== password) {
      return res.status(401).json({ message: 'Kullanıcı adı veya şifre yanlış' });
    }
  
    res.status(200).json({ 
        message: 'Giriş başarılı.',
        kullaniciAdi: email_control[0].kullaniciAdi,
        kazanilanOyun: email_control[0].kazanilanOyun,
        toplamOyun: email_control[0].toplamOyun
    });
  });
  

