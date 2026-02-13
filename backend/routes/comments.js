const express = require('express');
const router = express.Router();
const Comment = require('../models/Comment');
const Post = require('../models/Post');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { getAvatarFallback } = require('../utils/avatar');
const { sendNotificationFCM } = require('../utils/fcm');

// Helper: build comment tree
async function buildCommentTree(comments) {
  const map = {};
  comments.forEach(c => map[c._id] = { ...c._doc, replies: [] });
  const roots = [];
  comments.forEach(c => {
    if (c.parentId) {
      if (map[c.parentId]) map[c.parentId].replies.push(map[c._id]);
    } else {
      roots.push(map[c._id]);
    }
  });
  return roots;
}

// Get comments for a post (threaded)
router.get('/post/:postId', async (req, res) => {
  try {
    const comments = await Comment.find({ post: req.params.postId })
      .populate('author', 'username full_name avatar_url')
      .sort({ createdAt: 1 });
    const formatted = comments.map(c => ({
      id: c._id,
      content: c.content,
      author: {
        id: c.author._id,
        name: c.author.full_name,
        username: c.author.username,
        avatar: getAvatarFallback(c.author)
      },
      timestamp: c.createdAt,
      parentId: c.parentId,
      likes: c.likes ? c.likes.length : 0,
      replies: []
    }));
    const tree = await buildCommentTree(formatted);
    res.json(tree);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Add comment or reply
router.post('/post/:postId', auth, async (req, res) => {
  try {
    const { content, parentId } = req.body;
    const comment = new Comment({
      post: req.params.postId,
      author: req.user.id,
      content,
      parentId: parentId || null
    });
    await comment.save();
    await comment.populate('author', 'username full_name avatar_url');
    // Gửi notification cho chủ post nếu là comment gốc
    if (!parentId) {
      const post = await Post.findById(req.params.postId).populate('author');
      if (post && post.author && post.author.fcmToken && post.author._id.toString() !== req.user.id) {
        await sendNotificationFCM(
          post.author.fcmToken,
          'Có bình luận mới!',
          `${comment.author.full_name} đã bình luận bài viết của bạn`,
          { postId: post._id.toString() }
        );
      }
    } else {
      // Nếu là reply, gửi notification cho chủ comment cha
      const parentComment = await Comment.findById(parentId).populate('author');
      if (parentComment && parentComment.author && parentComment.author.fcmToken && parentComment.author._id.toString() !== req.user.id) {
        await sendNotificationFCM(
          parentComment.author.fcmToken,
          'Có phản hồi mới!',
          `${comment.author.full_name} đã trả lời bình luận của bạn`,
          { postId: req.params.postId }
        );
      }
    }
    res.json({
      id: comment._id,
      content: comment.content,
      author: {
        id: comment.author._id,
        name: comment.author.full_name,
        username: comment.author.username,
        avatar: comment.author.avatar_url
      },
      timestamp: comment.createdAt,
      parentId: comment.parentId,
      likes: 0,
      replies: []
    });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Like/Unlike comment
router.put('/:id/like', auth, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ msg: 'Comment not found' });
    const idx = comment.likes.indexOf(req.user.id);
    if (idx === -1) {
      comment.likes.push(req.user.id);
    } else {
      comment.likes.splice(idx, 1);
    }
    await comment.save();
    res.json({ likes: comment.likes.length });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

module.exports = router;
