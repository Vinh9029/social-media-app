const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Notification = require('../models/Notifications');

// Get notifications for current user
router.get('/', auth, async (req, res) => {
  try {
    const notifications = await Notification.find({ recipient: req.user.id })
      .sort({ createdAt: -1 })
      .populate('sender', 'username full_name avatar_url')
      .populate('post', 'content image_url')
      .limit(20);
    
    const formattedNotifications = notifications.map(n => ({
      id: n._id,
      type: n.type, // like, comment, follow...
      sender: n.sender ? {
        id: n.sender._id,
        name: n.sender.full_name,
        username: n.sender.username,
        avatar: n.sender.avatar_url
      } : { name: 'Unknown', avatar: '' },
      post: n.post,
      read: n.read,
      createdAt: n.createdAt
    }));
    
    res.json(formattedNotifications);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Mark notification as read
router.put('/:id/read', auth, async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);
    if (!notification) return res.status(404).json({ msg: 'Notification not found' });

    // Check user
    if (notification.recipient.toString() !== req.user.id) {
      return res.status(401).json({ msg: 'User not authorized' });
    }

    notification.read = true;
    await notification.save();

    res.json(notification);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Mark ALL as read
router.put('/read-all', auth, async (req, res) => {
  try {
    await Notification.updateMany(
      { recipient: req.user.id, read: false },
      { $set: { read: true } }
    );
    res.json({ msg: 'All notifications marked as read' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

module.exports = router;
