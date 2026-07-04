#include "PluginProcessor.h"
#include "PluginEditor.h"

#include <algorithm>
#include <vector>

#if __has_include("BankData.h")
 #include "BankData.h"
 #define HAS_BANKS 1
#else
 #define HAS_BANKS 0
#endif

//==============================================================================
namespace
{
    struct ParsedSample
    {
        int root = 60;   // MIDI root note
        int velHi = 127; // top velocity of this layer (1..127), default = full range
    };

    // Parse the top velocity of a layer from a "_vNN" suffix, e.g. "C3_v80".
    int parseVelocityTop (const juce::String& base)
    {
        auto idx = base.lastIndexOf ("_V");
        if (idx < 0) idx = base.lastIndexOf ("_v");
        if (idx >= 0)
        {
            auto rest = base.substring (idx + 2);
            if (rest.isNotEmpty() && rest.containsOnly ("0123456789"))
                return juce::jlimit (1, 127, rest.getIntValue());
        }
        return 127;
    }

    // Find the last note-name pattern (C3, A#4, B-1, etc.) in a string.
    int parseNoteName (const juce::String& s)
    {
        static const char* names[] = { "C", "C#", "D", "D#", "E", "F",
                                       "F#", "G", "G#", "A", "A#", "B" };
        juce::String upper = s.toUpperCase();
        int bestRoot = -1;

        for (int pos = 0; pos < upper.length(); )
        {
            for (int i = 11; i >= 0; --i) // check sharps first (longer match)
            {
                juce::String n (names[i]);
                if (upper.substring (pos).startsWith (n))
                {
                    int after = pos + n.length();
                    // Optional minus or digits after the note name.
                    if (after < upper.length()
                        && (upper[after] == '-' || juce::CharacterFunctions::isDigit (upper[after])))
                    {
                        int numStart = after;
                        if (upper[after] == '-') ++after;
                        while (after < upper.length() && juce::CharacterFunctions::isDigit (upper[after]))
                            ++after;
                        int octave = upper.substring (numStart, after).getIntValue();
                        bestRoot = juce::jlimit (0, 127, (octave + 1) * 12 + i);
                        pos = after; // continue scanning; last match wins
                        break;
                    }
                }
            }
            if (pos < upper.length())
                ++pos;
        }
        return bestRoot;
    }

    // Map a sample file name like "C3.wav" / "roneat_60.wav" / "TA khe D1 01 C3.wav".
    ParsedSample parseSampleName (const juce::String& name, int fallbackNote)
    {
        ParsedSample out;
        out.root = fallbackNote;

        auto base = name.upToLastOccurrenceOf (".", false, false).toUpperCase();
        out.velHi = parseVelocityTop (base);

        // Strip the velocity tag before looking for the note.
        auto vIdx = base.lastIndexOf ("_V");
        auto notePart = vIdx >= 0 ? base.substring (0, vIdx) : base;

        // 1) note name like C3, A#4 anywhere in the filename (last match wins).
        int noteRoot = parseNoteName (notePart);
        if (noteRoot >= 0)
        {
            out.root = noteRoot;
            return out;
        }

        // 2) trailing number = direct MIDI note, e.g. "roneat_60"
        auto digits = notePart.fromLastOccurrenceOf ("_", false, false);
        if (digits.isNotEmpty() && digits.containsOnly ("0123456789"))
        {
            out.root = juce::jlimit (0, 127, digits.getIntValue());
            return out;
        }

        return out;
    }
}

//==============================================================================
SynthlenKhmerProcessor::SynthlenKhmerProcessor()
    : AudioProcessor (BusesProperties()
                          .withOutput ("Main", juce::AudioChannelSet::stereo(), true)
                          .withOutput ("AUX 1",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 2",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 3",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 4",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 5",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 6",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 7",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 8",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 9",  juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 10", juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 11", juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 12", juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 13", juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 14", juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 15", juce::AudioChannelSet::stereo(), false)
                          .withOutput ("AUX 16", juce::AudioChannelSet::stereo(), false)),
      apvts (*this, nullptr, "PARAMS", createParameterLayout())
{
    formatManager.registerBasicFormats();

    // Hook the shared (lock-free) parameter pointers used by the voices.
    sharedParams.attack    = apvts.getRawParameterValue ("attack");
    sharedParams.decay     = apvts.getRawParameterValue ("decay");
    sharedParams.release   = apvts.getRawParameterValue ("release");
    sharedParams.cutoff    = apvts.getRawParameterValue ("cutoff");
    sharedParams.resonance = apvts.getRawParameterValue ("resonance");
    sharedParams.pitch     = apvts.getRawParameterValue ("pitch");

    // Plenty of voices for polyphonic playing.
    for (int i = 0; i < 16; ++i)
        synth.addVoice (new KhmerVoice (&sharedParams));

    // Load the initial preset (bundled bank + knob snapshot).
    selectPreset (getPresetNames()[0]);

    // An external "Samples" folder next to the plugin overrides the bundled bank.
    auto exeDir = juce::File::getSpecialLocation (juce::File::currentExecutableFile)
                      .getParentDirectory();
    auto samples = exeDir.getChildFile ("Samples");
    if (samples.isDirectory())
        loadSamplesFromFolder (samples);
}

SynthlenKhmerProcessor::~SynthlenKhmerProcessor() = default;

//==============================================================================
juce::AudioProcessorValueTreeState::ParameterLayout
SynthlenKhmerProcessor::createParameterLayout()
{
    using P = juce::AudioParameterFloat;
    using B = juce::AudioParameterBool;
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;

    auto norm = [] (const juce::String& id, const juce::String& name, float def)
    { return std::make_unique<P> (juce::ParameterID { id, 1 },
                                  name, juce::NormalisableRange<float> (0.0f, 1.0f), def); };

    // FILTER section
    params.push_back (norm ("resonance", "Resonance", 0.3f));
    params.push_back (norm ("cutoff",    "Cutoff",    0.7f));
    // FX knobs
    params.push_back (norm ("delay",     "Delay",     0.2f));
    params.push_back (norm ("reverb",    "Reverb",    0.25f));
    params.push_back (norm ("pitch",     "Pitch",     0.5f)); // 0.5 = no shift
    // MASTER volume
    params.push_back (norm ("master",    "Master",    0.8f));
    // ENVELOPE
    params.push_back (norm ("attack",    "Attack",    0.05f));
    params.push_back (norm ("decay",     "Decay",     0.3f));
    params.push_back (norm ("release",   "Release",   0.4f));
    // FX enable toggles (the 3 buttons)
    params.push_back (std::make_unique<B> (juce::ParameterID { "fxReverb", 1 }, "FX Reverb", false));
    params.push_back (std::make_unique<B> (juce::ParameterID { "fxDelay",  1 }, "FX Delay",  false));
    params.push_back (std::make_unique<B> (juce::ParameterID { "fxPitch",  1 }, "FX Pitch",  false));

    // PRESET selector (sound bank).
    auto presetNames = getPresetNames();
    if (presetNames.isEmpty())
        presetNames.add ("Default");
    params.push_back (std::make_unique<juce::AudioParameterChoice> (
        juce::ParameterID { "preset", 1 }, "Preset", presetNames, 0));

    // AUX output routing: 0 = Main only, 1-16 = also send to AUX N.
    juce::StringArray auxChoices;
    auxChoices.add ("Main Only");
    for (int i = 1; i <= 16; ++i)
        auxChoices.add ("AUX " + juce::String (i));
    params.push_back (std::make_unique<juce::AudioParameterChoice> (
        juce::ParameterID { "auxOut", 1 }, "AUX Output", auxChoices, 0));

    return { params.begin(), params.end() };
}

//==============================================================================
static juce::File findBanksRoot()
{
    auto exeDir = juce::File::getSpecialLocation (juce::File::currentExecutableFile).getParentDirectory();
    auto local = exeDir.getChildFile ("banks");
    if (local.isDirectory())
        return local;

    return juce::File::getSpecialLocation (juce::File::userDocumentsDirectory)
               .getChildFile ("Synthlen Khmer").getChildFile ("banks");
}

//==============================================================================
// Encrypted bank pack (SynthlenKhmer.banks) - single file containing all
// samples, XOR-encrypted so users cannot extract the .wav files.
namespace
{
    constexpr const char* kPackKey = "SynKh2024_BankPack_Secret!";

    struct BankPack
    {
        struct Entry { juce::String preset, fileName; juce::int64 offset = 0, size = 0; };
        juce::File file;
        std::vector<Entry> entries;
        bool loaded = false;
    };

    juce::File findPackFile()
    {
        auto exeDir = juce::File::getSpecialLocation (juce::File::currentExecutableFile).getParentDirectory();
        const juce::File candidates[] = {
            exeDir.getChildFile ("SynthlenKhmer.banks"),
            exeDir.getParentDirectory().getChildFile ("SynthlenKhmer.banks"),
            juce::File::getSpecialLocation (juce::File::userDocumentsDirectory)
                .getChildFile ("Synthlen Khmer").getChildFile ("SynthlenKhmer.banks")
        };
        for (auto& f : candidates)
            if (f.existsAsFile())
                return f;
        return {};
    }

    BankPack& getBankPack()
    {
        static BankPack pack;
        if (! pack.loaded)
        {
            pack.loaded = true;
            pack.file = findPackFile();
            if (pack.file.existsAsFile())
            {
                juce::FileInputStream in (pack.file);
                char magic[8] = {};
                if (in.openedOk() && in.read (magic, 8) == 8
                    && memcmp (magic, "SYNKB1\0\0", 8) == 0)
                {
                    const int num = in.readInt();
                    for (int i = 0; i < num && ! in.isExhausted(); ++i)
                    {
                        const int nameLen = in.readInt();
                        if (nameLen <= 0 || nameLen > 4096) break;
                        juce::HeapBlock<char> nameBuf ((size_t) nameLen);
                        in.read (nameBuf.getData(), nameLen);
                        auto full = juce::String::fromUTF8 (nameBuf.getData(), nameLen);

                        BankPack::Entry e;
                        e.preset   = full.upToFirstOccurrenceOf ("/", false, false);
                        e.fileName = full.fromFirstOccurrenceOf ("/", false, false);
                        e.offset   = in.readInt64();
                        e.size     = in.readInt64();
                        pack.entries.push_back (std::move (e));
                    }
                }
            }
        }
        return pack;
    }

    void xorDecrypt (void* data, size_t size)
    {
        const auto* key = (const unsigned char*) kPackKey;
        const size_t keyLen = strlen (kPackKey);
        auto* p = (unsigned char*) data;
        for (size_t i = 0; i < size; ++i)
            p[i] ^= key[i % keyLen];
    }
}

juce::StringArray SynthlenKhmerProcessor::getPresetNames()
{
    juce::StringArray names;

    // Prefer the encrypted bank pack.
    auto& pack = getBankPack();
    if (! pack.entries.empty())
    {
        for (auto& e : pack.entries)
            names.addIfNotAlreadyThere (e.preset);
        names.sortNatural();
        return names;
    }

    for (auto& d : findBanksRoot().findChildFiles (juce::File::findDirectories, false))
        names.add (d.getFileName());
    names.sortNatural();
    return names;
}

SynthlenKhmerProcessor::PresetSnapshot
SynthlenKhmerProcessor::snapshotFor (const juce::String& name)
{
    // resonance,cutoff,delay,reverb,pitch,attack,decay,release, fxRev,fxDel,fxPit
    // Neutral, raw-sample sound: no FX, filter wide open, minimal ADSR colour.

    // Quiet sample banks -> boost gain.
    if (name == "Russey Khyal") return { 0.0f, 1.0f, 0.0f, 0.0f, 0.5f, 0.0f, 0.0f, 0.05f, false, false, false, 6.0f };
    if (name == "Pei Bampe")    return { 0.0f, 1.0f, 0.0f, 0.0f, 0.5f, 0.0f, 0.0f, 0.05f, false, false, false, 6.0f };

    return { 0.0f, 1.0f, 0.0f, 0.0f, 0.5f, 0.0f, 0.0f, 0.05f, false, false, false, 1.0f };
}

//==============================================================================
void SynthlenKhmerProcessor::buildSounds (std::vector<SampleEntry>& entries)
{
    synth.clearSounds();
    loadedSampleNames.clear();

    // --- distinct root notes -> key zones ------------------------------------
    std::vector<int> roots;
    for (auto& e : entries)
        if (std::find (roots.begin(), roots.end(), e.root) == roots.end())
            roots.push_back (e.root);
    std::sort (roots.begin(), roots.end());

    auto keyZoneFor = [&] (int root, int& lowKey, int& highKey)
    {
        auto it = std::find (roots.begin(), roots.end(), root);
        int idx = (int) std::distance (roots.begin(), it);
        int prev = idx > 0 ? roots[idx - 1] : -1;
        int next = idx < (int) roots.size() - 1 ? roots[idx + 1] : 128;
        // Kontakt-style: first zone stretches to key 0, last zone to key 127.
        lowKey  = prev < 0 ? 0   : (prev + root) / 2 + 1;
        highKey = next > 127 ? 127 : (root + next) / 2;
        // Ensure no gaps: clamp to valid range.
        lowKey  = juce::jlimit (0, 127, lowKey);
        highKey = juce::jlimit (0, 127, highKey);
    };

    // --- velocity layers: per root, sort by velHi and chain the ranges -------
    auto velRangeFor = [&] (int root, int velHi, int& lowVel, int& highVel)
    {
        std::vector<int> tops;
        for (auto& e : entries)
            if (e.root == root)
                tops.push_back (e.velHi);
        std::sort (tops.begin(), tops.end());
        int prevTop = 0;
        for (int t : tops)
        {
            if (t == velHi) { lowVel = prevTop + 1; highVel = t; return; }
            prevTop = t;
        }
        lowVel = 1; highVel = 127;
    };

    // --- create sounds -------------------------------------------------------
    for (auto& e : entries)
    {
        if (e.reader == nullptr)
            continue;

        int lowKey, highKey, lowVel, highVel;
        keyZoneFor (e.root, lowKey, highKey);
        velRangeFor (e.root, e.velHi, lowVel, highVel);

        synth.addSound (new KhmerSound (e.name, *e.reader, e.root,
                                        lowKey, highKey, lowVel, highVel));
        loadedSampleNames.add (e.name);
    }
}

//==============================================================================
void SynthlenKhmerProcessor::loadSamplesFromFolder (const juce::File& folder)
{
    auto files = folder.findChildFiles (juce::File::findFiles, false, "*.wav;*.aif;*.aiff;*.flac");
    files.sort();

    std::vector<SampleEntry> entries;
    const int n = files.size();
    for (int i = 0; i < n; ++i)
    {
        // Kontakt-style: spread samples across the full 88-key piano range (A0=21..C8=108).
        int fallback = n > 1 ? 21 + (i * 87) / (n - 1) : 60;
        auto parsed = parseSampleName (files[i].getFileName(), fallback);

        SampleEntry e;
        e.name  = files[i].getFileNameWithoutExtension();
        e.root  = parsed.root;
        e.velHi = parsed.velHi;
        e.reader.reset (formatManager.createReaderFor (files[i]));
        if (e.reader != nullptr)
            entries.push_back (std::move (e));
    }

    buildSounds (entries);
}

//==============================================================================
void SynthlenKhmerProcessor::loadBankSamples (const juce::String& presetName)
{
    std::vector<SampleEntry> entries;

    // --- 1) Encrypted bank pack (SynthlenKhmer.banks) ------------------------
    {
        auto& pack = getBankPack();
        if (! pack.entries.empty())
        {
            std::vector<const BankPack::Entry*> matching;
            for (auto& e : pack.entries)
                if (e.preset == presetName)
                    matching.push_back (&e);

            std::sort (matching.begin(), matching.end(),
                       [] (const BankPack::Entry* a, const BankPack::Entry* b)
                       { return a->fileName.compareNatural (b->fileName) < 0; });

            juce::FileInputStream in (pack.file);
            if (in.openedOk())
            {
                const int n = (int) matching.size();
                for (int i = 0; i < n; ++i)
                {
                    const auto* m = matching[(size_t) i];
                    if (! in.setPosition (m->offset))
                        continue;

                    juce::MemoryBlock data ((size_t) m->size);
                    if (in.read (data.getData(), (int) m->size) != (int) m->size)
                        continue;

                    xorDecrypt (data.getData(), (size_t) m->size);

                    int fallback = n > 1 ? 21 + (i * 87) / (n - 1) : 60;
                    auto parsed = parseSampleName (m->fileName, fallback);

                    SampleEntry e;
                    e.name  = m->fileName.upToLastOccurrenceOf (".", false, false);
                    e.root  = parsed.root;
                    e.velHi = parsed.velHi;

                    auto stream = std::make_unique<juce::MemoryInputStream> (data, true);
                    e.reader.reset (formatManager.createReaderFor (std::move (stream)));
                    if (e.reader != nullptr)
                        entries.push_back (std::move (e));
                }
            }
        }
    }

    // --- 2) Disk fallback (Documents\Synthlen Khmer\banks\<Preset>) ----------
    if (entries.empty())
    {
        auto folder = findBanksRoot().getChildFile (presetName);
        if (folder.isDirectory())
        {
            auto files = folder.findChildFiles (juce::File::findFiles, true, "*.wav;*.aif;*.aiff;*.flac");
            files.sort();

            const int n = files.size();
            for (int i = 0; i < n; ++i)
            {
                int fallback = n > 1 ? 21 + (i * 87) / (n - 1) : 60;
                auto parsed = parseSampleName (files[i].getFileName(), fallback);

                SampleEntry e;
                e.name  = files[i].getFileNameWithoutExtension();
                e.root  = parsed.root;
                e.velHi = parsed.velHi;
                e.reader.reset (formatManager.createReaderFor (files[i]));
                if (e.reader != nullptr)
                    entries.push_back (std::move (e));
            }
        }
    }

    buildSounds (entries);
}

//==============================================================================
void SynthlenKhmerProcessor::applySnapshot (const PresetSnapshot& s)
{
    auto setF = [this] (const char* id, float v)
    { if (auto* p = apvts.getParameter (id)) p->setValueNotifyingHost (juce::jlimit (0.0f, 1.0f, v)); };
    auto setB = [this] (const char* id, bool v)
    { if (auto* p = apvts.getParameter (id)) p->setValueNotifyingHost (v ? 1.0f : 0.0f); };

    setF ("resonance", s.resonance); setF ("cutoff",  s.cutoff);
    setF ("delay",     s.delay);     setF ("reverb",  s.reverb);
    setF ("pitch",     s.pitch);     setF ("attack",  s.attack);
    setF ("decay",     s.decay);     setF ("release", s.release);
    setB ("fxReverb",  s.fxReverb);  setB ("fxDelay", s.fxDelay);
    setB ("fxPitch",   s.fxPitch);
    currentPresetGain = s.gain;
}

//==============================================================================
void SynthlenKhmerProcessor::selectPreset (const juce::String& presetName)
{
    const int index = juce::jmax (0, getPresetNames().indexOf (presetName));

    // Reflect the choice in the parameter (for host save/automation display).
    if (auto* p = apvts.getParameter ("preset"))
    {
        const int num = getPresetNames().size();
        p->setValueNotifyingHost (num > 1 ? (float) index / (float) (num - 1) : 0.0f);
    }

    loadBankSamples (presetName);
    applySnapshot (snapshotFor (presetName));
}

//==============================================================================
void SynthlenKhmerProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;
    synth.setCurrentPlaybackSampleRate (sampleRate);
    midiCollector.reset (sampleRate);

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = (juce::uint32) samplesPerBlock;
    spec.numChannels = 2;

    reverb.prepare (spec);
    delayLine.prepare (spec);
    delayLine.setMaximumDelayInSamples ((int) (sampleRate * 1.0));
}

void SynthlenKhmerProcessor::releaseResources() {}

bool SynthlenKhmerProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    const int numOuts = layouts.outputBuses.size();
    if (numOuts < 1)
        return false;

    // Main output must be stereo.
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    // All AUX buses (if enabled) must be stereo.
    for (int i = 1; i < numOuts; ++i)
    {
        const auto& set = layouts.outputBuses[i];
        if (set != juce::AudioChannelSet::stereo() && ! set.isDisabled())
            return false;
    }

    return true;
}

//==============================================================================
void SynthlenKhmerProcessor::applyFxParameters()
{
    juce::dsp::Reverb::Parameters rp;
    rp.roomSize = apvts.getRawParameterValue ("reverb")->load();
    rp.wetLevel = apvts.getParameterAsValue ("fxReverb").getValue() ? 0.4f : 0.0f;
    rp.dryLevel = 1.0f;
    reverb.setParameters (rp);
}

void SynthlenKhmerProcessor::processBlock (juce::AudioBuffer<float>& buffer,
                                           juce::MidiBuffer& midi)
{
    juce::ScopedNoDenormals noDenormals;

    // Get all output buses.
    auto buses = getBusCount (false);
    auto mainBuffer = getBusBuffer (buffer, false, 0);

    // Clear all buses.
    for (int bus = 0; bus < buses; ++bus)
        getBusBuffer (buffer, false, bus).clear();

    // Merge notes coming from the on-screen piano (GUI) into the MIDI stream.
    midiCollector.removeNextBlockOfMessages (midi, mainBuffer.getNumSamples());

    // Render the sampler into the main bus.
    synth.renderNextBlock (mainBuffer, midi, 0, mainBuffer.getNumSamples());

    // Apply per-preset gain boost (e.g. for quieter sample sets).
    if (currentPresetGain != 1.0f)
        mainBuffer.applyGain (currentPresetGain);

    // Master volume (user-controlled output level, 0..3x boost).
    if (auto* masterParam = apvts.getRawParameterValue ("master"))
    {
        const float masterGain = masterParam->load() * 3.0f;
        mainBuffer.applyGain (masterGain);
    }

    juce::dsp::AudioBlock<float> block (mainBuffer);
    juce::dsp::ProcessContextReplacing<float> ctx (block);

    // Delay (if enabled)
    if (apvts.getParameterAsValue ("fxDelay").getValue())
    {
        float amt = apvts.getRawParameterValue ("delay")->load();
        int delaySamples = (int) (currentSampleRate * (0.05 + 0.45 * amt));
        delayLine.setDelay ((float) delaySamples);
        for (int ch = 0; ch < mainBuffer.getNumChannels(); ++ch)
        {
            auto* d = mainBuffer.getWritePointer (ch);
            for (int s = 0; s < mainBuffer.getNumSamples(); ++s)
            {
                float in = d[s];
                float dl = delayLine.popSample (ch);
                delayLine.pushSample (ch, in + dl * 0.45f);
                d[s] = in + dl * 0.35f;
            }
        }
    }

    // Reverb (if enabled)
    applyFxParameters();
    if (apvts.getParameterAsValue ("fxReverb").getValue())
        reverb.process (ctx);

    // Copy main output to the selected AUX bus (if any).
    if (auto* auxParam = apvts.getRawParameterValue ("auxOut"))
    {
        const int auxIdx = (int) std::round (auxParam->load() * 15.0f); // 0=Main Only, 1..16=AUX 1..16
        if (auxIdx >= 1 && auxIdx <= 16 && auxIdx < buses)
        {
            auto auxBuffer = getBusBuffer (buffer, false, auxIdx);
            const int numCh = juce::jmin (mainBuffer.getNumChannels(), auxBuffer.getNumChannels());
            for (int ch = 0; ch < numCh; ++ch)
                auxBuffer.copyFrom (ch, 0, mainBuffer, ch, 0, mainBuffer.getNumSamples());
        }
    }
}

//==============================================================================
void SynthlenKhmerProcessor::addMidiNote (bool isNoteOn, int midiNote, float velocity)
{
    midiNote = juce::jlimit (0, 127, midiNote);
    auto msg = isNoteOn
                 ? juce::MidiMessage::noteOn  (1, midiNote, (juce::uint8) juce::jlimit (1, 127, (int) (velocity * 127.0f)))
                 : juce::MidiMessage::noteOff (1, midiNote);
    msg.setTimeStamp (juce::Time::getMillisecondCounterHiRes() * 0.001);
    midiCollector.addMessageToQueue (msg);
}

void SynthlenKhmerProcessor::addPitchBend (int value)
{
    value = juce::jlimit (0, 16383, value);
    auto msg = juce::MidiMessage::pitchWheel (1, value);
    msg.setTimeStamp (juce::Time::getMillisecondCounterHiRes() * 0.001);
    midiCollector.addMessageToQueue (msg);
}

void SynthlenKhmerProcessor::addModWheel (int value)
{
    value = juce::jlimit (0, 127, value);
    auto msg = juce::MidiMessage::controllerEvent (1, 1, value); // CC1 = Modulation
    msg.setTimeStamp (juce::Time::getMillisecondCounterHiRes() * 0.001);
    midiCollector.addMessageToQueue (msg);
}

//==============================================================================
juce::AudioProcessorEditor* SynthlenKhmerProcessor::createEditor()
{
    return new SynthlenKhmerEditor (*this);
}

//==============================================================================
void SynthlenKhmerProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    if (auto state = apvts.copyState(); state.isValid())
    {
        juce::MemoryOutputStream mos (destData, true);
        state.writeToStream (mos);
    }
}

void SynthlenKhmerProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    auto tree = juce::ValueTree::readFromData (data, (size_t) sizeInBytes);
    if (! tree.isValid())
        return;

    apvts.replaceState (tree);

    // Reload the bundled bank for the restored preset, but keep the saved
    // knob values (do NOT re-apply the snapshot).
    if (auto* p = apvts.getParameter ("preset"))
    {
        const int idx = (int) std::round (p->getValue() * (getPresetNames().size() - 1));
        loadBankSamples (getPresetNames()[juce::jlimit (0, getPresetNames().size() - 1, idx)]);
    }
}

//==============================================================================
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new SynthlenKhmerProcessor();
}
