#!/bin/sh
# Run "dotnet" with the glibc tunables that the Urho3D native libraries need.
# libUrho3D.so uses static TLS. glibc cannot load such a library with dlopen from the dotnet host
# unless the static TLS space is bigger than the default. This script increases it.
case ":${GLIBC_TUNABLES}:" in
*:glibc.rtld.optional_static_tls=*) ;;
*) GLIBC_TUNABLES="${GLIBC_TUNABLES:+${GLIBC_TUNABLES}:}glibc.rtld.optional_static_tls=65536" ;;
esac
export GLIBC_TUNABLES
exec dotnet "$@"
