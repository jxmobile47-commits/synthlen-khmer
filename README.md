# Synthlen Khmer — VST Plugin UI

## រចនាសម្ព័ន្ធ / Project Structure

```
UI UX Desing/
├── synthlen-khmer.html      # ទំព័រចម្បង (HTML + CSS + JS)
├── server.js                # Node.js server (upload/storage)
├── package.json             # Dependencies (express, multer, cors)
├── uploads/
│   ├── instruments/         # រូបភាព instrument (roneat, chayam, tror, pin)
│   ├── background/          # រូបភាព background
│   └── slideshow/           # រូបភាព slideshow
└── README.md                # ឯកសារនេះ
```

## របៀបដំណើរការ / How to Run

1. **បើក terminal** នៅ folder `UI UX Desing`
2. **ដំណើរការ server:**
   ```bash
   npm install
   node server.js
   ```
3. **បើក browser** ទៅ `http://127.0.0.1:8080/synthlen-khmer.html`

## មុខងារដែលបានបង្កើត / Features Implemented

### UI Layout (Khmer Temple Aesthetic)
- **Header:** SYNTHLEN KHMER + subtitle
- **Left Panel (FILTER):** Resonance, Cutoff knobs + Roneat Ek, Chayam upload zones
- **Center Panel:** Waveform display, presets (Angkor Sunset, Mekong Flow, Royal Ballet, Pine Forest), FX selection
- **Right Panel (ENVELOPE):** Attack, Decay, Release knobs + Tror, Pin upload zones + **Slideshow**
- **Bottom:** **Piano Keyboard 61 keys** (C2-C7)

### Upload Zones (4 Instruments)
- Roneat Ek, Chayam, Tror, Pin
- Click or drag-and-drop to upload
- **Zoom (+/-)** on each image
- **Pan/drag** to reposition images
- **Saved to server disk** (not localStorage)

### Background Upload
- Upload background image with zoom/pan
- Dark overlay for readability
- **Saved to server disk**

### Slideshow
- Upload multiple images
- **Auto-slide** every 3 seconds
- Navigation arrows `<` / `>`
- Dots for manual navigation
- **Zoom (+/-)** per slide (independent)
- **Pan/drag per slide** (independent — doesn't affect other slides)
- **Saved to server disk**

### Piano Keyboard (61 Keys)
- 5 octaves (C2 to C7)
- White + black keys with Khmer gold theme
- **Click/touch to play** — key glows gold
- Horizontal scroll for all 61 keys

### Persistence
- Images → saved to `uploads/` folder on server disk
- Zoom/pan positions → saved in browser localStorage
- Reload page → images and positions restored

## ពណ៌ / Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| Gold | `#d4b872` | Primary text, highlights |
| Light Gold | `#f2db98` | Header glow |
| Dark Gold | `#8a733b` | Subtle borders, shadows |
| Stone | `#1e2420` | Dark backgrounds |
| Stone Mid | `#2f3a33` | Panels, gradients |

## ពុម្ពអក្សរ / Fonts
- **Cinzel** (Google Fonts) — headings, labels

## ជា VST Plugin — ជំហានបន្ទាប់ / Next Steps for VST

To convert this HTML/CSS/JS UI into a real VST plugin, you need:

### 1. VST Framework (C++ / JUCE)
- **JUCE** (recommended): `https://juce.com/`
- Create `AudioProcessor` + `AudioProcessorEditor`
- Load this HTML UI using `juce::WebBrowserComponent` or `juce::WebView2WebBrowserComponent`

### 2. Audio Engine
- Implement `processBlock()` for audio synthesis
- Khmer instrument samples (Roneat, Chayam, Tror, Pin)
- ADSR envelope, filter (resonance, cutoff), effects (delay, reverb)

### 3. Host Communication
- MIDI input from piano keyboard → trigger samples/oscillators
- Parameter automation (knobs → DAW automation)
- Preset management

### 4. Build Targets
- Windows VST3 (`.vst3`)
- macOS VST3 / AU
- Standalone app

### 5. File Structure for VST
```
synthlen-khmer-vst/
├── Source/
│   ├── PluginProcessor.cpp/.h
│   ├── PluginEditor.cpp/.h
│   └── assets/ (HTML, CSS, JS, images)
├── JuceLibraryCode/
├── synthlen-khmer.jucer
└── Builds/
```

## Dependencies

- **Node.js** (for local server during development)
- **npm packages:** express, multer, cors

## Notes

- All image uploads go to `uploads/` folder — **backup this folder** to keep your images
- The UI is designed at **1100×680px** (plugin container size)
- Piano keyboard is **1100px wide** to match plugin width
- `localStorage` only stores zoom/pan positions, not images (images are on disk)

---

## Download / ទាញយកកម្មវិធី

### Windows Installer (bundled with sound banks)
- **Part 1:** https://drive.google.com/file/d/1RMRuVSP2O-r1K_RSvswuc2NTWGFrRTMZ/view?usp=sharing
- **Part 2:** https://drive.google.com/file/d/1uQMq0ASgX0cKGcyaO1xNUhIvm0G0WP9F/view?usp=sharing

**របៀប install:**
1. Download Part 1 + Part 2
2. បញ្ចូលគ្នា: `copy /b SynthlenKhmer-Setup-1.0.0.exe.part1 + SynthlenKhmer-Setup-1.0.0.exe.part2 SynthlenKhmer-Setup-1.0.0.exe`
3. Double-click `SynthlenKhmer-Setup-1.0.0.exe` → install រួចរាល់
4. Bank ភ្ជាប់ជាមួយកម្មវិធី — មិនត្រូវការ download ដាច់ដោយឡែយទេ

### macOS Installer
- **Download:** https://drive.google.com/file/d/129tOwhkne66gYk5QB8wWn4c4Xg39x_zA/view?usp=sharing

**របៀប install:**
1. Download `SynthlenKhmer-macOS-Installer.zip`
2. Extract រួច double-click `.pkg` → install រួចរាល់
3. Bank ភ្ជាប់ក្នុង `.app` ផ្ទាល់ — មិនត្រូវការ download ដាច់ដោយឡែយទេ

---

**Created:** June 15, 2026
