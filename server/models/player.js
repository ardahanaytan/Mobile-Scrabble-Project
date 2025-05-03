const mongoose = require('mongoose');

const playerSchema = new mongoose.Schema({
  nickname: {
    type: String,
    trim: true,
    required: true,
  },
  socketID: {
    type: String,
    required: true,
  },
  points: {
    type: Number,
    default: 0,
  },
  rack: {
    type: [String], // Oyuncunun elindeki harfler
    default: [],
  },
  rewardInventory: {
    type: Object,
    default: {},
  }
});

module.exports = playerSchema;
