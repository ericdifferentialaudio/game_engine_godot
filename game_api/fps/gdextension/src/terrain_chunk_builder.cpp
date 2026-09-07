#include "terrain_chunk_builder.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

using namespace godot;

void TerrainChunkBuilder::_bind_methods() {
	ClassDB::bind_method(D_METHOD("build", "heightmap", "region", "world_size", "height_scale", "lod"),
			&TerrainChunkBuilder::build);
}

Ref<ArrayMesh> TerrainChunkBuilder::build(const Ref<Image> &heightmap, const Rect2i &region, float world_size,
		float height_scale, int lod) const {
	Ref<ArrayMesh> mesh;
	mesh.instantiate();
	if (heightmap.is_null()) {
		return mesh;
	}
	const int step = 1 << MAX(lod, 0);
	const int w = region.size.x / step + 1;
	const int h = region.size.y / step + 1;
	const float cell = world_size / (float)(w - 1);

	PackedVector3Array verts;
	PackedVector3Array normals;
	PackedVector2Array uvs;
	PackedInt32Array indices;
	verts.resize(w * h);
	normals.resize(w * h);
	uvs.resize(w * h);

	auto sample = [&](int px, int pz) -> float {
		px = CLAMP(px, 0, heightmap->get_width() - 1);
		pz = CLAMP(pz, 0, heightmap->get_height() - 1);
		return heightmap->get_pixel(px, pz).r * height_scale;
	};

	for (int z = 0; z < h; ++z) {
		for (int x = 0; x < w; ++x) {
			const int px = region.position.x + x * step;
			const int pz = region.position.y + z * step;
			const float y = sample(px, pz);
			const int i = z * w + x;
			verts[i] = Vector3(x * cell, y, z * cell);
			uvs[i] = Vector2((float)x / (w - 1), (float)z / (h - 1));
			const float hl = sample(px - step, pz), hr = sample(px + step, pz);
			const float hd = sample(px, pz - step), hu = sample(px, pz + step);
			normals[i] = Vector3(hl - hr, 2.0f * cell, hd - hu).normalized();
		}
	}
	for (int z = 0; z < h - 1; ++z) {
		for (int x = 0; x < w - 1; ++x) {
			const int i = z * w + x;
			indices.push_back(i);
			indices.push_back(i + w);
			indices.push_back(i + 1);
			indices.push_back(i + 1);
			indices.push_back(i + w);
			indices.push_back(i + w + 1);
		}
	}

	Array arrays;
	arrays.resize(Mesh::ARRAY_MAX);
	arrays[Mesh::ARRAY_VERTEX] = verts;
	arrays[Mesh::ARRAY_NORMAL] = normals;
	arrays[Mesh::ARRAY_TEX_UV] = uvs;
	arrays[Mesh::ARRAY_INDEX] = indices;
	mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
	return mesh;
}
