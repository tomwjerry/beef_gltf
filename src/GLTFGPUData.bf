using System;
using System.Collections;

namespace GLTF;

class GLTFGPUData
{
    public List<float[3]> positions;
    public List<float[3]> normals;
    public List<float[4]> colors;
    public List<float[2]> uvs;
    public List<uint16> indices;

    public static Result<void, GLTFError> ConvertToGPUData(GLTFData gltfData, List<GLTFGPUData> gpuData)
    {
        // Look in the meshes place, and get the accessors to the meshes out
        for (let mesh in gltfData.meshes)
        {
            let meshGPUData = new GLTFGPUData();

            for (let primitive in mesh.primitives)
            {
                meshGPUData.indices.AddRange(gltfData.accessors[(int)primitive.indices]
                    .accessorDataUnsignedShort.GetEnumerator());

                if (primitive.attributes.ContainsKey(.Position))
                {
                    let accessorData = gltfData.accessors[(int)primitive.attributes[.Position]]
                        .accessorDataFloat;
                    for (int posFragment = 0; posFragment < accessorData.Count; posFragment += 3)
                    {
                        meshGPUData.positions.Add(float[3](accessorData[posFragment],
                            accessorData[posFragment + 1],
                            accessorData[posFragment + 2]));
                    }   
                }
                if (primitive.attributes.ContainsKey(.Normal))
                {
                    let accessorData = gltfData.accessors[(int)primitive.attributes[.Normal]]
                        .accessorDataFloat;
                    for (int fragment = 0; fragment < accessorData.Count; fragment += 3)
                    {
                        meshGPUData.normals.Add(float[3](accessorData[fragment],
                            accessorData[fragment + 1],
                            accessorData[fragment + 2]));
                    }
                }
                if (primitive.attributes.ContainsKey(.TexCoord))
                {
                    let accessorData = gltfData.accessors[(int)primitive.attributes[.TexCoord]]
                        .accessorDataFloat;
                    for (int fragment = 0; fragment < accessorData.Count; fragment += 2)
                    {
                        meshGPUData.uvs.Add(float[2](accessorData[fragment],
                            accessorData[fragment + 1]));
                    }
                }
                if (primitive.attributes.ContainsKey(.Color))
                {
                    let accessorData = gltfData.accessors[(int)primitive.attributes[.Color]]
                        .accessorDataFloat;
                    for (int fragment = 0; fragment < accessorData.Count; fragment += 4)
                    {
                        meshGPUData.colors.Add(float[4](accessorData[fragment],
                            accessorData[fragment + 1],
                            accessorData[fragment + 2],
                            accessorData[fragment + 3]));
                    }
                }
            }

            gpuData.Add(meshGPUData);
        }

        return .Ok;
    }

    public this ()
    {
        positions = new List<float[3]>();
        normals = new List<float[3]>();
        colors = new List<float[4]>();
        uvs = new List<float[2]>();
        indices = new List<uint16>();
    }

    public ~this ()
    {
        delete positions;
        delete normals;
        delete colors;
        delete uvs;
        delete indices;
    }
}
