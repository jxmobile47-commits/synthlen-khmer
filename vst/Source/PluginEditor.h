#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"

//==============================================================================
// WebView-based editor. Renders the existing Synthlen Khmer HTML/CSS/JS design
// inside a juce::WebBrowserComponent. Static assets (html, css, images) are
// served from embedded BinaryData through a resource provider, so no external
// web server is required.
//==============================================================================
class SynthlenKhmerEditor : public juce::AudioProcessorEditor
{
public:
    explicit SynthlenKhmerEditor (SynthlenKhmerProcessor&);
    ~SynthlenKhmerEditor() override;

    void resized() override;

private:
    // Returns embedded asset bytes + mime type for a given URL path.
    std::optional<juce::WebBrowserComponent::Resource> getResource (const juce::String& url);

    // Builds the WebView options, wiring in every relay + the piano function.
    juce::WebBrowserComponent::Options makeOptions();

    SynthlenKhmerProcessor& processorRef;

    // ----- GUI <-> parameter relays (names match the JS / data-param ids) ----
    juce::WebSliderRelay resonanceRelay { "resonance" };
    juce::WebSliderRelay cutoffRelay    { "cutoff" };
    juce::WebSliderRelay delayRelay     { "delay" };
    juce::WebSliderRelay reverbRelay    { "reverb" };
    juce::WebSliderRelay pitchRelay     { "pitch" };
    juce::WebSliderRelay attackRelay    { "attack" };
    juce::WebSliderRelay decayRelay     { "decay" };
    juce::WebSliderRelay releaseRelay   { "release" };
    juce::WebSliderRelay masterRelay     { "master" };

    juce::WebToggleButtonRelay fxReverbRelay { "fxReverb" };
    juce::WebToggleButtonRelay fxDelayRelay  { "fxDelay" };
    juce::WebToggleButtonRelay fxPitchRelay  { "fxPitch" };

    // WebView must be constructed AFTER the relays above.
    juce::WebBrowserComponent webView { makeOptions() };

    // ----- parameter attachments (constructed in the .cpp ctor) --------------
    std::vector<std::unique_ptr<juce::WebSliderParameterAttachment>> sliderAttachments;
    std::vector<std::unique_ptr<juce::WebToggleButtonParameterAttachment>> toggleAttachments;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SynthlenKhmerEditor)
};
