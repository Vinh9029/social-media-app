const mongoose = require('mongoose');

const PostSchema = new mongoose.Schema({
  author: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true 
  },
  content: { type: String },
  image_url: { type: String },
  title: { type: String }, // Optional title
  
  // Interactions
  // Thay đổi từ mảng ID sang mảng Object để lưu loại reaction
  reactions: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    type: { type: String, enum: ['like', 'love', 'haha', 'wow', 'sad', 'angry'], default: 'like' }
  }],
  shares: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  
  // Comments sẽ được query từ collection Comment, nhưng có thể cache số lượng nếu cần
  
  createdAt: { type: Date, default: Date.now },
  editedAt: { type: Date }, // Thời gian chỉnh sửa
  originalPost: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Post' 
  } // Bài viết gốc nếu là chia sẻ
});

module.exports = mongoose.model('Post', PostSchema);