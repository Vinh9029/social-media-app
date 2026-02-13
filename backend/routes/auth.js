const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const auth = require('../middleware/auth');
const User = require('../models/User');

// Helper: Generate Token
const generateToken = (id) => {
  if (!process.env.JWT_SECRET) {
    console.error("FATAL ERROR: JWT_SECRET is not defined in .env file");
    throw new Error("Server configuration error: Missing JWT_SECRET");
  }
  return jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: '30d' });
};

// @route   GET api/auth/me
// @desc    Get current user
// @access  Private
router.get('/me', auth, async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
    const user = await User.findById(req.user.id).select('-password');
    if (!user) return res.status(404).json({ message: 'User not found' });

    // Đồng bộ data: Map các trường DB sang trường Frontend mong đợi
    res.json({
      id: user.id,
      username: user.username,
      email: user.email,
      name: user.full_name,       // Frontend dùng 'name'
      avatar: user.avatar_url,    // Frontend dùng 'avatar'
      cover: user.cover_url,
      bio: user.bio,
      github: user.github,
      facebook: user.facebook,
      linkedin: user.linkedin,
      followers: user.followers,
      following: user.following
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// @route   POST api/auth/register
// @desc    Register user
// @access  Public
router.post('/register', async (req, res) => {
  const { username, email, password, full_name } = req.body;

  try {
    // Check Email
    let user = await User.findOne({ email });
    if (user) {
      return res.status(400).json({ message: 'Email này đã được sử dụng' });
    }

    // Check Username
    let userByUsername = await User.findOne({ username });
    if (userByUsername) {
      return res.status(400).json({ message: 'Username này đã được sử dụng' });
    }

    user = new User({
      username,
      email,
      password,
      full_name,
      avatar_url: `https://ui-avatars.com/api/?name=${encodeURIComponent(full_name || username)}&background=random`
    });

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(password, salt);

    await user.save();

    const token = generateToken(user.id);
    res.json({ token, user: { id: user.id, username: user.username, email: user.email, name: user.full_name, avatar: user.avatar_url } });
  } catch (err) {
    console.error("Register Error:", err.message);
    res.status(500).send('Server error');
  }
});

// @route   POST api/auth/login
// @desc    Authenticate user & get token
// @access  Public
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    let user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid Credentials' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid Credentials' });
    }

    const token = generateToken(user.id);
    res.json({ token, user: { id: user.id, username: user.username, email: user.email, name: user.full_name, avatar: user.avatar_url } });
  } catch (err) {
    console.error("Login Error:", err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/auth/update
// @desc    Update user profile
// @access  Private
router.put('/update', auth, async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const fields = ['name', 'username', 'bio', 'avatar', 'cover', 'github', 'facebook', 'linkedin'];
    fields.forEach(field => {
      if (req.body[field] !== undefined) {
        if (field === 'name') user.full_name = req.body[field];
        else if (field === 'avatar') user.avatar_url = req.body[field];
        else if (field === 'cover') user.cover_url = req.body[field];
        else user[field] = req.body[field];
      }
    });

    await user.save();
    res.json({ 
      id: user.id, 
      username: user.username, 
      email: user.email, 
      name: user.full_name, 
      avatar: user.avatar_url,
      bio: user.bio,
      cover: user.cover_url,
      github: user.github,
      facebook: user.facebook,
      linkedin: user.linkedin
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// @route   PUT api/auth/change-password
// @desc    Change password
// @access  Private
router.put('/change-password', auth, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  try {
    if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
    const user = await User.findById(req.user.id);
    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) return res.status(400).json({ message: 'Mật khẩu hiện tại không đúng' });

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();
    res.json({ message: 'Đổi mật khẩu thành công' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// --- OAUTH ---

// Google Login
router.get('/google', (req, res) => {
  const redirectUri = process.env.GOOGLE_CALLBACK_URL;
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const url = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=profile email`;
  res.redirect(url);
});

// Google Callback
router.get('/google/callback', async (req, res) => {
  const { code } = req.query;
  try {
    // Exchange code for tokens
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        code,
        client_id: process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.GOOGLE_CLIENT_SECRET,
        redirect_uri: process.env.GOOGLE_CALLBACK_URL,
        grant_type: 'authorization_code'
      })
    });
    const tokenData = await tokenRes.json();
    
    // Get User Info
    const userRes = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { Authorization: `Bearer ${tokenData.access_token}` }
    });
    const userData = await userRes.json();

    // Logic login/register
    let user = await User.findOne({ email: userData.email });
    if (!user) {
      const randomPassword = crypto.randomBytes(16).toString('hex');
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(randomPassword, salt);
      
      user = new User({
        username: userData.email.split('@')[0] + Math.floor(Math.random() * 1000),
        email: userData.email,
        password: hashedPassword,
        full_name: userData.name,
        avatar_url: userData.picture,
        googleId: userData.sub
      });
      await user.save();
    } else if (!user.googleId) {
      // Nếu user đã tồn tại (do đăng ký email trước đó) nhưng chưa có googleId -> Cập nhật thêm
      user.googleId = userData.sub;
      await user.save();
    }

    const token = generateToken(user.id);
    // Redirect về trang /login để Frontend (Login.tsx) bắt được token và xử lý
    res.redirect(`${process.env.CLIENT_URL}/login?token=${token}`);
  } catch (err) {
    console.error('Google Auth Error:', err);
    res.redirect(`${process.env.CLIENT_URL}/login?error=GoogleAuthFailed`);
  }
});

// GitHub Login
router.get('/github', (req, res) => {
  const redirectUri = process.env.GITHUB_CALLBACK_URL;
  const clientId = process.env.GITHUB_CLIENT_ID;
  
  if (!clientId) {
    return res.status(500).send('Server Error: GITHUB_CLIENT_ID is missing');
  }

  const url = `https://github.com/login/oauth/authorize?client_id=${clientId}&redirect_uri=${redirectUri}&scope=user:email`;
  res.redirect(url);
});

// GitHub Callback
router.get('/github/callback', async (req, res) => {
  const { code } = req.query;
  try {
    // Exchange code for token
    const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        client_id: process.env.GITHUB_CLIENT_ID,
        client_secret: process.env.GITHUB_CLIENT_SECRET,
        code
      })
    });
    const tokenData = await tokenRes.json();

    // Get User Info
    const userRes = await fetch('https://api.github.com/user', {
      headers: { Authorization: `Bearer ${tokenData.access_token}` }
    });
    const userData = await userRes.json();

    // Get Email (if private)
    let email = userData.email;
    if (!email) {
      const emailRes = await fetch('https://api.github.com/user/emails', {
        headers: { Authorization: `Bearer ${tokenData.access_token}` }
      });
      const emails = await emailRes.json();
      const primary = emails.find(e => e.primary && e.verified);
      email = primary ? primary.email : null;
    }

    if (!email) throw new Error('No email found from GitHub');

    let user = await User.findOne({ email });
    if (!user) {
      const randomPassword = crypto.randomBytes(16).toString('hex');
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(randomPassword, salt);

      user = new User({
        username: userData.login + Math.floor(Math.random() * 1000), // Thêm số ngẫu nhiên để tránh trùng username
        email: email,
        password: hashedPassword,
        full_name: userData.name || userData.login,
        avatar_url: userData.avatar_url,
        github: userData.html_url,
        bio: userData.bio,
        githubId: userData.id.toString()
      });
      await user.save();
    } else if (!user.githubId) {
      // Nếu user đã tồn tại nhưng chưa có githubId -> Cập nhật thêm
      user.githubId = userData.id.toString();
      await user.save();
    }

    const token = generateToken(user.id);
    // Redirect về trang /login để Frontend (Login.tsx) bắt được token và xử lý
    res.redirect(`${process.env.CLIENT_URL}/login?token=${token}`);
  } catch (err) {
    console.error('GitHub Auth Error:', err);
    res.redirect(`${process.env.CLIENT_URL}/login?error=GitHubAuthFailed`);
  }
});

module.exports = router;
