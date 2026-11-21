using System;
using System.Collections.Generic;

namespace Urho3DNet
{
    /// <summary>
    /// Copies the type registry of a SWIG module into the shared Urho3D registry.
    /// The proxy classes of each module call <see cref="Ensure"/> in a static initializer.
    /// </summary>
    public static class SwigTypeRegistryMerge
    {
        private static readonly HashSet<Type> Done = new HashSet<Type>();

        /// <param name="module">The PINVOKE class of the module. It identifies the module.</param>
        /// <param name="init">Fills the registry of the module.</param>
        /// <param name="get">Returns the registry of the module.</param>
        public static bool Ensure(Type module, Action init, Func<Dictionary<IntPtr, Type>> get)
        {
            lock (Done)
            {
                if (!Done.Add(module))
                    return true;
                // A module with its own initializer (Urho3D) is ready: do not initialize it again.
                var registry = get();
                if (registry == null)
                {
                    init();
                    registry = get();
                }
                var shared = Urho3DPINVOKE.SWIGTypeRegistry;
                if (!ReferenceEquals(registry, shared))
                {
                    foreach (var pair in registry)
                        shared[pair.Key] = pair.Value;
                }
                return true;
            }
        }
    }
}
