#pragma once

#include <JuceHeader.h>

//==============================================================================
// Machine-locked licensing.
//
// Each computer has a unique Machine ID (derived from hardware identifiers).
// A license key is valid only when it matches SHA256(machineId + secret).
// Keys are generated with the private keygen script (vst/keygen.ps1) which
// must NEVER be distributed with the plugin.
//==============================================================================
namespace Licensing
{
    // Must match the secret inside keygen.ps1.
    static constexpr const char* kSecret = "SynKh2026_License_Secret_KH#77";

    inline juce::String groupHex (const juce::String& hex)
    {
        juce::String out;
        for (int i = 0; i < hex.length(); i += 4)
        {
            if (out.isNotEmpty()) out << "-";
            out << hex.substring (i, i + 4);
        }
        return out;
    }

    // Stable per-computer ID shown to the customer (XXXX-XXXX-XXXX-XXXX).
    inline juce::String getMachineId()
    {
        auto raw = juce::SystemStats::getUniqueDeviceID();
        juce::SHA256 h (raw.toRawUTF8(), raw.getNumBytesAsUTF8());
        return groupHex (h.toHexString().toUpperCase().substring (0, 16));
    }

    // The one valid key for a given machine ID (XXXX-XXXX-XXXX-XXXX-XXXX).
    inline juce::String keyForMachine (const juce::String& machineId)
    {
        auto data = machineId.trim().toUpperCase() + juce::String (kSecret);
        juce::SHA256 h (data.toRawUTF8(), data.getNumBytesAsUTF8());
        return groupHex (h.toHexString().toUpperCase().substring (0, 20));
    }

    inline juce::File licenseFile()
    {
        return juce::File::getSpecialLocation (juce::File::userDocumentsDirectory)
                   .getChildFile ("Synthlen Khmer")
                   .getChildFile ("license.key");
    }

    inline bool isValidKey (const juce::String& key)
    {
        return key.trim().equalsIgnoreCase (keyForMachine (getMachineId()));
    }

    inline bool isLicensed()
    {
        auto f = licenseFile();
        return f.existsAsFile() && isValidKey (f.loadFileAsString());
    }

    // Validates and stores the key. Returns true on success.
    inline bool activate (const juce::String& key)
    {
        if (! isValidKey (key))
            return false;

        auto f = licenseFile();
        f.getParentDirectory().createDirectory();
        f.replaceWithText (key.trim());
        return true;
    }
}
