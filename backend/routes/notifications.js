const express = require('express');
const router = express.Router();
const Notification = require('../models/Notifications');
const auth = require('../middleware/auth');

// Get all notifications for current user
router.get('/', auth, async (req, res) => {
  try {
    const notifications = await Notification.find({ recipient: req.user.id })
      .sort({ createdAt: -1 })
      .populate('sender', 'username full_name avatar_url')
      .populate('post', 'content image_url');

    // Mark as read (optional: or do it in a separate route)
    // await Notification.updateMany({ recipient: req.user.id, read: false }, { read: true });

    const formatted = notifications.map(n => ({
      id: n._id,
      title: n.type === 'like' ? 'Thích bài viết' : n.type === 'comment' ? 'Bình luận mới' : 'Thông báo',
      body: `${n.sender.full_name} ${n.content || 'đã tương tác với bạn'}`,
      avatar: n.sender.avatar_url,
      senderId: n.sender._id,
      postId: n.post ? n.post._id : null,
      isNew: !n.read,
      timestamp: n.createdAt
    }));

    res.json(formatted);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

module.exports = router;