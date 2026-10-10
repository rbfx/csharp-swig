// Copyright (c) 2017-2026 the rbfx project.
// This work is licensed under the terms of the MIT license.
// For a copy, see <https://opensource.org/licenses/MIT> or the accompanying LICENSE file.

#include <Player/PlayerApplication.h>

#include <Urho3D/Engine/EngineDefs.h>

namespace Urho3D
{

class PlayerApplicationWithPlugins : public PlayerApplication
{
public:
    using PlayerApplication::PlayerApplication;

    /// Implement PlayerApplication.
    /// @{
    void Setup() override
    {
        PlayerApplication::Setup();

        engineParameters_[EP_PLUGINS] = ea::string::joined(LinkedPlugins::GetLinkedPlugins(), ";");
        LinkedPlugins::RegisterStaticPlugins();
    }
    /// @}
};

}

// The managed host loads this module and calls the exported CreateApplication function.
URHO3D_DEFINE_APPLICATION_FACTORY(Urho3D::PlayerApplicationWithPlugins);
