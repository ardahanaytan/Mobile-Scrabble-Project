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
const turnTimers = new Map(); // roomId -> timeout


// Placeholder for move validation logic
// TODO: Implement actual Scrabble word validation rules
const validateMove = (boardState, placedTiles) => {
  console.log("Validating move (placeholder)...", placedTiles);
  // For now, just return true. Implement real validation later.
  return true;
};

function generateRandomPositions(count, occupied = new Set()) {
  const positions = new Set();

  while (positions.size < count) {
    const row = Math.floor(Math.random() * 15);
    const col = Math.floor(Math.random() * 15);
    const key = `${row},${col}`;
    if (!occupied.has(key)) {
      positions.add(key);
      occupied.add(key);
    }
  }

  return Array.from(positions).map(p => p.split(',').map(Number));
}

function initializeSpecialTiles() {
  const mineCounts = {
    PUAN_BOLUNMESI: 5,
    PUAN_TRANSFERI: 4,
    HARF_KAYBI: 3,
    EKSTRA_HAMLE_ENGELI: 2,
    KELIME_IPTALI: 2,
  };

  const rewardCounts = {
    BOLGE_YASAGI: 2,
    HARF_YASAGI: 3,
    EKSTRA_HAMLE_JOKERI: 2,
  };

  const mineMap = Array(15).fill(null).map(() => Array(15).fill(null));
  const rewardMap = Array(15).fill(null).map(() => Array(15).fill(null));
  const occupied = new Set();

  // Mayınları yerleştir
  for (const [type, count] of Object.entries(mineCounts)) {
    const positions = generateRandomPositions(count, occupied);
    for (const [row, col] of positions) {
      mineMap[row][col] = `M_${type}`;
    }
  }

  // Ödülleri yerleştir
  for (const [type, count] of Object.entries(rewardCounts)) {
    const positions = generateRandomPositions(count, occupied);
    for (const [row, col] of positions) {
      rewardMap[row][col] = `R_${type}`;
    }
  }

  return { mineMap, rewardMap };
}

const letterPoints = {
  'A': 1, 'B': 3, 'C': 4, 'Ç': 4, 'D': 3, 'E': 1, 'F': 7,
  'G': 5, 'Ğ': 8, 'H': 5, 'I': 2, 'İ': 1, 'J': 10, 'K': 1,
  'L': 1, 'M': 2, 'N': 1, 'O': 2, 'Ö': 7, 'P': 5, 'R': 1,
  'S': 2, 'Ş': 4, 'T': 1, 'U': 2, 'Ü': 3, 'V': 7, 'Y': 3, 'Z': 4
};

function calculateRackPenalty(rack) {
  return rack.reduce((total, letter) => {
    const point = letterPoints[letter.toUpperCase()] || 0;
    return total + point;
  }, 0);
}

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
          ...initializeSpecialTiles()
        });
  
        player.rack = drawLettersFromBag(room.letterBag, 7);
        waitingPlayer.player.rack = drawLettersFromBag(room.letterBag, 7);

        if (!player.rewardInventory) player.rewardInventory = {};
        if (!waitingPlayer.rewardInventory) waitingPlayer.player.rewardInventory = {};

        player.rewardInventory['R_HARF_YASAGI'] = 0;
        waitingPlayer.player.rewardInventory['R_HARF_YASAGI'] = 0;

        player.rewardInventory['R_EKSTRA_HAMLE_JOKERI'] = 0;
        waitingPlayer.player.rewardInventory['R_EKSTRA_HAMLE_JOKERI'] = 0;

        player.rewardInventory['R_BOLGE_YASAGI'] = 0;
        waitingPlayer.player.rewardInventory['R_BOLGE_YASAGI'] = 0;

  
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

        updateTurnTimer(room);
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
          io.to(roomId).emit('updateRoom', {
            ...room.toObject(),
            letterBagCount: room.letterBag.length,
          });
          
      
        } catch (err) {
          console.error('joinRoom hatası:', err);
        }
    });


    socket.on('placeWord', async ({ roomId, nickname, placedTiles, normalScore, score }) => {
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

        var isLeft = false;
        var isRight = false;

        placedTiles.forEach(tile => {
          if(tile.col >= 0 && tile.col <7 )
          {
            isLeft = true;
          }
          else if(tile.col >= 8 && tile.col <=15)
          {
            isRight = true;
          }
        });

        // left - right control
        console.log("isLR:",isLeft, isRight);
        console.log(room.activeZoneRestrictions);
        if(room.activeZoneRestrictions.get(nickname) === 'LEFT' && isLeft)
        {
          console.log("left!");
          socket.emit('zoneRestrictionError', {
            'message': 'Sola hamleniz engellendi!'
          });
          
          return;
        }
        else if(room.activeZoneRestrictions.get(nickname) === 'RIGHT' && isRight)
        {
          console.log("right!");
          socket.emit('zoneRestrictionError', {
            'message': 'Sağa hamleniz engellendi!'
          });
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
        let pointsEarned = score; // TODO: Calculate actual points
        let lettersUsedCount = 0;

        placedTiles.forEach(tile => {
          if (tile.isJoker) {
            const jokerIndex = player.rack.indexOf(' '); // joker varsa
            if (jokerIndex !== -1) {
              player.rack.splice(jokerIndex, 1);         // ✅ doğru şekilde jokeri sil
              lettersUsedCount++;
            } else {
              console.warn(`Joker harfi silinemedi – elde joker yok`);
            }
          } else {
            const index = player.rack.indexOf(tile.letter);
            if (index !== -1) {
              player.rack.splice(index, 1);
              lettersUsedCount++;
            } else {
              console.warn(`placeWord Error: Player ${nickname} did not have tile ${tile.letter}.`);
            }
          }
        });

        // 🔍 Yeni yerleştirilen taşlara bak: Ödül veya Ceza var mı?
        placedTiles.forEach(tile => {
          if (room.mineMap && room.mineMap[tile.row][tile.col]) {
            console.log(`💣 ${tile.letter} harfi mayına denk geldi! Türü: ${room.mineMap[tile.row][tile.col]}`);
            switch (room.mineMap[tile.row][tile.col]) {
              case 'M_PUAN_BOLUNMESI':
                pointsEarned = Math.floor(pointsEarned * 0.3);
                break;
              case 'M_PUAN_TRANSFERI':
                const opponent = room.players.find(p => p.nickname !== nickname);
                if (opponent) {
                  opponent.points += pointsEarned;
                  pointsEarned = 0; 
                }
                break;
              case 'M_HARF_KAYBI':
                const lostLetters = [...player.rack]; // elindeki tüm harfleri kaybeder
                room.letterBag.push(...lostLetters);

                player.rack = [];

                lettersUsedCount = 7;
                break;
              case 'M_EKSTRA_HAMLE_ENGELI':
                pointsEarned = normalScore;
                break;
              case 'M_KELIME_IPTALI':
                pointsEarned = 0;
                break;
            }
          }

          if (room.rewardMap && room.rewardMap[tile.row][tile.col]) {
            const rewardType = room.rewardMap[tile.row][tile.col];
            console.log(`🎁 ${tile.letter} harfi ödüle denk geldi! Türü: ${rewardType}`);

            if (!player.rewardInventory[rewardType]) {
              player.rewardInventory[rewardType] = 0;
            }
            player.rewardInventory[rewardType] += 1;
            console.log('PLAYER REWARD INVENTORY: ', player.rewardInventory);
          }
        });

        room.activeZoneRestrictions.delete(nickname);
        player.frozenIndexes = [];
        room.markModified('activeZoneRestrictions');


        // Draw new letters
        const lettersToDraw = Math.min(lettersUsedCount, room.letterBag.length);
        const newLetters = drawLettersFromBag(room.letterBag, lettersToDraw);
        player.rack.push(...newLetters);
        player.points += pointsEarned; // Add calculated points
        // Mark players array as modified
        
        // --- End Update Player Rack & Points ---

        room.consecutivePasses = 0;

        // --- Advance Turn ---
        if (player.extraMoveActive) {
          player.extraMoveActive = false; // tek seferlik kullanıldı
          console.log("🎯 Ekstra hamle hakkı kullanıldı, sıra değişmedi.");
        } else {
          room.turnIndex = (room.turnIndex + 1) % room.players.length;
        }
        room.lastMoveTime = new Date();
        // --- End Advance Turn ---

        // --- Check Game Over (Basic) ---
        
        if(player.rack.length == 0)
          {
            var playerPoint = player.points;
            var opponentPoint = opponent.points;

            //rakibe ceza olayi
            var eldekiPuanlar = 0;
            var opponentRacks = opponent.rack;
            const penalty = calculateRackPenalty(opponentRacks);
            opponent.points -= penalty;
            opponentPoint -= penalty;

            //oyunu bitirme
            room.isGameOver = true;
            if(playerPoint > opponentPoint)
            {
              room.winner = player.nickname;
            }
            else if(playerPoint < opponentPoint)
            {
              room.winner = opponent.nickname;
            }
            else
            {
              room.winner = room.players[0].nickname;
            }
        }
  

        // --- End Check Game Over ---

        room.markModified('players');
        await room.save();

        // Broadcast updated room state to all players in the room
        io.to(roomId).emit('updateRoom', {
          ...room.toObject(),
          letterBagCount: room.letterBag.length,
        });        
        console.log(`placeWord Success: Move by ${nickname} processed in room ${roomId}. Turn advanced.`);

        updateTurnTimer(room);

      } catch (err) {
        console.error(`placeWord Error processing move in room ${roomId} for ${nickname}:`, err);
        // Optionally emit a generic error
        // socket.emit('gameError', { message: 'Hamle işlenirken bir sunucu hatası oluştu.' });
      }
    });

    socket.on('passTurn', async ({ roomId, nickname }) => {
      console.log(`passTurn event received from ${nickname} in room ${roomId}`);

      try {
        const room = await Room.findById(roomId);
        if (!room) {
          console.error(`passTurn Error: Room ${roomId} not found.`);
          return;
        }

        const playerIndex = room.players.findIndex(p => p.nickname === nickname);
        if (playerIndex === -1 || room.turnIndex !== playerIndex) {
          console.warn(`passTurn Warning: It's not ${nickname}'s turn in room ${roomId}.`);
          return;
        }

        // ✅ Pas sayısını artır
        room.consecutivePasses = (room.consecutivePasses || 0) + 1;

        if (room.consecutivePasses >= 2) {
          room.isGameOver = true;
          const sorted = [...room.players].sort((a, b) => b.points - a.points);
          const highestScore = sorted[0].points;

          // Eğer eşitlik varsa ilk olan kazanır (istersen eşitliği de kontrol edebiliriz)
          const winnerPlayer = sorted.find(p => p.points === highestScore);
          room.winner = winnerPlayer?.nickname || null;

          console.log(`🛑 Game over in room ${roomId} due to 2 consecutive passes.`);
          console.log(`🏆 Winner: ${room.winner}`);
          console.log(`🛑 Game over in room ${roomId} due to 2 consecutive passes.`);
        } else {
          room.turnIndex = (room.turnIndex + 1) % room.players.length;
          room.lastMoveTime = new Date();
        }

        await room.save();
        io.to(roomId).emit('updateRoom', {
          ...room.toObject(),
          letterBagCount: room.letterBag.length,
        });
        

        updateTurnTimer(room);

      } catch (err) {
        console.error(`passTurn Error:`, err);
      }
    });

    socket.on('surrender', async ({ roomId, nickname }) => {
      console.log(`⚠️ ${nickname} surrendered in room ${roomId}`);
      try {
        const room = await Room.findById(roomId);
        if (!room || room.isGameOver) return;
    
        const playerIndex = room.players.findIndex(p => p.nickname === nickname);
        if (playerIndex === -1) return;
    
        // 🎯 Kazanan rakip
        const opponent = room.players.find(p => p.nickname !== nickname);
        room.winner = opponent?.nickname || null;
        room.isGameOver = true;
    
        await room.save();
        io.to(roomId).emit('updateRoom', {
          ...room.toObject(),
          letterBagCount: room.letterBag.length,
        });
        

        turnTimers.delete(room._id.toString());

      } catch (err) {
        console.error(`surrender error in room ${roomId}:`, err);
      }
    });

    socket.on('useZoneBlock', async ({ roomId, nickname, restrictedSide }) => {
      try {
        console.log("zoneblockdayiz");

        const room = await Room.findById(roomId);
        if (!room || room.isGameOver) return;

        const num = room.players.find(p => p.nickname === nickname)['rewardInventory']['R_BOLGE_YASAGI']
        console.log(num);
        if(num <= 0)
        {
          return;
        }
    
        const opponent = room.players.find(p => p.nickname !== nickname);
        if (!opponent) return;
    
        // Rakibin adıyla yasak bölgeyi işaretle
        console.log(opponent.nickname, "için", restrictedSide);
        room.activeZoneRestrictions.set(opponent.nickname, restrictedSide); // 'LEFT' ya da 'RIGHT'

        //buton azaltma
        const player = room.players.find(p => p.nickname === nickname)
        player.rewardInventory['R_BOLGE_YASAGI']-= 1;

        room.markModified('players');
        await room.save();
    
        io.to(roomId).emit('updateRoom', {
          ...room.toObject(),
          letterBagCount: room.letterBag.length
        });
      } catch (err) {
        console.error('useZoneBlock error:', err);
      }
    });
    
    socket.on('useReward', async ({ roomId, nickname, rewardKey }) => {
      const room = await Room.findById(roomId);
      const player = room.players.find(p => p.nickname === nickname);

      if (rewardKey === 'R_EKSTRA_HAMLE_JOKERI' && player.rewardInventory['R_EKSTRA_HAMLE_JOKERI'] > 0) {
        player.extraMoveActive = true;
        player.rewardInventory['R_EKSTRA_HAMLE_JOKERI'] -= 1;
        room.markModified('players');
        await room.save();
        io.to(roomId).emit('updateRoom', {
          ...room.toObject(),
          letterBagCount: room.letterBag.length,
        });
      }
    });

    socket.on('freeze_letter', async ({ roomId, nickname}) => {
      
      const room = await Room.findById(roomId);
      if (!room || room.isGameOver) return;

      //rakip racks sayisi
      const opponent = room.players.find(p => p.nickname !== nickname);
      if (!opponent) return;
      console.log("freeze letter for ", opponent.nickname);
      const op_rack_num = opponent.rack.length;

      let frozen = [];

      if (op_rack_num >= 2) {
        while (frozen.length < 2) {
          const rnd = Math.floor(Math.random() * op_rack_num);
          if (!frozen.includes(rnd)) {
            frozen.push(rnd);
          }
        }
      } else if (op_rack_num === 1) {
        frozen.push(0); 
      } else {
        frozen = [];
      }
      //save on db
      console.log("frozen:", frozen);
      opponent.frozenIndexes = frozen;

      const player = room.players.find(p => p.nickname === nickname);
      if(!player) return;

      player.rewardInventory['R_HARF_YASAGI'] -= 1;
      room.markModified('players');
      await room.save();
      io.to(roomId).emit('updateRoom', {
        ...room.toObject(),
        letterBagCount: room.letterBag.length,
      });

    });


    // Diğer eventler...
});

function updateTurnTimer(room) {
  const roomId = room._id.toString();

  // Önceki zamanlayıcıyı temizle
  if (turnTimers.has(roomId)) {
    clearTimeout(turnTimers.get(roomId));
  }

  const timeout = setTimeout(async () => {
    try {
      const room = await Room.findById(roomId);
      if (!room || room.isGameOver) return;

      const loser = room.players[room.turnIndex];
      const winner = room.players.find(p => p.nickname !== loser.nickname);

      room.isGameOver = true;
      room.winner = winner?.nickname || null;

      console.log(`⏱ Oyuncu süresini doldurdu ve kaybetti: ${loser.nickname}`);
      console.log(`🏆 Kazanan: ${room.winner}`);

      room.markModified('winner', 'isGameOver');
      await room.save();
      io.to(roomId).emit('updateRoom', {
        ...room.toObject(),
        letterBagCount: room.letterBag.length,
      });
      

    } catch (err) {
      console.error('❌ Zaman dolumu hatası:', err);
    }
  }, room.turnTimeLimit * 1000); // saniyeyi milisaniyeye çevir

  turnTimers.set(roomId, timeout);
}


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
    const [nickname_control,] = await db.execute('SELECT kullaniciAdi FROM kullanici WHERE email = ?', [email]);
    nickname = nickname_control[0].kullaniciAdi;

    if (email_control.length === 0 || email_control[0].password !== password) {
      return res.status(401).json({ message: 'Kullanıcı adı veya şifre yanlış' });
    }

    try {
      const Room = require('./models/room');
  
      // Toplam oyun sayısı (bitmiş oyunlar ve kullanıcı oynamış)
      const allGames = await Room.find({
        isGameOver: true,
        players: { $elemMatch: { nickname: nickname } }
      });
  
      const totalGames = allGames.length;
  
      // Kazanılan oyun sayısı
      const winCount = allGames.filter(room => room.winner === nickname).length;
  
      return res.status(200).json({
        kullaniciAdi: nickname,
        kazanilanOyun: winCount,
        toplamOyun: totalGames,
      });
    } catch (err) {
      console.error("❌ Kullanıcı istatistik hatası:", err);
      res.status(500).json({ message: 'İstatistik alınamadı.' });
    }
});
  

app.post('/api/get-stats', async (req, res) => {

  const { nickname } = req.body;
  console.log("nickname: ", nickname);
  if (!nickname) {
    return res.status(400).json({ message: 'nickname gerekli' });
  }
  try {
    const Room = require('./models/room');
  
    // Toplam oyun sayısı (bitmiş oyunlar ve kullanıcı oynamış)
    const allGames = await Room.find({
      isGameOver: true,
      players: { $elemMatch: { nickname: nickname } }
    });
    

    const totalGames = allGames.length;

    // Kazanılan oyun sayısı
    const winCount = allGames.filter(room => room.winner === nickname).length;
    console.log("totalGames: ", totalGames);
    console.log("winCount: ", winCount);

    return res.status(200).json({
      kullaniciAdi: nickname,
      kazanilanOyun: winCount,
      toplamOyun: totalGames,
    });
  }
  catch (err) {
    console.error("❌ Kullanıcı istatistik hatası:", err);
    res.status(500).json({ message: 'İstatistik alınamadı.' });
  }
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

app.get('/api/finished-rooms', async (req, res) => {
  try{
    const nickname = req.query.nickname;

    if (!nickname) {
      return res.status(400).json({ message: "nickname gerekli" });
    }

    const rooms = await Room.find({
      isGameOver: true,
      players: { $elemMatch: { nickname: nickname } }
    });
    res.status(200).json(rooms);
  }
  catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Biten odalar çekilemedi.' });
  }
});

  
