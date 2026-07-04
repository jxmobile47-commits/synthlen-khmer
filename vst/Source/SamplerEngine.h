#pragma once

#include <JuceHeader.h>

//==============================================================================
// Synthlen Khmer - custom sampler engine
//
// Adds real DSP on top of a basic sampler:
//   * per-voice ADSR envelope (Attack / Decay / Release knobs)
//   * per-voice resonant low-pass filter (Cutoff / Resonance knobs)
//   * pitch ratio playback + global Pitch knob (-12..+12 semitones)
//   * key-zone + velocity-layer sample mapping
//==============================================================================

//------------------------------------------------------------------------------
// Parameter values shared (lock-free) between the processor and every voice.
//------------------------------------------------------------------------------
struct SharedParams
{
    std::atomic<float>* attack    = nullptr;
    std::atomic<float>* decay     = nullptr;
    std::atomic<float>* release    = nullptr;
    std::atomic<float>* cutoff    = nullptr;
    std::atomic<float>* resonance = nullptr;
    std::atomic<float>* pitch     = nullptr;

    // Pitch bend range in semitones (default ±2)
    static constexpr float pitchBendRangeSemitones = 2.0f;

    static float get (std::atomic<float>* p, float fallback) { return p ? p->load() : fallback; }
};

//------------------------------------------------------------------------------
// A sample mapped to a key zone and a velocity layer.
//------------------------------------------------------------------------------
class KhmerSound : public juce::SynthesiserSound
{
public:
    KhmerSound (const juce::String& nameIn,
                juce::AudioFormatReader& reader,
                int rootMidiNote,
                int lowKeyIn, int highKeyIn,
                int lowVelIn, int highVelIn)
        : name (nameIn),
          rootNote (rootMidiNote),
          lowKey (lowKeyIn), highKey (highKeyIn),
          lowVel (lowVelIn), highVel (highVelIn),
          sourceSampleRate (reader.sampleRate)
    {
        length = (int) reader.lengthInSamples;
        if (length > 0 && sourceSampleRate > 0.0)
        {
            data.setSize ((int) reader.numChannels, length + 4, false, false, false);
            reader.read (&data, 0, length + 4, 0, true, true);
        }
    }

    bool appliesToNote    (int midiNote) override { return midiNote >= lowKey && midiNote <= highKey; }
    bool appliesToChannel (int)          override { return true; }
    bool appliesToVelocity (int vel)     const    { return vel >= lowVel && vel <= highVel; }

    const juce::String name;
    juce::AudioBuffer<float> data;
    int   rootNote = 60;
    int   lowKey = 0, highKey = 127;
    int   lowVel = 1, highVel = 127;
    int   length = 0;
    double sourceSampleRate = 44100.0;
};

//------------------------------------------------------------------------------
// Voice: plays a KhmerSound through an ADSR and a resonant low-pass filter.
//------------------------------------------------------------------------------
class KhmerVoice : public juce::SynthesiserVoice
{
public:
    explicit KhmerVoice (const SharedParams* p) : params (p) {}

    bool canPlaySound (juce::SynthesiserSound* s) override
    {
        return dynamic_cast<KhmerSound*> (s) != nullptr;
    }

    void startNote (int midiNoteNumber, float velocity,
                    juce::SynthesiserSound* s, int currentPitchWheel) override
    {
        currentSound = dynamic_cast<KhmerSound*> (s);
        if (currentSound == nullptr)
            return;

        sourceSamplePosition = 0.0;
        // Natural velocity curve: square-root response for more realistic dynamics.
        level = juce::jlimit (0.1f, 1.0f, std::sqrt (velocity));
        noteMidi = midiNoteNumber;

        // Store the pitch wheel position at note-on so bending sounds correct.
        pitchWheelValue = currentPitchWheel;

        prepareFilterIfNeeded();
        filter.reset();

        // Anti-aliasing: simple one-pole LPF state, reset per note.
        aaL = 0.0f; aaR = 0.0f;

        updateAdsrParameters();
        adsr.setSampleRate (getSampleRate());
        adsr.noteOn();
    }

    void stopNote (float /*velocity*/, bool allowTailOff) override
    {
        if (allowTailOff)
        {
            adsr.noteOff();
        }
        else
        {
            adsr.reset();
            clearCurrentNote();
            currentSound = nullptr;
        }
    }

    void pitchWheelMoved (int newValue) override
    {
        pitchWheelValue = newValue;
    }

    void controllerMoved (int controllerNumber, int controllerValue) override
    {
        if (controllerNumber == 1) // Modulation Wheel (CC1)
            modWheelValue = controllerValue;
    }

    void renderNextBlock (juce::AudioBuffer<float>& output,
                          int startSample, int numSamples) override
    {
        if (currentSound == nullptr || currentSound->length <= 0)
            return;

        prepareFilterIfNeeded();
        updateAdsrParameters();
        updateFilterParameters();

        const auto& src = currentSound->data;
        const int   srcChannels = src.getNumChannels();
        const float* inL = src.getReadPointer (0);
        const float* inR = srcChannels > 1 ? src.getReadPointer (1) : inL;

        const double ratio = playbackRatio();
        const int    outChannels = output.getNumChannels();
        const int    fadeSamples = juce::jmin (64, currentSound->length / 4);
        const double aaCoeff = (ratio > 1.0) ? (1.0 / ratio) : 1.0; // anti-alias when pitching up

        while (--numSamples >= 0)
        {
            const int   pos   = (int) sourceSamplePosition;
            const float frac  = (float) (sourceSamplePosition - pos);

            if (pos + 2 >= currentSound->length)
            {
                stopNote (0.0f, false);
                break;
            }

            // Cubic Hermite interpolation for smoother, more natural playback.
            auto hermite = [] (const float* d, int i, float t) -> float
            {
                const float y0 = d[i - 1], y1 = d[i], y2 = d[i + 1], y3 = d[i + 2];
                const float c0 = y1;
                const float c1 = 0.5f * (y2 - y0);
                const float c2 = y0 - 2.5f * y1 + 2.0f * y2 - 0.5f * y3;
                const float c3 = 0.5f * (y3 - y0) + 1.5f * (y1 - y2);
                return c0 + t * (c1 + t * (c2 + t * c3));
            };

            float l = (pos > 0) ? hermite (inL, pos, frac) : inL[pos];
            float r = (pos > 0) ? hermite (inR, pos, frac) : inR[pos];

            // Simple one-pole anti-aliasing filter when pitching up.
            if (aaCoeff < 1.0f)
            {
                aaL += aaCoeff * (l - aaL);
                aaR += aaCoeff * (r - aaR);
                l = aaL; r = aaR;
            }

            // Smooth fade-out near the end of the sample to avoid clicks.
            const int remaining = currentSound->length - pos;
            if (remaining < fadeSamples)
            {
                const float fadeGain = (float) remaining / (float) fadeSamples;
                l *= fadeGain;
                r *= fadeGain;
            }

            const float env = adsr.getNextSample();
            l *= env * level;
            r *= env * level;

            l = filter.processSample (0, l);
            r = filter.processSample (1, r);

            if (outChannels > 0) output.addSample (0, startSample, l);
            if (outChannels > 1) output.addSample (1, startSample, r);

            ++startSample;
            sourceSamplePosition += ratio;

            if (! adsr.isActive())
            {
                clearCurrentNote();
                currentSound = nullptr;
                break;
            }
        }
    }

private:
    double playbackRatio() const
    {
        // semitone offset from the root note + global Pitch knob (-12..+12).
        const float pitchKnob = SharedParams::get (params ? params->pitch : nullptr, 0.5f);
        const double semis = (noteMidi - currentSound->rootNote) + (pitchKnob - 0.5f) * 24.0;

        // Pitch bend: MIDI value 0..16383, center 8192 → ±2 semitones.
        const double bendSemitones =
            ((double) (pitchWheelValue - 8192) / 8192.0) * SharedParams::pitchBendRangeSemitones;

        const double base  = std::pow (2.0, (semis + bendSemitones) / 12.0);
        return base * (currentSound->sourceSampleRate / getSampleRate());
    }

    void updateAdsrParameters()
    {
        juce::ADSR::Parameters p;
        p.attack  = 0.001f + 2.0f * SharedParams::get (params ? params->attack  : nullptr, 0.05f);
        p.decay   = 0.010f + 2.0f * SharedParams::get (params ? params->decay   : nullptr, 0.30f);
        p.sustain = 1.0f; // Full volume during sustain - let the sample's natural decay speak.
        p.release = 0.010f + 3.0f * SharedParams::get (params ? params->release : nullptr, 0.40f);
        adsr.setParameters (p);
    }

    void prepareFilterIfNeeded()
    {
        const double sr = getSampleRate();
        if (sr > 0.0 && sr != preparedSampleRate)
        {
            juce::dsp::ProcessSpec spec;
            spec.sampleRate = sr;
            spec.maximumBlockSize = 512;
            spec.numChannels = 2;
            filter.prepare (spec);
            filter.setType (juce::dsp::StateVariableTPTFilterType::lowpass);
            preparedSampleRate = sr;
        }
    }

    void updateFilterParameters()
    {
        const float cut = SharedParams::get (params ? params->cutoff    : nullptr, 0.7f);
        const float res = SharedParams::get (params ? params->resonance : nullptr, 0.3f);

        // Modulation wheel (CC1) opens the filter cutoff for expressive brightness.
        // 0..127 → up to +0.25 added to the cutoff parameter.
        const float modAdd = (modWheelValue / 127.0f) * 0.25f;

        // 20 Hz .. 20 kHz, exponential.
        const float hz = 20.0f * std::pow (1000.0f, juce::jlimit (0.0f, 1.0f, cut + modAdd));
        const float q  = 0.5f + res * 9.5f; // 0.5 .. 10
        filter.setCutoffFrequency (juce::jlimit (20.0f, 20000.0f, hz));
        filter.setResonance (q);
    }

    const SharedParams* params = nullptr;
    KhmerSound* currentSound = nullptr;

    juce::ADSR adsr;
    juce::dsp::StateVariableTPTFilter<float> filter;
    double preparedSampleRate = 0.0;

    double sourceSamplePosition = 0.0;
    float  level = 1.0f;
    int    noteMidi = 60;
    int    pitchWheelValue = 8192;  // MIDI center = no bend
    int    modWheelValue = 0;       // CC1, 0 = no modulation
    float  aaL = 0.0f, aaR = 0.0f; // anti-aliasing filter state
};

//------------------------------------------------------------------------------
// Synthesiser that picks a single sound matching BOTH note and velocity layer.
//------------------------------------------------------------------------------
class KhmerSynth : public juce::Synthesiser
{
public:
    void noteOn (int midiChannel, int midiNoteNumber, float velocity) override
    {
        const juce::ScopedLock sl (lock);
        const int vel = juce::jlimit (1, 127, (int) std::round (velocity * 127.0f));

        for (int i = 0; i < getNumSounds(); ++i)
        {
            auto* sound = dynamic_cast<KhmerSound*> (getSound (i).get());
            if (sound == nullptr)
                continue;
            if (sound->appliesToNote (midiNoteNumber)
                && sound->appliesToChannel (midiChannel)
                && sound->appliesToVelocity (vel))
            {
                if (auto* voice = findFreeVoice (sound, midiChannel, midiNoteNumber, isNoteStealingEnabled()))
                    startVoice (voice, sound, midiChannel, midiNoteNumber, velocity);
                return; // pick a single matching layer
            }
        }
    }
};
