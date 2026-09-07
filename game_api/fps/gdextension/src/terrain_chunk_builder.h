#pragma once

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

// Builds a terrain chunk mesh from a heightmap region. First native module;
// mirrors what TerrainStreamer (GDScript) would otherwise do per chunk.
class TerrainChunkBuilder : public RefCounted {
	GDCLASS(TerrainChunkBuilder, RefCounted)

protected:
	static void _bind_methods();

public:
	TerrainChunkBuilder() = default;
	~TerrainChunkBuilder() override = default;

	// heightmap: single-channel float image; region in pixels; world_size metres; height_scale metres.
	Ref<ArrayMesh> build(const Ref<Image> &heightmap, const Rect2i &region, float world_size, float height_scale, int lod) const;
};

} // namespace godot
