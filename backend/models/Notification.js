const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // người nhận
  type: { type: String, required: true }, // like, comment, reply, follow, message
  title: { type: String, required: true },
  body: { type: String, required: true },
  avatar: { type: String },
  targetId: { type: String }, // id bài post, comment, user, message...
  isNew: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now }
});

const modelName = 'Notification';
module.exports = mongoose.models[modelName] || mongoose.model(modelName, NotificationSchema);
