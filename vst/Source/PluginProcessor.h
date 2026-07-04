#pragma once

#include <JuceHeader.h>
#include "SamplerEngine.h"

//==============================================================================
// Synthlen Khmer - Traditional Khmer Instrument Sampler
//
// A multi-sampled instrument plugin. Drop .wav files into a "Samples" folder
// (next to the plugin or chosen by the user) and they are mapped across the
// keyboard. The GUI is a WebView rendering the existing Khmer HTML design.
//==============================================================================
class SynthlenKhmerProcessor : public juce::AudioProcessor
{
public:
    SynthlenKhmerProcessor();
    ~SynthlenKhmerProcessor() override;

    //==========================================================================
    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    //==========================================================================
    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    const juce::String getName() const override { return "Synthlen Khmer"; }
    bool acceptsMidi() const override  { return true; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram (int) override {}
    const juce::String getProgramName (int) override { return {}; }
    void changeProgramName (int, const juce::String&) override {}

    //==========================================================================
    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    //==========================================================================
    // Public parameter tree, shared with the editor (knobs / fx buttons).
    juce::AudioProcessorValueTreeState apvts;

    // Loads every .wav inside a folder and maps them across the keyboard.
    void loadSamplesFromFolder (const juce::File& folder);
    juce::StringArray getLoadedSampleNames() const { return loadedSampleNames; }

    // Called from the GUI (on-screen piano) to inject a MIDI note.
    void addMidiNote (bool isNoteOn, int midiNote, float velocity);

    // ----- Preset / sound-bank API ------------------------------------------
    static juce::StringArray getPresetNames();
    // Loads the bundled sound bank for a preset AND applies its knob snapshot.
    void selectPreset (const juce::String& presetName);

private:
    static juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();

    // One parsed sample ready to be mapped (from disk or bundled memory).
    struct SampleEntry
    {
        juce::String name;
        int root = 60;
        int velHi = 127;
        std::unique_ptr<juce::AudioFormatReader> reader;
    };

    // Shared mapping: computes key zones + velocity layers and adds the sounds.
    void buildSounds (std::vector<SampleEntry>& entries);

    // Loads samples for a preset from the bundled BankData (if present).
    void loadBankSamples (const juce::String& presetName);

    // Knob/FX snapshot applied when a preset is selected.
    struct PresetSnapshot
    {
        float resonance, cutoff, delay, reverb, pitch, attack, decay, release;
        bool  fxReverb, fxDelay, fxPitch;
        float gain = 1.0f; // per-preset volume boost
    };
    static PresetSnapshot snapshotFor (const juce::String& presetName);
    void applySnapshot (const PresetSnapshot& s);

    KhmerSynth synth;
    SharedParams sharedParams;
    juce::AudioFormatManager formatManager;
    juce::StringArray loadedSampleNames;

    // Thread-safe queue for notes coming from the GUI piano.
    juce::MidiMessageCollector midiCollector;

    // Simple master FX driven by the GUI parameters.
    juce::dsp::Reverb reverb;
    juce::dsp::DelayLine<float> delayLine { 96000 };
    double currentSampleRate { 44100.0 };
    float  currentPresetGain { 1.0f };

    void applyFxParameters();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SynthlenKhmerProcessor)
};
