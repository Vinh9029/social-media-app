const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  full_name: { type: String },
  avatar_url: { type: String },
  cover_url: { type: String },
  bio: { type: String },
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
  
  // Social Login IDs
  googleId: { type: String },
  githubId: { type: String },

  // Social Links
  github: { type: String },
  facebook: { type: String },
  linkedin: { type: String },

  // Social Features
  followers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  following: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  saved_posts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Post' }],
  blocked_users: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('User', UserSchema);