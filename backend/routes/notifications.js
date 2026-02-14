const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');

// Lấy danh sách notification của user (mới nhất trước)
router.get('/', auth, async (req, res) => {
  try {
    const notis = await Notification.find({ user: req.user.id })
      .sort({ createdAt: -1 })
      .limit(100);
    res.json(notis.map(n => ({
      id: n._id,
      title: n.title,
      body: n.body,
      avatar: n.avatar,
      isNew: n.isNew,
      type: n.type,
      targetId: n.targetId,
      createdAt: n.createdAt
    })));
  } catch (err) {
    res.status(500).send('Server Error');
  }
});

// Đánh dấu đã đọc
router.put('/:id/read', auth, async (req, res) => {
  try {
    await Notification.findByIdAndUpdate(req.params.id, { isNew: false });
    res.json({ success: true });
  } catch (err) {
    res.status(500).send('Server Error');
  }
});

module.exports = router;
