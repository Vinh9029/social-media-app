const admin = require('firebase-admin');
const path = require('path');
const Notification = require('../models/Notification');

// Đường dẫn tới file serviceAccountKey.json (bạn có thể đổi lại nếu cần)
const serviceAccount = require(path.join(__dirname, '../keys/social-app-12638-firebase-adminsdk-fbsvc-d65f70295b.json'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function sendNotificationFCM(token, title, body, data = {}, dbUserId = null, options = {}) {
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data
    });
    // Lưu notification vào database nếu có dbUserId
    // Chỉ lưu nếu có senderId và không bị tắt cờ saveToDb
    if (dbUserId && options.senderId && options.saveToDb !== false) {
      await Notification.create({
        recipient: dbUserId,
        sender: options.senderId,
        type: options.type || 'system',
        post: options.postId || null, // postId được truyền trong options
        content: body,
        read: false
        // Bỏ isNew vì là từ khóa dự phòng của Mongoose
      });
    }
  } catch (err) {
    console.error('FCM error:', err.message);
  }
}

module.exports = { sendNotificationFCM };
