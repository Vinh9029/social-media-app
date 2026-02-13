// Generate a random avatar background color and letter if user has no avatar
const COLORS = [
  '#F44336', '#E91E63', '#9C27B0', '#3F51B5', '#2196F3', '#009688', '#4CAF50', '#FF9800', '#795548', '#607D8B'
];

function getRandomColor(name) {
  if (!name) return COLORS[0];
  let sum = 0;
  for (let i = 0; i < name.length; i++) sum += name.charCodeAt(i);
  return COLORS[sum % COLORS.length];
}

function getAvatarFallback(user) {
  if (user.avatar_url) return user.avatar_url;
  const color = getRandomColor(user.full_name || user.username || 'U');
  const letter = (user.full_name || user.username || 'U')[0].toUpperCase();
  // Return a data URL SVG
  return `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80'><rect width='100%' height='100%' fill='${color}'/><text x='50%' y='55%' font-size='40' text-anchor='middle' fill='white' font-family='Arial' dy='.3em'>${letter}</text></svg>`;
}

module.exports = { getAvatarFallback };
