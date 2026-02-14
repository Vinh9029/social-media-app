const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const User = require('../models/User');
const Post = require('../models/Post');
const { getAvatarFallback } = require('../utils/avatar');
const { sendNotificationFCM } = require('../utils/fcm');

// Follow / Unfollow User
router.put('/follow/:id', auth, async (req, res) => {
  if (req.user.id === req.params.id) {
    return res.status(400).json({ msg: 'Bạn không thể follow chính mình' });
  }

  try {
    const targetUser = await User.findById(req.params.id);
    const currentUser = await User.findById(req.user.id);

    if (!targetUser || !currentUser) {
      return res.status(404).json({ msg: 'User not found' });
    }

    // Kiểm tra xem đã follow chưa
    if (targetUser.followers.some(id => id.toString() === req.user.id)) {
      // Đã follow -> Thực hiện Unfollow
      await targetUser.updateOne({ $pull: { followers: req.user.id } });
      await currentUser.updateOne({ $pull: { following: req.params.id } });
      res.json({ msg: 'Unfollowed', isFollowing: false });
    } else {
      // Chưa follow -> Thực hiện Follow
      targetUser.followers.push(currentUser._id);
      currentUser.following.push(targetUser._id);
      await targetUser.save();
      await currentUser.save();
      res.json({ msg: 'Followed', isFollowing: true });

      // Gửi notification FCM khi có người theo dõi mới
      if (targetUser.fcmToken && targetUser._id.toString() !== currentUser._id.toString()) {
        await sendNotificationFCM(
          targetUser.fcmToken,
          'Bạn có người theo dõi mới!',
          `${currentUser.full_name} đã theo dõi bạn`,
          { userId: currentUser._id.toString() },
          targetUser._id,
          { avatar: currentUser.avatar_url, type: 'follow', targetId: currentUser._id.toString() }
        );
      }
    }
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Toggle Save Post
router.put('/save/:postId', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    const postId = req.params.postId;

    // Kiểm tra xem đã lưu chưa
    if (user.saved_posts.some(id => id.toString() === postId)) {
      // Đã lưu -> Bỏ lưu
      await user.updateOne({ $pull: { saved_posts: postId } });
      res.json({ msg: 'Unsaved', isSaved: false });
    } else {
      // Chưa lưu -> Lưu (đưa lên đầu mảng)
      // Dùng $pull trước để đảm bảo không trùng, sau đó $push với $position 0
      await user.updateOne({ $pull: { saved_posts: postId } });
      await user.updateOne({ $push: { saved_posts: { $each: [postId], $position: 0 } } });
      res.json({ msg: 'Saved', isSaved: true });
    }
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Get Saved Posts
router.get('/saved', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).populate({
      path: 'saved_posts',
      populate: {
        path: 'author',
        select: 'username full_name avatar_url'
      }
    });

    // Đồng bộ cấu trúc bài viết đã lưu giống với News Feed
    const savedPosts = user.saved_posts.map(post => ({
      id: post._id,
      content: post.content,
      image: post.image_url,
      author: post.author ? {
        id: post.author._id,
        name: post.author.full_name,
        username: post.author.username,
        avatar: post.author.avatar_url
      } : { id: 'unknown', name: 'Unknown', avatar: '' },
      timestamp: post.createdAt
    }));

    res.json(savedPosts);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Block User
router.put('/block/:id', auth, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user.id);
    const targetId = req.params.id;

    if (!currentUser.blocked_users.some(id => id.toString() === targetId)) {
      await currentUser.updateOne({ $push: { blocked_users: targetId } });
    }
    res.json({ msg: 'User blocked' });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Unblock User
router.put('/unblock/:id', auth, async (req, res) => {
  try {
    const currentUser = await User.findById(req.user.id);
    const targetId = req.params.id;

    await currentUser.updateOne({ $pull: { blocked_users: targetId } });
    res.json({ msg: 'User unblocked' });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Lưu FCM token cho user
router.put('/fcm-token', auth, async (req, res) => {
  try {
    const { token } = req.body;
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ msg: 'User not found' });
    user.fcmToken = token;
    await user.save();
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Get user profile (with avatar fallback, followers, following, posts, shares)
router.get('/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id)
      .populate('followers', 'username full_name avatar_url')
      .populate('following', 'username full_name avatar_url');
    if (!user) return res.status(404).json({ msg: 'User not found' });

    // Get posts
    const posts = await Post.find({ author: user._id })
      .populate('author', 'username full_name avatar_url')
      .sort({ createdAt: -1 });
    // Get shares
    const shares = await Post.find({ shares: user._id })
      .populate('author', 'username full_name avatar_url')
      .sort({ createdAt: -1 });

    res.json({
      id: user._id,
      name: user.full_name,
      username: user.username,
      avatar: getAvatarFallback(user),
      cover: user.cover_url,
      bio: user.bio,
      followers: user.followers.map(f => ({
        id: f._id,
        name: f.full_name,
        username: f.username,
        avatar: getAvatarFallback(f)
      })),
      following: user.following.map(f => ({
        id: f._id,
        name: f.full_name,
        username: f.username,
        avatar: getAvatarFallback(f)
      })),
      followersCount: user.followers.length,
      followingCount: user.following.length,
      posts: posts.map(post => ({
        id: post._id,
        content: post.content,
        image: post.image_url,
        author: {
          id: post.author._id,
          name: post.author.full_name,
          username: post.author.username,
          avatar: getAvatarFallback(post.author)
        },
        timestamp: post.createdAt
      })),
      shares: shares.map(post => ({
        id: post._id,
        content: post.content,
        image: post.image_url,
        author: {
          id: post.author._id,
          name: post.author.full_name,
          username: post.author.username,
          avatar: getAvatarFallback(post.author)
        },
        timestamp: post.createdAt
      }))
    });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Get saved posts
router.get('/:id/saved-posts', async (req, res) => {
  try {
    const user = await User.findById(req.params.id).populate({
      path: 'saved_posts',
      populate: { path: 'author', select: 'username full_name avatar_url' }
    });
    if (!user) return res.status(404).json({ msg: 'User not found' });
    res.json(user.saved_posts.map(post => ({
      id: post._id,
      content: post.content,
      image: post.image_url,
      author: {
        id: post.author._id,
        name: post.author.full_name,
        username: post.author.username,
        avatar: getAvatarFallback(post.author)
      },
      timestamp: post.createdAt
    })));
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

module.exports = router;