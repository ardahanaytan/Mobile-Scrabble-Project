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
//const DB = '';
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

let waitingPlayer = null;

io.on('connection', (socket) => {
    console.log('✅ Yeni bağlantı:', socket.id);
  
    socket.on('findMatch', async ({ nickname, selectedMode }) => {
      try {
        const player = {
          socketID: socket.id,
          nickname,
          rack: [],
        };
  
        if (!waitingPlayer) {
          // Kimse yoksa beklemeye al
          waitingPlayer = { socket, player, selectedMode };
          return;
        }
  
        // Bekleyen biri var, eşleştir
        const room = new Room({
            roomName: `oda-${waitingPlayer.socket.id}-${socket.id}`,
        });
  
        player.rack = drawLettersFromBag(room.letterBag, 7);
        waitingPlayer.player.rack = drawLettersFromBag(room.letterBag, 7);
  
        room.players.push(waitingPlayer.player);
        room.players.push(player);
  
        room.turnIndex = 0;
        room.turnTimeLimit = {
          '2dk': 120,
          '5dk': 300,
          '12saat': 43200,
          '24saat': 86400,
        }[selectedMode];
        room.gameStarted = true;
  
        await room.save();
  
        const roomId = room._id.toString();
        socket.join(roomId);
        waitingPlayer.socket.join(roomId);
  
        io.to(roomId).emit('matchFound', { room });
  
        waitingPlayer = null;
      } catch (err) {
        console.error('❌ Eşleşme hatası:', err);
      }
    });

    socket.on('joinRoom', async ({ roomId, nickname }) => {
        try {
          const room = await Room.findById(roomId);
      
          if (!room) {
            return socket.emit('errorJoin', { message: 'Oda bulunamadı.' });
          }
      
          const alreadyPlayer = room.players.find(p => p.nickname === nickname);
      
          if (!alreadyPlayer && room.players.length >= 2) {
            // Oda dolu ve kullanıcı zaten odada değilse
            return socket.emit('errorJoin', { message: 'Oda dolu.' });
          }
      
          if (!alreadyPlayer) {
            // Eğer kullanıcı odada yoksa ekleyelim
            const newPlayer = {
              socketID: socket.id,
              nickname: nickname,
              points: 0,
              rack: [],
            };
            room.players.push(newPlayer);
            await room.save();
          }
      
          socket.join(roomId);
          socket.emit('joinRoomSuccess', room);
      
          // Odaya zaten bağlı olan diğer oyunculara da updateRoom gönderelim
          socket.to(roomId).emit('updateRoom', room);
      
        } catch (err) {
          console.error('joinRoom hatası:', err);
        }
    });
      
      
  
    // Diğer eventler...
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
  




app.get('/api/active-rooms', async (req, res) => {
    try {
        const nickname = req.query.nickname;

        if (!nickname) {
            return res.status(400).json({ message: "nickname gerekli" });
        }

        const rooms = await Room.find({
            isGameOver: false,
            players: { $elemMatch: { nickname: nickname } }
        });

        res.status(200).json(rooms);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Aktif odalar çekilemedi.' });
    }
});
  
