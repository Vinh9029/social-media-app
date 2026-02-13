const admin = require('firebase-admin');
const path = require('path');

// Đường dẫn tới file serviceAccountKey.json (bạn có thể đổi lại nếu cần)
const serviceAccount = require(path.join(__dirname, '../keys/social-app-12638-firebase-adminsdk-fbsvc-d65f70295b.json'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function sendNotificationFCM(token, title, body, data = {}) {
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data
    });
  } catch (err) {
    console.error('FCM error:', err.message);
  }
}

module.exports = { sendNotificationFCM };
