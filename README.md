# beef_gltf
GLTF importer made in Beef. Requires json tree reader and writer https://github.com/EinScott/json and Base64 encoder / decoder https://github.com/tomwjerry/beef_sead

See the example how to use. Note that the example requires SDL3.

Simply put, this should load a gLTF mesh:
```
// Make a stucture to load the data
GLTFData gltfData = scope GLTFData();
// This is a helper structure, to retrive data for each mesh.
List<GLTFGPUData> glftgpu = scope List<GLTFGPUData>();
// Loads gLTF data
if (GLTF.LoadFromFile(scope String(BasePath, "Content/Meshes/BarramundiFish.gltf"), gltfData) case .Err)
{
    return;
}
// Helper for a more useful format, but makes some assumptions of data types
if (GLTFGPUData.ConvertToGPUData(gltfData, glftgpu) case .Err)
{
    return;
}
// GLTFGPUData has positions, normals, colors, uvs, indices that can be rendered
```
