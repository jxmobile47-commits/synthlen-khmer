# Synthlen Khmer - VST3 Build Guide (C++ / JUCE)

This builds the Khmer instrument UI into a real **VST3 + Standalone** plugin.
The GUI is your existing `synthlen-khmer.html` design, rendered inside a
**WebView** (no design rewrite needed). Audio is a **multi-sample sampler**.

---

## 1. Prerequisites (Windows)

| Tool | Status on your machine | Notes |
|------|------------------------|-------|
| Visual Studio 2022 (Desktop C++ workload) | Installed | Provides MSVC compiler + CMake |
| Git | Installed (2.53) | Used to fetch JUCE |
| CMake >= 3.22 | Bundled with VS 2022 (3.31) | No separate install needed |
| WebView2 SDK | Auto-downloaded by CMake | NuGet package fetched at configure time |
| WebView2 Runtime | Usually preinstalled on Win10/11 | Required to run the WebView GUI |

**CMake** ships inside VS 2022 at:
```
C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe
```
Either use that full path, or open *x64 Native Tools Command Prompt for VS 2022*
(which puts `cmake` on PATH).

> The **Microsoft WebView2 SDK** (provides `WebView2.h`) is downloaded automatically
> by CMake via `FetchContent` (NuGet package), so no manual SDK install is required.

---

## 2. Bundle the web UI

This copies the HTML + uploaded images into `vst/ui/` and writes `manifest.json`.

```powershell
cd "c:\Users\User\Desktop\UI UX Desing\vst"
powershell -ExecutionPolicy Bypass -File .\bundle-ui.ps1
```

Re-run this any time you change the design or images.

---

## 3. Add instrument samples (optional but recommended)

Place `.wav` files in a `Samples` folder. The file name controls mapping:

**Pitch (root note)** - one of:
- note name + octave: `C3.wav`, `A#4.wav`, `roneat_C3.wav`
- trailing MIDI number: `roneat_60.wav` (= MIDI note 60)

**Velocity layers (optional)** - add a `_vNN` suffix giving the layer's TOP velocity:
- `roneat_C3_v60.wav`  -> plays for velocity 1..60
- `roneat_C3_v100.wav` -> plays for velocity 61..100
- `roneat_C3_v127.wav` -> plays for velocity 101..127

**Key zones** are computed automatically: each root note covers the range up to
the midpoint towards its neighbouring samples, so a few samples fill the whole
keyboard. The plugin auto-loads a `Samples` folder placed **next to the built
plugin**. Without samples it loads but stays silent.

The knobs drive real DSP per voice:
- **Attack / Decay / Release** -> ADSR envelope
- **Cutoff / Resonance** -> resonant low-pass filter (20 Hz..20 kHz)
- **Pitch** -> +/-12 semitone playback ratio shift

---

## 4. Configure & build

```powershell
cd "c:\Users\User\Desktop\UI UX Desing\vst"
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

First configure downloads JUCE 8 (a few minutes).

---

## 5. Output

After a successful build:

- **VST3:** `vst\build\SynthlenKhmer_artefacts\Release\VST3\Synthlen Khmer.vst3`
- **Standalone app:** `...\Release\Standalone\Synthlen Khmer.exe`

To install the VST3, copy it into the system folder (needs admin rights):

```powershell
Copy-Item "build\SynthlenKhmer_artefacts\Release\VST3\Synthlen Khmer.vst3" `
          "$env:CommonProgramFiles\VST3\" -Recurse -Force
```

(`COPY_PLUGIN_AFTER_BUILD` is `FALSE` because copying to `Program Files` fails
without admin; set it `TRUE` only when building from an elevated prompt.)
Then load it in any DAW (FL Studio, Ableton, Reaper...), or just run the
Standalone `.exe`.

---

## 6. Project layout

```
vst/
  CMakeLists.txt        JUCE project (FetchContent), binary-data embedding
  bundle-ui.ps1         Copies HTML + images into ui/, writes manifest.json
  ui/                   (generated) embedded web assets
  Source/
    PluginProcessor.*   Sampler engine + parameters + master FX
    PluginEditor.*      WebView that renders the Khmer HTML UI
  BUILD.md              this file
```

---

## 7. GUI <-> audio bindings (implemented)

The web UI and the audio engine are connected via JUCE's WebView relays and a
native function. This works automatically inside the plugin; in a plain browser
the same HTML still runs (the bindings are skipped when `window.__JUCE__` is absent).

- **Knobs -> parameters:** each `.knob` has a `data-param` id
  (`resonance, cutoff, delay, reverb, pitch, attack, decay, release`). The editor
  exposes a `juce::WebSliderRelay` per id and attaches it to the matching APVTS
  parameter with `juce::WebSliderParameterAttachment`. Turning a knob calls
  `window.__onKnob(id, norm)` -> `Juce.getSliderState(id).setNormalisedValue(...)`.
  Host automation flows back and rotates the knob.
- **FX buttons -> parameters:** the 3 MULTI-EFFECT buttons have `data-fx`
  (`fxReverb, fxDelay, fxPitch`), bound through `juce::WebToggleButtonRelay` +
  `WebToggleButtonParameterAttachment`.
- **Piano -> MIDI:** pressing a key calls the native function `pianoNote(isOn, midiNote, vel)`.
  The processor feeds it into a `juce::MidiMessageCollector`, which is drained into
  the MIDI stream each `processBlock`, so the sampler plays the note.

The JUCE frontend JS module is copied into `ui/js/juce` at CMake configure time
and embedded with the rest of the UI. The HTML imports it via
`import('./js/juce/index.js')`.

> Note: re-running `bundle-ui.ps1` wipes `ui/`, so re-run the CMake **configure**
> step afterwards to re-copy the JUCE JS module before building.

## 7b. Presets / sound banks (implemented, bundled)

The PRESET list (Angkor Sunset / Mekong Flow / Royal Ballet / Pine Forest) is a
real **sound-bank switch + knob snapshot**:

- A `preset` `AudioParameterChoice` stores the selection (saved with the session).
- Each preset has its own **bundled** sample set under `banks/<Preset>/*.wav`.
- Clicking a preset calls the `selectPreset` native function -> the processor
  loads that bank from embedded `BankData` and applies the preset's knob snapshot
  (`snapshotFor` in `PluginProcessor.cpp`); the knobs/buttons update automatically.

**Add samples to a bank:**

```powershell
# 1. Drop .wav into banks\Angkor Sunset\  (naming = section 3 rules)
# 2. Flatten for embedding
powershell -ExecutionPolicy Bypass -File .\bundle-banks.ps1
# 3. Re-configure + build (samples get embedded into the plugin)
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

With no samples the banks are empty and the preset still switches the knob
snapshot (silent until you add `.wav`). Tweak snapshot values in `snapshotFor`.

## 8. Next steps / TODO

- [x] **Apply parameters to DSP** - ADSR, resonant low-pass filter, pitch ratio.
- [x] **Sample mapping** - automatic key zones + `_vNN` velocity layers.
- [x] **Preset system** - bundled sound banks + knob snapshots.
- [ ] **Per-instrument routing:** let each instrument image (Roneat/Chayam/Tror/Pin)
  select its own sample set / key split.
- [ ] **macOS/AU:** add `AU` to `FORMATS` and build with Xcode for an Audio Unit.
