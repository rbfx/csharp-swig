#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

# Use nuget if it is available. Else use "dotnet pack" as a fallback.
NUGET=""
if [ -e ./nuget.exe ];
then
    NUGET=./nuget.exe
elif command -v nuget >/dev/null 2>&1;
then
    NUGET=nuget
elif ! command -v dotnet >/dev/null 2>&1;
then
    echo "Error: Neither nuget nor dotnet is available." >&2
    exit 1
fi

# Print the in/ directories that a nuspec file uses. XML comments are ignored.
nuspec_inputs() {
    perl -0pe 's/<!--.*?-->//gs' "$1" | grep -o 'src="in/[^/"]*' | sed 's/^src="//' | sort -u
}

# Pack one nuspec file.
# Usage: pack_nuspec <nuspec> <version> <output dir> [base path] [properties]
# Properties use the format "name=value;name2=value2".
pack_nuspec() {
    local nuspec="$1" version="$2" outdir="$3" basepath="${4:-$PWD}" props="${5:-}"

    if [ -n "$NUGET" ];
    then
        local args=(pack "$nuspec" -OutputDirectory "$outdir" -Version "$version" -BasePath "$basepath")
        if [ -n "$props" ];
        then
            args+=(-Properties "$props")
        fi
        $NUGET "${args[@]}"
        return
    fi

    local tmp rc=0
    tmp=$(mktemp -d)
    local framework="net$(dotnet --version | cut -d. -f1).0"
    cat <<EOF > "$tmp/pack.csproj"
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>$framework</TargetFramework>
        <IsPackable>true</IsPackable>
        <GenerateAssemblyInfo>false</GenerateAssemblyInfo>
        <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
        <IncludeBuildOutput>false</IncludeBuildOutput>
        <SuppressDependenciesWhenPacking>true</SuppressDependenciesWhenPacking>
        <NoWarn>\$(NoWarn);NU5128;NU5100;NU5129;CS2008</NoWarn>
    </PropertyGroup>
</Project>
EOF
    local nuspec_props="version=$version"
    if [ -n "$props" ];
    then
        nuspec_props="$nuspec_props;$props"
    fi
    mkdir -p "$outdir"
    dotnet pack "$tmp/pack.csproj" -nologo -v q \
        "-p:NuspecFile=$(realpath "$nuspec")" \
        "-p:NuspecBasePath=$(realpath "$basepath")" \
        "-p:NuspecProperties=\"$nuspec_props\"" \
        -o "$(realpath "$outdir")" || rc=$?
    rm -rf "$tmp"
    return $rc
}

merge() {
    local platform="" engine="" bindings="" source=""
    local OPTIND opt
    local usage="Usage: $0 merge -p PLATFORM -e ENGINE_SDK -b BINDINGS_SDK [-s ENGINE_SOURCE]"

    while getopts "p:e:b:s:h" opt; do
        case "$opt" in
            p) platform="$OPTARG" ;;
            e) engine="$OPTARG" ;;
            b) bindings="$OPTARG" ;;
            s) source="$OPTARG" ;;
            h)
                echo "$usage"
                echo "  -p PLATFORM        Platform name, for example linux-gcc-x64"
                echo "  -e ENGINE_SDK      Install tree of the engine"
                echo "  -b BINDINGS_SDK    Install tree of the C# bindings"
                echo "  -s ENGINE_SOURCE   Engine source tree (optional, for the SDL Java files)"
                return 0
                ;;
            *)
                echo "$usage" >&2
                return 1
                ;;
        esac
    done

    if [ -z "$platform" ] || [ -z "$engine" ] || [ -z "$bindings" ];
    then
        echo "Error: Options -p, -e and -b are required." >&2
        echo "$usage" >&2
        return 1
    fi
    local dir
    for dir in "$engine" "$bindings";
    do
        if [ ! -d "$dir" ];
        then
            echo "Error: $dir is not a directory." >&2
            return 1
        fi
    done

    local target="in/rebelfork-sdk-$platform-dll-latest"
    rm -rf "$target"
    mkdir -p "$target"
    # The bindings files overwrite the engine files with the same name.
    cp -a "$engine"/. "$target"/
    cp -a "$bindings"/. "$target"/
    echo "Merged into $target"

    if [ -n "$source" ];
    then
        local sdl="Source/ThirdParty/SDL/android-project/app/src/main/java/org/libsdl/app"
        if [ ! -d "$source/$sdl" ];
        then
            echo "Error: $source/$sdl is absent." >&2
            return 1
        fi
        rm -rf "in/engine-source/$sdl"
        mkdir -p "in/engine-source/$sdl"
        cp -a "$source/$sdl"/. "in/engine-source/$sdl"/
        echo "Copied SDL Java files into in/engine-source"
    fi
}

create() {
    local version=""
    local OPTIND opt

    # Parse options
    while getopts "v:h" opt; do
        case "$opt" in
            v)
                version="$OPTARG"
                ;;
            h)
                echo "Usage: $0 package [-v VERSION]"
                echo "  -v VERSION    Specify package version (default: auto-detect from git)"
                return 0
                ;;
            *)
                echo "Usage: $0 package [-v VERSION]" >&2
                return 1
                ;;
        esac
    done

    # Error if version is not provided
    if [ -z "$version" ];
    then
        echo "Error: Version not specified. Use -v option to specify version." >&2
        return 1
    fi

    # Append commit hash for dev versions
    case "$version" in
        *-alpha|*-dev)
            sha_short=$(git rev-parse --short HEAD)
            version="$version-$sha_short"
        ;;
    esac

    echo "Packaging $version"

    # Strip debug information from all binaries before packaging.
    # This is safe because in/ holds copies of the SDK files.
    find in -type f ! -name "*.dll" ! -name "*.exe" \( -name "*.so" -o -name "*.so.*" -o -executable \) -exec strip --strip-debug {} \; 2>/dev/null || true

    # Create .temp directory structure if it doesn't exist
    rm -rf out
    rm -rf ~/.nuget/packages/rbfx.urho3dnet* 2>/dev/null || true
    mkdir -p out

    cat <<EOF > ./build/rbfx.Urho3DNet.props
<Project>
    <PropertyGroup>
        <Urho3DNetVersion>$version</Urho3DNetVersion>
    </PropertyGroup>
</Project>
EOF

    # The data packages use the bin directory of the first merged SDK that has CoreData.
    local databin="" bin
    for bin in in/*/bin;
    do
        if [ -d "$bin/CoreData" ];
        then
            databin="$PWD/$bin"
            break
        fi
    done

    local nuspec dir missing
    for nuspec in rbfx.*.nuspec;
    do
        case "$nuspec" in
            rbfx.CoreData.nuspec|rbfx.Data.nuspec|rbfx.EditorData.nuspec)
                if [ -z "$databin" ];
                then
                    echo "Skip $nuspec: no merged SDK with bin/CoreData in in/"
                    continue
                fi
                pack_nuspec "$nuspec" "$version" out "$databin" "pkdir=$PWD"
                continue
                ;;
        esac

        missing=""
        for dir in $(nuspec_inputs "$nuspec");
        do
            if [ ! -d "$dir" ];
            then
                missing="$dir"
                break
            fi
        done
        if [ -n "$missing" ];
        then
            echo "Skip $nuspec: $missing is absent"
            continue
        fi
        pack_nuspec "$nuspec" "$version" out
    done

    echo "Packages created in out/"
}

local-repository() {
    local OPTIND opt

    # Parse options
    while getopts "h" opt; do
        case "$opt" in
            h)
                echo "Usage: $0 local-repo"
                echo "  Create a local NuGet repository from packages in out/"
                return 0
                ;;
            *)
                echo "Usage: $0 local-repo" >&2
                return 1
                ;;
        esac
    done

    rm -rf local-repository
    mkdir -p local-repository

    for package in out/*.nupkg;
    do
        if [ -n "$NUGET" ];
        then
            $NUGET add "$package" -source local-repository
        else
            # Without nuget use a flat folder feed.
            cp "$package" local-repository/
        fi
    done
}

# Main script logic
if [ $# -eq 0 ];
then
    echo "Usage: $0 <action> [options]" >&2
    echo "" >&2
    echo "Actions:" >&2
    echo "  merge         Merge an engine SDK and a bindings SDK into in/" >&2
    echo "  create        Build NuGet packages" >&2
    echo "  local-repo    Create local NuGet repository" >&2
    echo "" >&2
    echo "Use '$0 <action> -h' for action-specific help" >&2
    exit 1
fi

action="$1"
shift

case "$action" in
    merge)
        merge "$@"
    ;;
    create)
        create "$@"
    ;;
    local-repo)
        local-repository "$@"
    ;;
    *)
        echo "Error: Unknown action '$action'" >&2
        echo "Usage: $0 merge|create|local-repo [options]" >&2
        exit 1
    ;;
esac
