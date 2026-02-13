const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // Người nhận
  sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },    // Người gửi (tạo ra thông báo)
  type: { type: String, enum: ['like', 'comment', 'reply', 'follow', 'share', 'system'], required: true },
  post: { type: mongoose.Schema.Types.ObjectId, ref: 'Post' }, // Bài viết liên quan (nếu có)
  commentId: { type: mongoose.Schema.Types.ObjectId }, // ID của comment (nếu là reply)
  content: { type: String }, // Nội dung tùy chỉnh (nếu cần)
  read: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Notification', NotificationSchema);