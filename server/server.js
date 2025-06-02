const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Create uploads folder if it doesn't exist
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

// Multer setup
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ storage: storage });

// Upload route
app.post('/upload', upload.single('image'), (req, res) => {
  console.log('Incoming upload request...');

  if (!req.file) {
    console.log('❌ No file uploaded');
    return res.status(400).json({ error: 'No file uploaded' });
  }

  const imageUrl = `http://${req.get('host')}/uploads/${req.file.filename}`;
  console.log('✅ File uploaded:', req.file.filename);

  res.json({ imageUrl });
});


// Health check
app.get('/', (req, res) => {
  res.send('🚀 Server is running...');
});

// Start server
app.listen(PORT, () => {
  console.log(`Server listening at http://localhost:${PORT}`);
});
