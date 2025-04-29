const mongoose = require('mongoose');
const playerSchema = require('./player');

const roomSchema = new mongoose.Schema({
  roomName: {
    type: String,
    required: true,
  },
  players: {
    type: [playerSchema],
    validate: [arr => arr.length <= 2, 'Oda en fazla 2 oyuncu içerebilir.']
  },
  turnTimeLimit: {
    type: Number,
    required: true, // saniye cinsinden
  },
  lastMoveTime: {
    type: Date,
    default: () => new Date()
  },
  turnIndex: {
    type: Number,
    default: 0, // 0: players[0], 1: players[1]
  },
  boardState: {
    type: [[String]],
    default: () => Array(15).fill().map(() => Array(15).fill('')), // 15x15 boş tahta
  },
  letterBag: {
    type: [String],
    default: () => [
      ...'A'.repeat(12), ...'B'.repeat(2), ...'C'.repeat(2), ...'Ç'.repeat(2),
      ...'D'.repeat(2), ...'E'.repeat(8), ...'F'.repeat(1), ...'G'.repeat(1),
      ...'Ğ'.repeat(1), ...'H'.repeat(1), ...'I'.repeat(4), ...'İ'.repeat(7),
      ...'J'.repeat(1), ...'K'.repeat(7), ...'L'.repeat(7), ...'M'.repeat(4),
      ...'N'.repeat(5), ...'O'.repeat(3), ...'Ö'.repeat(1), ...'P'.repeat(1),
      ...'R'.repeat(6), ...'S'.repeat(3), ...'Ş'.repeat(2), ...'T'.repeat(5),
      ...'U'.repeat(3), ...'Ü'.repeat(2), ...'V'.repeat(1), ...'Y'.repeat(2),
      ...'Z'.repeat(2), ...' '.repeat(2), // 2 joker harf
    ]
  },
  gameStarted: {
    type: Boolean,
    default: false,
  },
  isGameOver: {
    type: Boolean,
    default: false,
  },
  winner: {
    type: String,
    default: '',
  },
  moves: [{
    playerIndex: Number,
    word: String,
    startPosition: {
      row: Number,
      col: Number,
    },
    direction: { type: String, enum: ['horizontal', 'vertical'] },
    score: Number,
  }],
}, { timestamps: true });

// --- Helper Methods ---

// Helper function to shuffle an array (Fisher-Yates)
function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]]; // Swap elements
  }
}

// Method to shuffle the letter bag
roomSchema.methods._shuffleBag = function() {
  shuffleArray(this.letterBag);
};

// Method to draw tiles from the bag
// Takes the number of tiles needed as input
roomSchema.methods.drawTiles = function(numTiles) {
  // Ensure the bag is shuffled before drawing.
  // A robust implementation might track shuffle status.
  // For simplicity here, we shuffle before each draw batch,
  // though shuffling only once at game start and then drawing is more typical.
  // If called multiple times for one turn's refill, shuffling each time is incorrect.
  // Consider a dedicated startGame method to shuffle once.
  // this._shuffleBag(); // Let's assume the bag is shuffled at game start

  const drawnTiles = [];
  const tilesToDraw = Math.min(numTiles, this.letterBag.length); // Draw available tiles

  // Efficiently remove and collect tiles using splice
  if (tilesToDraw > 0) {
      // Using splice directly on the bag modifies it and returns the removed items
      const removed = this.letterBag.splice(0, tilesToDraw);
      drawnTiles.push(...removed);
  }

  // 'this.letterBag' is now updated automatically by splice
  return drawnTiles;
};

/*
  Example Usage (potentially in a startGame method):

  roomSchema.methods.startGame = async function() {
    if (this.gameStarted || this.players.length < 2) return; // Need 2 players

    this.gameStarted = true;
    this.lastMoveTime = new Date();
    this._shuffleBag(); // Shuffle ONCE at the start

    this.players.forEach(player => {
      // Assuming playerSchema has a 'tiles' array field
      player.tiles = this.drawTiles(7); // Draw 7 tiles for each player
    });

    // Determine starting player (e.g., randomly)
    this.turnIndex = Math.floor(Math.random() * this.players.length);

    await this.save(); // Persist changes
  };
*/


module.exports = mongoose.model('Room', roomSchema);
