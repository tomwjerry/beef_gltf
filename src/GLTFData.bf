using System;
using System.Collections;

namespace gLTF;

class GLTFData
{
    public Asset asset;
    public List<Accessor> accessors;
    public List<Animation> animations;
    public List<Buffer> buffers;
    public List<Buffer_View> buffer_views;
    public List<Camera> cameras;
    public List<Image> images;
    public List<Material> materials;
    public List<Mesh> meshes;
    public List<Node> nodes;
    public List<Sampler> samplers;
    public int? scene;
    public List<Scene> scenes;
    public List<Skin> skins;
    public List<Texture> textures;
    public List<String> extensions_used;
    public List<String> extensions_required;
    public Extensions extensions;        
    public Extras extras;
    public Json.JsonElement json_value;

    public this()
    {
        accessors = new .();
        animations = new .();
        buffers = new .();
        buffer_views = new .();
        cameras = new .();
        images = new .();
        materials = new .();
        meshes = new .();
        nodes = new .();
        samplers = new .();
        scenes = new .();
        skins = new .();
        textures = new .();
        extensions_used = new .();
        extensions_required = new .();
    }

    public ~this()
    {
        DeleteContainerAndDisposeItems!(accessors);
        DeleteContainerAndDisposeItems!(animations);
        DeleteContainerAndDisposeItems!(buffers);
        DeleteContainerAndDisposeItems!(buffer_views);
        DeleteContainerAndDisposeItems!(cameras);
        DeleteContainerAndDisposeItems!(images);
        DeleteContainerAndDisposeItems!(materials);
        DeleteContainerAndDisposeItems!(meshes);
        DeleteContainerAndDisposeItems!(nodes);
        DeleteContainerAndDisposeItems!(samplers);
        DeleteContainerAndDisposeItems!(scenes);
        DeleteContainerAndDisposeItems!(skins);
        DeleteContainerAndDisposeItems!(textures);
    }
}
