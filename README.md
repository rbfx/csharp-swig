# rbfx-csharp

C# bindings for the [rbfx](https://github.com/rbfx/rbfx) game engine.
The repository holds the SWIG interface files, the native wrapper library `Urho3DCSharp`,
the managed assembly `Urho3DNet`, and the C# tools, samples and tests.

## Requirements

- An rbfx engine built with `URHO3D_SCRIPT_RUNTIME=ON`, `URHO3D_MONOLITHIC_HEADER=ON` and shared libraries.
  The option `URHO3D_NO_EDITOR_PLAYER_EXE=ON` is necessary only for the in-tree form.
- The dotnet SDK.
- CMake 3.25 or newer and Ninja.
- bison is optional. The generated SWIG parser is in the repository. bison is only needed if it is missing.

## Build

The engine can be an in-tree sibling checkout (`../rbfx`) or an installed SDK.

In-tree engine. CMake builds the engine together with the bindings:

    cmake --preset linux-in-tree
    cmake --build cmake-build/linux-in-tree

Installed engine SDK. Set `URHO3D_SDK` to the install prefix of the engine:

    URHO3D_SDK=/path/to/urho-sdk cmake --preset linux-sdk
    cmake --build cmake-build/linux-sdk

Install the bindings as a package with `cmake --install cmake-build/linux-sdk --prefix <dir>`.

## Run

Start managed programs with `script/run-dotnet.sh` and not with `dotnet`.
The script sets the glibc tunable that `libUrho3D.so` needs, because it uses static TLS.
CMake copies the script to the output directory of the build.
This is `bin/<CMAKE_BUILD_TYPE>/` for a single-config generator (for example `bin/RelWithDebInfo/`)
and `bin/<Configuration>/` for a multi-config generator.

## Tests

    script/run-dotnet.sh test Source/Tests/CSharp/Urho3DNet.Tests.csproj --no-build -p:CMAKE_BINARY_DIR=$PWD/cmake-build/linux-in-tree/ -p:Platform=x64 -p:Configuration=RelWithDebInfo

## Layout

- `CMake/` - package config templates, the in-tree dummy config and the modules `Urho3DNetCommon.cmake` and `VSSolution.cmake`.
- `Source/Urho3DNet/` - SWIG files (`Swig/`), native helpers (`Native/`) and the managed assembly `Urho3DNet`.
- `Source/Editor/`, `Source/Player/`, `Source/Tools/` - the managed hosts, the editor wrapper and the C# tools.
- `Source/Samples/` - C# samples and a C# plugin.
- `Source/Tests/` - the C# unit tests.
- `ThirdParty/` - the SWIG generator (`swig`).
- `script/` - `run-dotnet.sh`, `ci.sh` and a Makefile.
- `packaging/` - NuGet packaging files.
- `.github/` - the CI workflows for the build and for NuGet.

## Use in a plugin

An external C++ plugin finds the bindings with `find_package`:

    find_package(Urho3D REQUIRED)
    find_package(Urho3DNet REQUIRED)
    csharp_bind_target(TARGET MyPlugin SWIG MyPlugin.i CSPROJ MyPlugin.csproj NAMESPACE Urho3DNet)

- Installed form: add the install prefix of the engine and of the bindings to `CMAKE_PREFIX_PATH`.
- In-tree form: set `Urho3D_DIR` to `<rbfx>/CMake/Urho3D/share/Urho3D`
  and `Urho3DNet_DIR` to `<rbfx-csharp>/CMake/Urho3DNet/share/Urho3DNet`.
  Set `URHO3D_SCRIPT_RUNTIME=ON`, `URHO3D_MONOLITHIC_HEADER=ON` and `URHO3D_NO_EDITOR_PLAYER_EXE=ON`
  before `find_package(Urho3D)`.
- `csharp_bind_target` links `Urho3DCSharp` to the plugin target. The SWIG file can then use `%import "Urho3D.i"`
  and `#include <Urho3DNet/Native/SWIGHelpers.h>`.
- The `.csproj` uses the variables `Urho3DNet_IS_SDK`, `Urho3DNet_PACKAGE_ROOT` and `Urho3DNet_SOURCE_DIR`.
  Installed form: reference `$(Urho3DNet_PACKAGE_ROOT)/bin/$(Configuration)/Urho3DNet.dll`.
  In-tree form: reference `$(Urho3DNet_SOURCE_DIR)/Source/Urho3DNet/Urho3DNet.csproj`.
- CMake does not build the plugin `.csproj`. Build it with `dotnet build` and `-p:CMAKE_BINARY_DIR=<build dir>/`.

## Platform status

- Verified: Linux x64 with a shared engine.
- Not verified: Windows, macOS, Android.
- Not supported by this build yet: static engine, iOS, Web, UWP. These platforms need the wrapper inside the host binary.

## NuGet packages

The scripts are in `packaging/nuget`. They need an engine SDK and a bindings SDK for each platform.
Build the engine SDK with `URHO3D_NO_EDITOR_PLAYER_EXE=ON`.

```
cd packaging/nuget
./package.sh merge -p linux-gcc-x64 -e <engine sdk dir> -b <bindings sdk dir> -s <engine source dir>
./package.sh create -v 0.0.1-dev
./package.sh local-repo
```

`merge` makes `in/rebelfork-sdk-<platform>-dll-latest/`. `create` packs the packages in `out/`.
`create` skips each package that has no input directory. If `nuget` is absent, the script uses `dotnet pack`.

## CI

The workflow `.github/workflows/build.yml` downloads `rebelfork-sdk-<tag>-latest.7z` from the release `latest` of `rbfx/rbfx`.
It builds the bindings with `script/ci.sh`.
On a push to `master`, it publishes `rebelfork-csharp-sdk-<tag>-latest.7z` to the release `latest` of this repository.

The inputs `rbfx_repository` and `rbfx_release` select a different engine release.
The repository variables `RBFX_REPOSITORY` and `RBFX_RELEASE` do the same.

To run the same steps on a local machine:

```
script/ci.sh all --engine-sdk <dir> --install-dir <dir>
```

## Known open items

- The Windows and macOS jobs and `nuget.yml` are not verified on a runner. Only `linux-x64` is verified for the NuGet packages.
