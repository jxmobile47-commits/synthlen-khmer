#include "PluginEditor.h"

#if HAS_WEB_UI
 #include "BinaryData.h"
#endif

//==============================================================================
namespace
{
    juce::String mimeForExtension (const juce::String& ext)
    {
        if (ext == "html" || ext == "htm") return "text/html";
        if (ext == "css")  return "text/css";
        if (ext == "js")   return "text/javascript";
        if (ext == "json") return "application/json";
        if (ext == "png")  return "image/png";
        if (ext == "jpg" || ext == "jpeg") return "image/jpeg";
        if (ext == "webp") return "image/webp";
        if (ext == "gif")  return "image/gif";
        if (ext == "svg")  return "image/svg+xml";
        if (ext == "woff2") return "font/woff2";
        if (ext == "woff")  return "font/woff";
        return "application/octet-stream";
    }

    // BinaryData mangles file names: "synthlen-khmer.html" -> "synthlenkhmer_html".
    // This helper looks up a resource by its original file name.
    const char* findBinaryResource (const juce::String& fileName, int& sizeOut)
    {
       #if HAS_WEB_UI
        for (int i = 0; i < BinaryData::namedResourceListSize; ++i)
        {
            const char* original = BinaryData::getNamedResourceOriginalFilename (
                                       BinaryData::namedResourceList[i]);
            if (original != nullptr && fileName == juce::String (original))
                return BinaryData::getNamedResource (BinaryData::namedResourceList[i], sizeOut);
        }
       #endif
        sizeOut = 0;
        return nullptr;
    }
}

//==============================================================================
juce::WebBrowserComponent::Options SynthlenKhmerEditor::makeOptions()
{
    auto opts = juce::WebBrowserComponent::Options{}
        .withNativeIntegrationEnabled();

   #if JUCE_WINDOWS
    opts = opts.withBackend (juce::WebBrowserComponent::Options::Backend::webview2)
               .withWinWebView2Options (juce::WebBrowserComponent::Options::WinWebView2{}
                   .withUserDataFolder (juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory)
                                            .getChildFile ("Synthlen Khmer")));
   #endif

    return opts.withResourceProvider ([this] (const auto& url) { return getResource (url); })
        // On-screen piano -> MIDI. JS calls: pianoNote(isOn, midiNote, velocity)
        .withNativeFunction ("pianoNote",
            [this] (const juce::Array<juce::var>& args,
                    juce::WebBrowserComponent::NativeFunctionCompletion completion)
            {
                if (args.size() >= 2)
                {
                    bool  isOn = (bool) args[0];
                    int   note = (int)  args[1];
                    float vel  = args.size() >= 3 ? (float) args[2] : 0.8f;
                    processorRef.addMidiNote (isOn, note, vel);
                }
                completion (juce::var());
            })
        // Page asks to size the plugin window to fit its content (desktop-app feel).
        .withNativeFunction ("resizeEditor",
            [this] (const juce::Array<juce::var>& args,
                    juce::WebBrowserComponent::NativeFunctionCompletion completion)
            {
                if (args.size() >= 2)
                {
                    const int w = (int) args[0];
                    const int h = (int) args[1];
                    juce::MessageManager::callAsync ([this, w, h]
                    {
                        int maxW = 1920, maxH = 1080;
                        if (auto* d = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay())
                        {
                            maxW = d->userArea.getWidth();
                            maxH = d->userArea.getHeight();
                        }
                        setSize (juce::jlimit (640, maxW, w), juce::jlimit (480, maxH, h));
                    });
                }
                completion (juce::var());
            })
        // Preset list -> load sound bank + knob snapshot.
        .withNativeFunction ("selectPreset",
            [this] (const juce::Array<juce::var>& args,
                    juce::WebBrowserComponent::NativeFunctionCompletion completion)
            {
                if (args.size() >= 1)
                    processorRef.selectPreset (args[0].toString());
                completion (juce::var());
            })
        // Page asks for the preset names (bank folders found on disk).
        .withNativeFunction ("getPresetNames",
            [] (const juce::Array<juce::var>& args,
                juce::WebBrowserComponent::NativeFunctionCompletion completion)
            {
                juce::ignoreUnused (args);
                juce::Array<juce::var> names;
                for (auto& n : SynthlenKhmerProcessor::getPresetNames())
                    names.add (n);
                completion (juce::var (names));
            })
        // Register all parameter relays.
        .withOptionsFrom (resonanceRelay)
        .withOptionsFrom (cutoffRelay)
        .withOptionsFrom (delayRelay)
        .withOptionsFrom (reverbRelay)
        .withOptionsFrom (pitchRelay)
        .withOptionsFrom (attackRelay)
        .withOptionsFrom (decayRelay)
        .withOptionsFrom (releaseRelay)
        .withOptionsFrom (masterRelay)
        .withOptionsFrom (fxReverbRelay)
        .withOptionsFrom (fxDelayRelay)
        .withOptionsFrom (fxPitchRelay);
}

//==============================================================================
SynthlenKhmerEditor::SynthlenKhmerEditor (SynthlenKhmerProcessor& p)
    : AudioProcessorEditor (&p), processorRef (p)
{
    addAndMakeVisible (webView);

    // Connect each relay to its APVTS parameter.
    auto attachSlider = [this] (const juce::String& id, juce::WebSliderRelay& relay)
    {
        if (auto* param = processorRef.apvts.getParameter (id))
            sliderAttachments.push_back (
                std::make_unique<juce::WebSliderParameterAttachment> (*param, relay, nullptr));
    };
    auto attachToggle = [this] (const juce::String& id, juce::WebToggleButtonRelay& relay)
    {
        if (auto* param = processorRef.apvts.getParameter (id))
            toggleAttachments.push_back (
                std::make_unique<juce::WebToggleButtonParameterAttachment> (*param, relay, nullptr));
    };

    attachSlider ("resonance", resonanceRelay);
    attachSlider ("cutoff",    cutoffRelay);
    attachSlider ("delay",     delayRelay);
    attachSlider ("reverb",    reverbRelay);
    attachSlider ("pitch",     pitchRelay);
    attachSlider ("attack",    attackRelay);
    attachSlider ("decay",     decayRelay);
    attachSlider ("release",   releaseRelay);
    attachSlider ("master",    masterRelay);

    attachToggle ("fxReverb", fxReverbRelay);
    attachToggle ("fxDelay",  fxDelayRelay);
    attachToggle ("fxPitch",  fxPitchRelay);

   #if HAS_WEB_UI
    // Resource provider serves the root URL ("/") as the main HTML page.
    webView.goToURL (juce::WebBrowserComponent::getResourceProviderRoot());
   #else
    webView.goToURL ("data:text/html,<h2 style='font-family:sans-serif;color:#d4b872;"
                     "background:#1e2420;padding:40px'>Synthlen Khmer UI not bundled. "
                     "Run the bundle step (see BUILD.md) and rebuild.</h2>");
   #endif

    setResizable (false, false);
    setSize (1180, 880);
}

SynthlenKhmerEditor::~SynthlenKhmerEditor() = default;

//==============================================================================
std::optional<juce::WebBrowserComponent::Resource>
SynthlenKhmerEditor::getResource (const juce::String& url)
{
    // url is like "/" or "/uploads/instruments/roneat.png"
    juce::String path = url;
    // Strip any query string (e.g. cache-busting "?t=...").
    path = path.upToFirstOccurrenceOf ("?", false, false);
    if (path.startsWith ("/"))
        path = path.substring (1);
    if (path.isEmpty())
        path = "synthlen-khmer.html"; // default document

    // The HTML fetches "/api/manifest" -> serve the bundled manifest.json.
    if (path == "api/manifest")
        path = "manifest.json";

    auto fileName = path.fromLastOccurrenceOf ("/", false, false);

    int size = 0;
    const char* data = findBinaryResource (fileName, size);
    if (data == nullptr || size == 0)
        return std::nullopt;

    auto ext = fileName.fromLastOccurrenceOf (".", false, false).toLowerCase();

    std::vector<std::byte> bytes (static_cast<size_t> (size));
    std::memcpy (bytes.data(), data, static_cast<size_t> (size));

    return juce::WebBrowserComponent::Resource { std::move (bytes), mimeForExtension (ext) };
}

//==============================================================================
void SynthlenKhmerEditor::resized()
{
    webView.setBounds (getLocalBounds());
}
