const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Post = require('../models/Post');

router.get('/', async (req, res) => {
  try {
    const { q, type } = req.query;
    if (!q) return res.json({ users: [], posts: [] });

    let users = [];
    let posts = [];
    const regex = new RegExp(q, 'i');

    const isUserSearch = q.startsWith('@') || type === 'users';
    const cleanQuery = q.startsWith('@') ? q.slice(1) : q;
    const cleanRegex = new RegExp(cleanQuery, 'i');

    if (type === 'all' || type === 'users' || isUserSearch) {
      const rawUsers = await User.find({
        $or: [
          { username: cleanRegex },
          { full_name: cleanRegex },
          { email: cleanRegex }
        ]
      }).select('username full_name avatar_url bio followers').limit(10);

      users = rawUsers.map(u => ({
        id: u._id,
        username: u.username,
        name: u.full_name,
        avatar: u.avatar_url,
        bio: u.bio,
        followers: u.followers
      }));
    }

    if ((type === 'all' || type === 'posts') && !q.startsWith('@')) {
      const postResults = await Post.find({
        $or: [
          { content: regex },
          { title: regex }
        ]
      })
      .populate('author', 'username full_name avatar_url')
      .sort({ createdAt: -1 })
      .limit(20);

      posts = postResults.map(p => ({
        id: p._id,
        content: p.content,
        image: p.image_url, // Frontend dùng 'image' hoặc 'image_url' đều được, nhưng posts.js dùng 'image'
        author: p.author ? {
          id: p.author._id,
          name: p.author.full_name,
          username: p.author.username,
          avatar: p.author.avatar_url
        } : { id: 'unknown', name: 'Unknown', avatar: '' },
        likes: p.reactions ? p.reactions.length : 0,
        comments: 0,
        timestamp: p.createdAt
      }));
    }

    res.json({ users, posts });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

module.exports = router;