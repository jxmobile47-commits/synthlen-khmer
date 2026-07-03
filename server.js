const express = require('express');
const multer = require('multer');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 8080;

// CORS for local development
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Ensure uploads directories exist
const uploadDirs = {
  instruments: path.join(__dirname, 'uploads', 'instruments'),
  background: path.join(__dirname, 'uploads', 'background'),
  slideshow: path.join(__dirname, 'uploads', 'slideshow')
};

Object.values(uploadDirs).forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Multer storage for instruments
const instrumentStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDirs.instruments);
  },
  filename: (req, file, cb) => {
    const target = req.params.target || 'unknown';
    const ext = path.extname(file.originalname) || '.png';
    cb(null, target + ext);
  }
});

const uploadInstrument = multer({ storage: instrumentStorage }).single('image');

// Multer storage for background
const bgStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDirs.background);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.png';
    cb(null, 'background' + ext);
  }
});

const uploadBg = multer({ storage: bgStorage }).single('image');

// Multer storage for slideshow
const slideStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDirs.slideshow);
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const ext = path.extname(file.originalname) || '.png';
    cb(null, 'slide_' + timestamp + '_' + Math.random().toString(36).slice(2, 8) + ext);
  }
});

const uploadSlide = multer({ storage: slideStorage }).array('images', 50);

// ===== API Routes =====

// Upload instrument image
app.post('/api/upload/:target', (req, res) => {
  uploadInstrument(req, res, (err) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    res.json({ 
      success: true, 
      url: '/uploads/instruments/' + req.file.filename,
      target: req.params.target
    });
  });
});

// Upload background
app.post('/api/upload-bg', (req, res) => {
  // Delete old background first
  fs.readdir(uploadDirs.background, (err, files) => {
    if (!err && files.length > 0) {
      files.forEach(f => fs.unlinkSync(path.join(uploadDirs.background, f)));
    }
    uploadBg(req, res, (err) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
      res.json({ 
        success: true, 
        url: '/uploads/background/' + req.file.filename
      });
    });
  });
});

// Upload slideshow images
app.post('/api/upload-slides', (req, res) => {
  uploadSlide(req, res, (err) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!req.files || req.files.length === 0) return res.status(400).json({ error: 'No files uploaded' });
    const urls = req.files.map(f => '/uploads/slideshow/' + f.filename);
    res.json({ success: true, urls });
  });
});

// Get manifest of all saved images
app.get('/api/manifest', (req, res) => {
  const manifest = {
    instruments: {},
    background: null,
    slideshow: []
  };

  // Instruments
  ['roneat', 'chayam', 'tror', 'pin'].forEach(target => {
    const files = fs.readdirSync(uploadDirs.instruments).filter(f => f.startsWith(target + '.'));
    if (files.length > 0) {
      manifest.instruments[target] = '/uploads/instruments/' + files[0];
    }
  });

  // Background
  const bgFiles = fs.readdirSync(uploadDirs.background);
  if (bgFiles.length > 0) {
    manifest.background = '/uploads/background/' + bgFiles[0];
  }

  // Slideshow
  const slideFiles = fs.readdirSync(uploadDirs.slideshow).sort();
  manifest.slideshow = slideFiles.map(f => '/uploads/slideshow/' + f);

  res.json(manifest);
});

// Delete slideshow image
app.delete('/api/slide/:filename', (req, res) => {
  const filePath = path.join(uploadDirs.slideshow, req.params.filename);
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    res.json({ success: true });
  } else {
    res.status(404).json({ error: 'File not found' });
  }
});

// Clear all slideshow images
app.delete('/api/slides', (req, res) => {
  fs.readdir(uploadDirs.slideshow, (err, files) => {
    if (err) return res.status(500).json({ error: err.message });
    files.forEach(f => fs.unlinkSync(path.join(uploadDirs.slideshow, f)));
    res.json({ success: true });
  });
});

// Serve uploads statically (cached for 1 day to speed up repeat loads)
app.use('/uploads', express.static(path.join(__dirname, 'uploads'), { maxAge: '1d' }));

// Root shows the main Khmer design (not the old index.html prototype)
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'synthlen-khmer.html'));
});

// Serve the HTML file and other static files
app.use(express.static(__dirname));

app.listen(PORT, '127.0.0.1', () => {
  console.log('Synthlen Khmer server running at http://127.0.0.1:' + PORT);
  console.log('Open: http://127.0.0.1:' + PORT + '/synthlen-khmer.html');
});
