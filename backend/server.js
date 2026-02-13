const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Static folder for uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Database Connection
mongoose.connect(process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/social-app')
    .then((conn) => console.log(`MongoDB Connected: ${conn.connection.host}`))
    .catch(err => {
        console.log('MongoDB Connection Error:', err.message);
        if (err.code === 8000) {
            console.log('>>> LỖI XÁC THỰC: Sai Username hoặc Password trong file .env');
            console.log('>>> Gợi ý: Hãy kiểm tra lại mật khẩu, đảm bảo không còn ký tự "<" hoặc ">" bao quanh.');
        }
    });

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/posts', require('./routes/posts'));
app.use('/api/users', require('./routes/users'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/search', require('./routes/search'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/comments', require('./routes/comments'));

// Socket.io logic
const onlineUsers = new Map();
io.on('connection', (socket) => {
  socket.on('user-online', (userId) => {
    onlineUsers.set(userId, socket.id);
  });

  socket.on('send-message', (data) => {
    const { recipientId, message } = data;
    const recipientSocket = onlineUsers.get(recipientId);
    if (recipientSocket) {
      io.to(recipientSocket).emit('receive-message', message);
    }
  });

  socket.on('disconnect', () => {
    for (const [userId, sockId] of onlineUsers.entries()) {
      if (sockId === socket.id) {
        onlineUsers.delete(userId);
        break;
      }
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).send('Something broke!');
});

// Create uploads folder if not exists
if (!fs.existsSync('./uploads')){
    fs.mkdirSync('./uploads');
}

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));