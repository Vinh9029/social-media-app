const express = require('express');
const router = express.Router();
const Post = require('../models/Post');
const Comment = require('../models/Comment');
const auth = require('../middleware/auth');
const Notification = require('../models/Notifications');

// Get Trending Posts (For Explore Page)
router.get('/trending', async (req, res) => {
  try {
    // Lấy bài viết, sắp xếp theo số lượng reaction giảm dần
    // Lưu ý: Đây là cách đơn giản, thực tế có thể cần aggregate framework
    const posts = await Post.find()
      .populate('author', 'username full_name avatar_url')
      .populate({
        path: 'originalPost',
        populate: {
          path: 'author',
          select: 'username full_name avatar_url'
        }
      })
      .sort({ 'reactions': -1, createdAt: -1 }) 
      .limit(20);

    const formattedPosts = await Promise.all(posts.map(async (post) => {
      const commentsCount = await Comment.countDocuments({ post: post._id });
      return {
        id: post._id,
        author: post.author ? {
          id: post.author._id,
          name: post.author.full_name,
          username: post.author.username,
          avatar: post.author.avatar_url
        } : { id: 'unknown', name: 'Unknown', avatar: '' },
        content: post.content,
        image: post.image_url,
        likes: post.reactions ? post.reactions.length : 0,
        reactions: post.reactions || [],
        comments: commentsCount,
        shares: 0,
        timestamp: post.createdAt,
        editedAt: post.editedAt,
        originalPost: post.originalPost
      };
    }));
    res.json(formattedPosts);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Get all posts
router.get('/', async (req, res) => {
  try {
    const posts = await Post.find()
      .populate('author', 'username full_name avatar_url')
      .populate({
        path: 'originalPost',
        populate: {
          path: 'author',
          select: 'username full_name avatar_url'
        }
      })
      .sort({ createdAt: -1 });

    // Enrich posts with comment counts and map to Frontend structure
    const postsWithCounts = await Promise.all(posts.map(async (post) => {
      const commentsCount = await Comment.countDocuments({ post: post._id });
      
      // Kiểm tra an toàn nếu author bị null (ví dụ user đã bị xóa)
      const authorData = post.author ? {
        id: post.author._id,
        name: post.author.full_name,
        username: post.author.username,
        avatar: post.author.avatar_url
      } : {
        id: 'unknown',
        name: 'Người dùng ẩn danh',
        username: 'unknown',
        avatar: ''
      };

      // Tính toán reaction của user hiện tại (nếu có login, nhưng ở route public này ta chỉ trả về tổng quan)
      // Logic chi tiết hơn sẽ nằm ở frontend hoặc route authenticated

      return {
        id: post._id,
        author: authorData,
        content: post.content,
        image: post.image_url,
        likes: post.reactions ? post.reactions.length : 0, // Tương thích ngược
        reactions: post.reactions || [],
        comments: commentsCount,
        shares: 0,
        timestamp: post.createdAt,
        title: post.title,
        editedAt: post.editedAt,
        originalPost: post.originalPost
      };
    }));

    res.json(postsWithCounts);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Create a post
router.post('/', auth, async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ message: 'Unauthorized' });

    const { content, image_url, title } = req.body;

    // Validation: Bài viết phải có ít nhất nội dung hoặc ảnh
    if (!content && !image_url) {
      return res.status(400).json({ message: 'Bài viết phải có nội dung hoặc hình ảnh' });
    }

    const newPost = new Post({
      author: req.user.id,
      title,
      content,
      image_url
    });

    const post = await newPost.save();
    await post.populate('author', 'username full_name avatar_url');

    res.json({
        id: post._id,
        author: {
          id: post.author._id,
          name: post.author.full_name,
          username: post.author.username,
          avatar: post.author.avatar_url
        },
        content: post.content,
        image: post.image_url,
        likes: 0,
        reactions: [],
        comments: 0,
        shares: 0,
        timestamp: post.createdAt,
        title: post.title,
        originalPost: null
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Toggle Like
router.post('/:id/reaction', auth, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ msg: 'Post not found' });

    const { type } = req.body; // 'like', 'love', 'haha', etc.
    const userId = req.user.id;

    // Tìm xem user đã react chưa
    const existingIndex = post.reactions.findIndex(r => r.user.toString() === userId);

    if (existingIndex !== -1) {
      // Nếu đã react
      if (post.reactions[existingIndex].type === type) {
        // Nếu cùng loại -> Xóa (Toggle off)
        post.reactions.splice(existingIndex, 1);
      } else {
        // Khác loại -> Cập nhật loại mới
        post.reactions[existingIndex].type = type;
      }
    } else {
      // Chưa react -> Thêm mới
      post.reactions.push({ user: userId, type: type || 'like' });
    }

    await post.save();
    res.json(post.reactions); 
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

// Get single post by ID
router.get('/:id', async (req, res) => {
  try {
    const post = await Post.findById(req.params.id)
      .populate('author', 'username full_name avatar_url')
      .populate({
        path: 'originalPost',
        populate: {
          path: 'author',
          select: 'username full_name avatar_url'
        }
      });
    if (!post) return res.status(404).json({ msg: 'Post not found' });
    
    const commentsCount = await Comment.countDocuments({ post: post._id });
    
    const authorData = post.author ? {
      id: post.author._id,
      name: post.author.full_name,
      username: post.author.username,
      avatar: post.author.avatar_url
    } : {
      id: 'unknown',
      name: 'Unknown',
      username: 'unknown',
      avatar: ''
    };

    res.json({
      id: post._id,
      author: authorData,
      content: post.content,
      image: post.image_url,
      likes: post.reactions ? post.reactions.length : 0,
      reactions: post.reactions || [],
      comments: commentsCount,
      shares: 0,
      timestamp: post.createdAt,
      title: post.title,
      editedAt: post.editedAt,
      originalPost: post.originalPost
    });
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') return res.status(404).json({ msg: 'Post not found' });
    res.status(500).send('Server Error');
  }
});

// Get comments for a post
router.get('/:id/comments', async (req, res) => {
  try {
    const comments = await Comment.find({ post: req.params.id })
      .populate('author', 'username full_name avatar_url')
      .sort({ createdAt: 1 });
      
    res.json(comments.map(comment => {
      const authorData = comment.author ? {
        id: comment.author._id,
        name: comment.author.full_name,
        username: comment.author.username,
        avatar: comment.author.avatar_url
      } : { id: 'unknown', name: 'Unknown', username: 'unknown', avatar: '' };

      return {
        id: comment._id,
        content: comment.content,
        author: authorData,
        timestamp: comment.createdAt,
        postId: comment.post,
        parentId: comment.parentId || null,
        likes: comment.likes || []
      };
    }));
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Add a comment
router.post('/:id/comments', auth, async (req, res) => {
  try {
    const newComment = new Comment({
      content: req.body.content,
      author: req.user.id,
      post: req.params.id,
      parentId: req.body.parentId || null,
      likes: []
    });
    
    await newComment.save();
    await newComment.populate('author', 'username full_name avatar_url');

    // --- TẠO THÔNG BÁO ---
    const post = await Post.findById(req.params.id);
    let recipientId = post.author;
    let notifType = 'comment';
    let notifContent = 'đã bình luận về bài viết của bạn';

    // Nếu là Reply (trả lời bình luận)
    if (req.body.parentId) {
      const parentComment = await Comment.findById(req.body.parentId);
      if (parentComment) {
        recipientId = parentComment.author;
        notifType = 'reply';
        notifContent = 'đã trả lời bình luận của bạn';
      }
    }

    // Chỉ tạo thông báo nếu người comment không phải là chính chủ
    if (recipientId.toString() !== req.user.id) {
      await new Notification({
        recipient: recipientId,
        sender: req.user.id,
        type: notifType,
        post: post._id,
        commentId: newComment._id,
        content: notifContent
      }).save();
    }
    // ---------------------

    res.json({
      id: newComment._id,
      content: newComment.content,
      author: {
        id: newComment.author._id,
        name: newComment.author.full_name,
        username: newComment.author.username,
        avatar: newComment.author.avatar_url
      },
      timestamp: newComment.createdAt,
      postId: newComment.post,
      parentId: newComment.parentId || null,
      likes: []
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Toggle Like Comment
router.post('/comments/:id/like', auth, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ msg: 'Comment not found' });

    if (!comment.likes) comment.likes = [];

    if (comment.likes.some(id => id.toString() === req.user.id)) {
      comment.likes = comment.likes.filter(id => id.toString() !== req.user.id);
    } else {
      comment.likes.unshift(req.user.id);
    }

    await comment.save();
    res.json(comment.likes);
  } catch (err) {
    res.status(500).send('Server Error');
  }
});

// Delete a comment
router.delete('/comments/:id', auth, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) return res.status(404).json({ msg: 'Comment not found' });

    if (comment.author.toString() !== req.user.id) {
      return res.status(401).json({ msg: 'User not authorized' });
    }

    await comment.deleteOne();
    res.json({ msg: 'Comment removed' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Update Post
router.put('/:id', auth, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ msg: 'Post not found' });

    // Check user
    if (post.author.toString() !== req.user.id) {
      return res.status(401).json({ msg: 'User not authorized' });
    }

    post.content = req.body.content || post.content;
    post.editedAt = Date.now();
    
    await post.save();
    res.json(post);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Delete Post
router.delete('/:id', auth, async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ msg: 'Post not found' });

    if (post.author.toString() !== req.user.id) {
      return res.status(401).json({ msg: 'User not authorized' });
    }

    await post.deleteOne();
    // Xóa luôn comment liên quan
    await Comment.deleteMany({ post: req.params.id });

    res.json({ msg: 'Post removed' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// Share Post
router.post('/:id/share', auth, async (req, res) => {
  try {
    const originalPost = await Post.findById(req.params.id);
    if (!originalPost) return res.status(404).json({ msg: 'Post not found' });

    // Nếu bài viết gốc cũng là bài share, hãy share bài gốc thực sự
    const sharedId = originalPost.originalPost ? originalPost.originalPost : originalPost._id;

    const newPost = new Post({
      author: req.user.id,
      content: req.body.content || '', // Nội dung người dùng viết thêm khi share
      originalPost: sharedId
    });

    await newPost.save();
    
    // Cập nhật số lượng share cho bài gốc (nếu muốn tracking)
    await Post.findByIdAndUpdate(sharedId, { $push: { shares: req.user.id } });

    res.json(newPost);
  } catch (err) {
    console.error(err);
    res.status(500).send('Server Error');
  }
});

module.exports = router;