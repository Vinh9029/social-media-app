const express = require('express');
const router = express.Router();
const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('cloudinary').v2;
const auth = require('../middleware/auth');
const User = require('../models/User');

// Cấu hình Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

// Cấu hình Storage
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: 'social-app',
    allowed_formats: ['jpg', 'png', 'jpeg', 'gif', 'webp'],
  },
});

const upload = multer({ storage: storage });

// Upload Avatar Route
router.post('/avatar', auth, upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'Vui lòng chọn file ảnh' });
    }

    // Cloudinary trả về đường dẫn ảnh trong req.file.path
    const avatarUrl = req.file.path;

    // Cập nhật avatar cho user trong DB
    await User.findByIdAndUpdate(req.user.id, { avatar_url: avatarUrl });

    res.json({ avatar: avatarUrl, message: 'Upload thành công' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Lỗi server khi upload' });
  }
});

// Upload Cover Image Route
router.post('/cover', auth, upload.single('cover'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'Vui lòng chọn file ảnh' });
    }

    // Tạo đường dẫn URL
    const coverUrl = req.file.path;

    // Cập nhật cover_url cho user trong DB
    await User.findByIdAndUpdate(req.user.id, { cover_url: coverUrl });

    res.json({ cover: coverUrl, message: 'Upload thành công' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Lỗi server khi upload' });
  }
});

// Upload Post Image Route
router.post('/post', auth, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'Vui lòng chọn file ảnh' });
    }

    // Tạo đường dẫn URL
    const imageUrl = req.file.path;

    // Trả về URL để frontend dùng tạo bài viết
    res.json({ url: imageUrl, message: 'Upload thành công' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Lỗi server khi upload' });
  }
});

// Lấy danh sách ảnh trong bộ sưu tập của User
router.get('/collection', auth, async (req, res) => {
  try {
    // Cloudinary không hỗ trợ list file đơn giản qua API public này
    // Trả về mảng rỗng hoặc cần implement Admin API nếu muốn
    res.json([]);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi lấy bộ sưu tập' });
  }
});

module.exports = router;