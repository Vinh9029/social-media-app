# Sử dụng Node.js phiên bản nhẹ (Alpine Linux)
FROM node:18-alpine

# Thiết lập thư mục làm việc trong container
WORKDIR /app

# Copy file package.json và package-lock.json trước (để tận dụng cache của Docker)
COPY package*.json ./

# Cài đặt các thư viện (dependencies)
RUN npm install

# Copy toàn bộ mã nguồn backend vào container
COPY . .

# Mở port 5000 (Port mà server.js đang lắng nghe)
EXPOSE 5000

# Lệnh chạy server
CMD ["npm", "start"]