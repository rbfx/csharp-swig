#!/usr/bin/env bash
# Build driver for rbfx-csharp. It runs in CI and on a developer machine.
# Usage: script/ci.sh <configure|build|test|install|all> [options] [-- extra-cmake-args]
# Options:
#   --engine-sdk DIR   Engine SDK prefix. Default: env CMAKE_PREFIX_PATH.
#   --build-dir DIR    Default: <repo>/cmake-build/ci
#   --install-dir DIR  Required for install and all.
#   --config NAME      Default: RelWithDebInfo
# Env: CI_OSX_ARCHITECTURES, Urho3D_DIR, CI_SKIP_TESTS=1 (for all)
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config=RelWithDebInfo
engine_sdk=''
build_dir="$root/cmake-build/ci"
install_dir=''
extra_args=()

native-path() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

is-windows() {
    case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; *) return 1 ;; esac
}

configure() {
    local prefix="${engine_sdk:-${CMAKE_PREFIX_PATH:-}}"
    if [[ -z "$prefix" ]]; then
        echo "Error: set --engine-sdk or CMAKE_PREFIX_PATH." >&2
        return 1
    fi
    local args=(-S "$(native-path "$root")" -B "$(native-path "$build_dir")" -DBUILD_SHARED_LIBS=ON)
    args+=("-DCMAKE_PREFIX_PATH=$prefix")
    if [[ -n "${Urho3D_DIR:-}" ]]; then
        args+=("-DUrho3D_DIR=${Urho3D_DIR}")
    fi
    if [[ -n "${CI_OSX_ARCHITECTURES:-}" ]]; then
        args+=("-DCMAKE_OSX_ARCHITECTURES=${CI_OSX_ARCHITECTURES}")
    fi
    # Windows uses the default Visual Studio generator, which is multi-config.
    if ! is-windows; then
        args+=("-DCMAKE_BUILD_TYPE=$config")
        if command -v ninja >/dev/null 2>&1; then
            args+=(-G Ninja)
        fi
    fi
    cmake "${args[@]}" ${extra_args[@]+"${extra_args[@]}"}
}

build() {
    local extra=()
    if is-windows; then
        # ALL_BUILD ignores solution-level project dependencies, so MSBuild compiles the C# projects
        # in parallel with SWIG. Build the native wrappers first to generate the C# sources.
        cmake --build "$(native-path "$build_dir")" --config "$config" --parallel \
            --target Urho3DCSharp libEditorWrapper libPlayer Urho3DNetTestsLib
        # The Visual Studio generator does not restore NuGet packages of external C# projects.
        extra=(-- -restore)
    fi
    cmake --build "$(native-path "$build_dir")" --config "$config" --parallel ${extra[@]+"${extra[@]}"}
}

run-test() {
    local runner=(dotnet)
    if [[ "$(uname -s)" == Linux ]]; then
        runner=("$root/script/run-dotnet.sh")
    fi
    # Windows has no RPATH. The wrapper library needs the engine library on PATH.
    local prefix="${engine_sdk:-${CMAKE_PREFIX_PATH:-}}"
    if is-windows && [[ -n "$prefix" ]]; then
        prefix=$(cygpath -u "$prefix")
        PATH="$prefix/bin/$config:$prefix/bin:$PATH"
    fi
    "${runner[@]}" test "$root/Source/Tests/CSharp/Urho3DNet.Tests.csproj" --no-build \
        "-p:CMAKE_BINARY_DIR=$(native-path "$build_dir")/" -p:Platform=x64 "-p:Configuration=$config"
}

install-sdk() {
    if [[ -z "$install_dir" ]]; then
        echo "Error: --install-dir is required." >&2
        return 1
    fi
    cmake --install "$(native-path "$build_dir")" --config "$config" --prefix "$(native-path "$install_dir")"
}

[[ $# -ge 1 ]] || { sed -n 2,9p "${BASH_SOURCE[0]}"; exit 1; }
command=$1; shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --engine-sdk) engine_sdk=$2; shift 2 ;;
        --build-dir) build_dir=$2; shift 2 ;;
        --install-dir) install_dir=$2; shift 2 ;;
        --config) config=$2; shift 2 ;;
        --) shift; extra_args=("$@"); break ;;
        *) echo "Error: unknown option: $1" >&2; exit 1 ;;
    esac
done

# MSBuild resolves a relative CMAKE_BINARY_DIR from the project directory, so use absolute paths.
absolute-path() {
    if [[ -z "$1" || "$1" == /* || "$1" =~ ^[A-Za-z]:[\\/] ]]; then printf '%s\n' "$1"; else printf '%s\n' "$PWD/$1"; fi
}
build_dir=$(absolute-path "$build_dir")
install_dir=$(absolute-path "$install_dir")

case "$command" in
    configure) configure ;;
    build) build ;;
    test) run-test ;;
    install) install-sdk ;;
    all)
        configure
        build
        if [[ "${CI_SKIP_TESTS:-}" != 1 ]]; then run-test; fi
        install-sdk
        ;;
    *) echo "Error: unknown command: $command" >&2; exit 1 ;;
esac
