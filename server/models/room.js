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
  consecutivePasses: {
    type: Number,
    default: 0
  },
  mineMap: {
    type: [[String]],
    default: () => Array(15).fill(null).map(() => Array(15).fill(null)),
  },
  rewardMap: {
    type: [[String]],
    default: () => Array(15).fill(null).map(() => Array(15).fill(null)),
  },
  activeZoneRestrictions: {
    type: Map,
    of: String, // Örnek: 'LEFT' ya da 'RIGHT'
    default: {} // örn: { "deniyorum2": "LEFT" }
  },
  eventLogs: {
    type: [[String]],
    default: () => [],
  }

}, { timestamps: true });

module.exports = mongoose.model('Room', roomSchema);