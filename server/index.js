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

// Placeholder for move validation logic
// TODO: Implement actual Scrabble word validation rules
const validateMove = (boardState, placedTiles) => {
  console.log("Validating move (placeholder)...", placedTiles);
  // For now, just return true. Implement real validation later.
  return true;
};

io.on('connection', (socket) => {
    console.log('✅ Yeni bağlantı:', socket.id);

    socket.on('findMatch', async ({ nickname, selectedMode }) => {
      console.log('Eşleşme arıyor:', nickname);
      try {
        const player = {
          socketID: socket.id,
          nickname,
          rack: [],
        };
  
        if (!waitingPlayer) {
          console.log('Bekleyen oyuncu yok, beklemeye alınıyor:', player);
          // Kimse yoksa beklemeye al
          waitingPlayer = { socket, player, selectedMode };
          return;
        }
        console.log('Bekleyen oyuncu bulundu:', waitingPlayer.player);
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
          console.log('room id: ', roomId);
          socket.join(roomId);
          socket.emit('joinRoomSuccess', room);
      
          // Odaya zaten bağlı olan diğer oyunculara da updateRoom gönderelim
          socket.to(roomId).emit('updateRoom', room);
      
        } catch (err) {
          console.error('joinRoom hatası:', err);
        }
    });


    socket.on('placeWord', async ({ roomId, nickname, placedTiles }) => {
      console.log(`placeWord event received from ${nickname} for room ${roomId}`, placedTiles);
      try {
        const room = await Room.findById(roomId);

        if (!room) {
          console.error(`placeWord Error: Room ${roomId} not found.`);
          // Optionally emit an error back to the sender
          // socket.emit('gameError', { message: 'Oda bulunamadı.' });
          return;
        }

        if (room.isGameOver) {
          console.log(`placeWord Info: Game in room ${roomId} is already over.`);
          return;
        }

        const playerIndex = room.players.findIndex(p => p.nickname === nickname);
        if (playerIndex === -1) {
          console.error(`placeWord Error: Player ${nickname} not found in room ${roomId}.`);
          // socket.emit('gameError', { message: 'Oyuncu odada bulunamadı.' });
          return;
        }

        // Check if it's the player's turn
        if (room.turnIndex !== playerIndex) {
          console.warn(`placeWord Warning: Not player ${nickname}'s turn in room ${roomId}.`);
          // socket.emit('gameError', { message: 'Sıra sizde değil.' });
          return;
        }

        // --- Basic Move Validation (Placeholder) ---
        if (!validateMove(room.boardState, placedTiles)) {
           console.log(`placeWord Info: Invalid move by ${nickname} in room ${roomId}.`);
           // socket.emit('gameError', { message: 'Geçersiz hamle.' });
           // TODO: Potentially revert temporary client state if needed
           return;
        }
        // --- End Validation ---


        // --- Update Board State ---
        placedTiles.forEach(tile => {
          if (tile.row >= 0 && tile.row < 15 && tile.col >= 0 && tile.col < 15) {
            // Ensure the target square on the board is actually empty before placing
            if (room.boardState[tile.row][tile.col] === '') {
               room.boardState[tile.row][tile.col] = tile.letter;
            } else {
               // This case should ideally be prevented by client-side checks
               // and more robust server validation, but log it for now.
               console.warn(`placeWord Warning: Attempted to place tile on non-empty square (${tile.row}, ${tile.col}) in room ${roomId}`);
            }
          } else {
             console.warn(`placeWord Warning: Invalid tile coordinates (${tile.row}, ${tile.col}) received for room ${roomId}`);
          }
        });
        // Mark boardState as modified for Mongoose
        room.markModified('boardState');
        // --- End Update Board State ---


        // --- Update Player Rack & Points (Placeholders) ---
        const player = room.players[playerIndex];
        let pointsEarned = 0; // TODO: Calculate actual points
        let lettersUsedCount = 0;

        placedTiles.forEach(tile => {
          const letterIndex = player.rack.indexOf(tile.letter);
          if (letterIndex !== -1) {
            player.rack.splice(letterIndex, 1);
            lettersUsedCount++;
          } else {
            // Handle potential cheating or errors (player didn't have the tile)
            console.error(`placeWord Error: Player ${nickname} in room ${roomId} did not have tile ${tile.letter}.`);
            // Decide how to handle this - revert move? penalize?
          }
        });

        // Draw new letters
        const lettersToDraw = Math.min(lettersUsedCount, room.letterBag.length);
        const newLetters = drawLettersFromBag(room.letterBag, lettersToDraw);
        player.rack.push(...newLetters);
        player.points += pointsEarned; // Add calculated points
        // Mark players array as modified
        room.markModified('players');
        // --- End Update Player Rack & Points ---


        // --- Advance Turn ---
        room.turnIndex = (room.turnIndex + 1) % room.players.length;
        room.lastMoveTime = new Date();
        // --- End Advance Turn ---

        // --- Check Game Over (Basic) ---
        // TODO: Implement proper game over conditions (e.g., bag empty + player rack empty, consecutive passes)
        // --- End Check Game Over ---


        await room.save();

        // Broadcast updated room state to all players in the room
        io.to(roomId).emit('updateRoom', room);
        console.log(`placeWord Success: Move by ${nickname} processed in room ${roomId}. Turn advanced.`);

      } catch (err) {
        console.error(`placeWord Error processing move in room ${roomId} for ${nickname}:`, err);
        // Optionally emit a generic error
        // socket.emit('gameError', { message: 'Hamle işlenirken bir sunucu hatası oluştu.' });
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
  
