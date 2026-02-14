const express = require('express');
const router = express.Router();
const User = require('../models/User');
const auth = require('../middleware/auth');

// Get User Profile by ID
router.get('/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    if (!user) return res.status(404).json({ msg: 'User not found' });
    
    // Tính toán số lượng (nếu chưa lưu sẵn trong DB thì dùng countDocuments)
    // Ở đây ta dùng dữ liệu có sẵn trong User model
    res.json({
      ...user._doc,
      followersCount: user.followers.length,
      followingCount: user.following.length
    });
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') return res.status(404).json({ msg: 'User not found' });
    res.status(500).send('Server Error');
  }
});

// Follow/Unfollow User
router.put('/follow/:id', auth, async (req, res) => {
  try {
    if (req.params.id === req.user.id) {
      return res.status(400).json({ msg: 'Cannot follow yourself' });
    }
    const targetUser = await User.findById(req.params.id);
    const currentUser = await User.findById(req.user.id);

    if (!targetUser) return res.status(404).json({ msg: 'User not found' });

    // Check if already following
    if (targetUser.followers.includes(req.user.id)) {
      // Unfollow
      targetUser.followers = targetUser.followers.filter(id => id.toString() !== req.user.id);
      currentUser.following = currentUser.following.filter(id => id.toString() !== req.params.id);
      await targetUser.save();
      await currentUser.save();
      return res.json({ msg: 'Unfollowed', isFollowing: false });
    } else {
      // Follow
      targetUser.followers.push(req.user.id);
      currentUser.following.push(req.params.id);
      await targetUser.save();
      await currentUser.save();
      
      // TODO: Send Notification here
      
      return res.json({ msg: 'Followed', isFollowing: true });
    }
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Block User
router.put('/block/:id', auth, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user.id);
    if (!currentUser.blocked_users.includes(req.params.id)) {
      currentUser.blocked_users.push(req.params.id);
      
      // Also unfollow if blocking
      currentUser.following = currentUser.following.filter(id => id.toString() !== req.params.id);
      currentUser.followers = currentUser.followers.filter(id => id.toString() !== req.params.id);
      
      await currentUser.save();
    }
    res.json(currentUser.blocked_users);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Unblock User
router.put('/unblock/:id', auth, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user.id);
    currentUser.blocked_users = currentUser.blocked_users.filter(id => id.toString() !== req.params.id);
    await currentUser.save();
    res.json(currentUser.blocked_users);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Get Blocked Users List
router.get('/blocked', auth, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user.id).populate('blocked_users', 'full_name username avatar_url');
    res.json(currentUser.blocked_users);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Update Profile (Bio, Social Links)
router.put('/update-profile', auth, async (req, res) => {
  try {
    const { bio, social } = req.body;
    const user = await User.findById(req.user.id);
    if (bio) user.bio = bio;
    // Giả sử social input là username chung hoặc link, ở đây lưu tạm vào github field demo
    if (social) user.username = social; 
    await user.save();
    res.json(user);
  } catch (err) {
    res.status(500).send('Server Error');
  }
});

module.exports = router;