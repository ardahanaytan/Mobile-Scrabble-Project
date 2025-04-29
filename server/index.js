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

const validateScrabbleMove = (placements, boardState) => {
    console.log("Dummy validation called for placements:", placements);
    // TODO: Implement actual Scrabble word validation logic here
    // - Check if words formed are valid (dictionary lookup)
    // - Check if placement connects to existing tiles (after first move)
    // - Check if all tiles are in a single line (row or column)
    return 1; // Placeholder for successful validation
};

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
    
    socket.on('placeTile', async ({ roomId, letter, row, col }) => {
        try {
          const room = await Room.findById(roomId);
          if (!room || !room.gameStarted) {
            // Oda bulunamadı veya oyun başlamadı
            return;
          }
  
          const playerIndex = room.players.findIndex(p => p.socketID === socket.id);
          if (playerIndex === -1 || room.turnIndex !== playerIndex) {
            // Oyuncu bulunamadı veya sıra onda değil
            // Belki bir hata mesajı gönderilebilir: socket.emit('error', 'Sıra sizde değil!');
            return;
          }
  
          const player = room.players[playerIndex];
          const tileIndex = player.rack.indexOf(letter);
  
          if (tileIndex === -1) {
            // Oyuncunun elinde bu harf yok
            // Belki bir hata mesajı gönderilebilir: socket.emit('error', 'Elinizde bu harf yok!');
            return;
          }
  
          if (room.boardState[row][col] !== '') {
            // Kare dolu
            // Belki bir hata mesajı gönderilebilir: socket.emit('error', 'Bu kare dolu!');
            return;
          }
  
          // --- State Update ---
          // Harfi rack'ten çıkar
          player.rack.splice(tileIndex, 1);
          // Harfi tahtaya yerleştir
          // Mongoose'un değişikliği algılaması için doğrudan atama yerine markModified gerekebilir
          // veya daha basit bir yol: yeni bir boardState oluşturup atamak.
          // Şimdilik doğrudan atama deneyelim:
          room.boardState[row][col] = letter;
          room.markModified('boardState'); // Mongoose'a boardState'in değiştiğini bildir
  
          // TODO: Puan hesaplama, kelime kontrolü, tur geçişi vb. eklenecek
  
          room.lastMoveTime = new Date(); // Son hamle zamanını güncelle
  
          await room.save();
  
          // Güncellenmiş oda bilgisini tüm oyunculara gönder
          io.to(roomId).emit('updateRoom', { room });
  
        } catch (err) {
          console.error(`❌ placeTile hatası (Oda: ${roomId}):`, err);
          // İstemciye genel bir hata mesajı gönderilebilir
          socket.emit('error', 'Harf yerleştirilirken bir hata oluştu.');
        }
      });
  
      socket.on('confirmMove', async ({ roomId, placements }) => {
        try {
          const room = await Room.findById(roomId);
          if (!room || !room.gameStarted) return; // Oda yok veya oyun bitmiş
  
          const playerIndex = room.players.findIndex(p => p.socketID === socket.id);
          if (playerIndex === -1 || room.turnIndex !== playerIndex) {
            // Sıra oyuncuda değil veya oyuncu odada değil
            return socket.emit('error', 'Hamle sırası sizde değil.');
          }
  
          const player = room.players[playerIndex];
          let currentBoardState = room.boardState.map(row => [...row]); // Deep copy for validation
  
          // --- Validation ---
          let isValidMove = true;
          const originalRack = [...player.rack]; // Copy rack before potential changes
          const usedRackIndices = new Set(); // Track used rack letters for duplicates
  
          for (const placement of placements) {
            const { letter, row, col } = placement;
  
            // 1. Check if square is empty on server's board
            if (currentBoardState[row][col] !== '') {
              isValidMove = false;
              socket.emit('error', `(${row},${col}) karesi zaten dolu.`);
              break;
            }
  
            // 2. Check if player *had* the letter (approximate check)
            // Note: This doesn't perfectly handle duplicate letters without more state.
            // It assumes the client sent letters the player generally possesses.
            // A more robust check would compare against the rack *before* temporary moves.
            let foundInRack = false;
            for(let i = 0; i < originalRack.length; i++) {
                if(originalRack[i] === letter && !usedRackIndices.has(i)) {
                    usedRackIndices.add(i);
                    foundInRack = true;
                    break;
                }
            }
            if (!foundInRack) {
               isValidMove = false;
               socket.emit('error', `Elinizde '${letter}' harfi bulunmuyor veya zaten kullandınız.`);
               break;
            }
  
  
            // Mark square as taken for subsequent checks in this loop
            currentBoardState[row][col] = letter;
          }
  
          // If initial placement checks failed, stop processing
          if (!isValidMove) {
            return;
          }
  
          // --- Scrabble Specific Validation ---
          const validationResult = validateScrabbleMove(placements, currentBoardState); // Call the dummy validation
  
          if (validationResult === 1) { // Proceed only if validation returns 1
              console.log("Move validation successful (dummy). Proceeding with state update.");
              // --- Update State ---
              // 1. Apply placements to the actual board state
              placements.forEach(p => {
                room.boardState[p.row][p.col] = p.letter;
              });
              room.markModified('boardState'); // Mark boardState as modified for Mongoose
  
              // 2. Remove used letters from player's rack (based on tracked indices)
              const newRack = originalRack.filter((_, index) => !usedRackIndices.has(index));
              player.rack = newRack;
  
  
              // 3. Draw new tiles
              const tilesNeeded = 7 - player.rack.length;
              const drawnTiles = drawLettersFromBag(room.letterBag, tilesNeeded);
              player.rack.push(...drawnTiles);
              room.markModified('letterBag'); // Mark letterBag as modified
  
              // TODO: Calculate score for the move
  
              // 4. Switch turn
              room.turnIndex = (room.turnIndex + 1) % room.players.length;
              room.lastMoveTime = new Date(); // Reset timer for the next player
  
              // --- Save and Broadcast ---
              await room.save();
              io.to(roomId).emit('updateRoom', { room }); // Send updated room to all players
          } else {
              // Validation failed (even the dummy one, though it won't currently)
              console.log("Move validation failed.");
              // Send an error message back to the client
              socket.emit('error', 'Geçersiz hamle.');
              // Note: We might need to revert temporary changes on the client if validation fails.
              // Currently, the client state (_temporaryPlacements, _currentRack) isn't automatically reverted.
              // This might require sending a specific 'validationFailed' event back.
          }
  
        } catch (err) {
          console.error(`❌ confirmMove hatası (Oda: ${roomId}):`, err);
          socket.emit('error', 'Hamle onaylanırken bir hata oluştu.');
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
  

