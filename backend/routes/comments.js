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
  comments.forEach(c => map[c.id] = { ...c, replies: [] });
  const roots = [];
  comments.forEach(c => {
    if (c.parentId) {
      if (map[c.parentId]) map[c.parentId].replies.push(map[c.id]);
    } else {
      roots.push(map[c.id]);
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
      reactions: c.reactions || [],
      editCount: c.editCount || 0,
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
          { postId: post._id.toString() },
          post.author._id,
          { 
            avatar: comment.author.avatar_url, 
            type: 'comment', 
            senderId: req.user.id,
            postId: post._id.toString()
          }
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
          { postId: req.params.postId },
          parentComment.author._id,
          { 
            avatar: comment.author.avatar_url, 
            type: 'reply', 
            senderId: req.user.id,
            postId: req.params.postId
          }
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
      reactions: [],
      editCount: 0,
      replies: []
    });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Reaction to comment
router.put('/:id/reaction', auth, async (req, res) => {
  try {
    const { type } = req.body; // 'like', 'love', 'haha', etc.
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ msg: 'Comment not found' });

    const idx = comment.reactions.findIndex(r => r.user.toString() === req.user.id);
    if (idx === -1) {
      comment.reactions.push({ user: req.user.id, type: type || 'like' });
    } else {
      // Nếu bấm lại icon cũ thì remove (toggle off), nếu icon mới thì update
      if (comment.reactions[idx].type === type) {
        comment.reactions.splice(idx, 1);
      } else {
        comment.reactions[idx].type = type;
      }
    }
    await comment.save();
    res.json(comment.reactions);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Edit comment
router.put('/:id', auth, async (req, res) => {
  try {
    const { content } = req.body;
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ msg: 'Comment not found' });
    if (comment.author.toString() !== req.user.id) return res.status(401).json({ msg: 'Unauthorized' });

    comment.content = content;
    comment.editCount = (comment.editCount || 0) + 1;
    await comment.save();
    res.json(comment);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

module.exports = router;
