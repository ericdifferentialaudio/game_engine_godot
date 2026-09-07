# gdextension/ — native (C++) performance modules

GDScript owns game logic. This folder is the **escape hatch** for hot paths
that profiling proves too slow in script. Nothing here is required to run the
project today; the framework runs 100% in GDScript.

## Candidates (in priority order)
1. `TerrainStreamer` chunk generation from heightmaps (mesh + collision + LOD).
2. Intel graph queries once journals reach thousands of tokens (relationship
   inference, contradiction detection, "what do I know about X?" at scale).
3. Procedural dungeon layout generation for recursive sublevels.
4. Large-scale foliage scattering / GPU instancing management.

## Toolchain
- Godot 4.3+ with matching `godot-cpp` (git submodule at `gdextension/godot-cpp`)
- SCons (`pip install scons`) *or* CMake ≥ 3.22 + Ninja
- MSVC 2022 (Windows), clang/gcc elsewhere

```powershell
cd gdextension
git submodule add -b 4.3 https://github.com/godotengine/godot-cpp godot-cpp
git submodule update --init --recursive
scons platform=windows target=template_debug
```
Output lands in `gdextension/bin/`. Then rename `intelforge.gdextension.disabled`
→ `intelforge.gdextension` to activate it (it is disabled by default because Godot
loads every `.gdextension` it finds and errors when the DLL is absent).

## Layout
```
gdextension/
  SConstruct              build script (godot-cpp convention)
  intelforge.gdextension  Godot loader manifest (enable by copying to project root)
  src/
    register_types.cpp/.h class registration
    terrain_chunk_builder.h/.cpp   (first module – stub)
```
