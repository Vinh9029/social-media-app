const mongoose = require('mongoose');

const CommentSchema = new mongoose.Schema({
  post: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Post', 
    required: true 
  },
  author: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true 
  },
  content: { type: String, required: true },
  
  // Hỗ trợ Reply (Nested Comments)
  parentId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Comment', 
    default: null 
  },
  
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Comment', CommentSchema);