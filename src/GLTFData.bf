using System;

namespace gLTF;

class GLTFData
{
    public Asset asset;
    public Accessor[] accessors;
    public Animation[] animations;
    public Buffer[] buffers;
    public Buffer_View[] buffer_views;
    public Camera[] cameras;
    public Image[] images;
    public Material[] materials;
    public Mesh[] meshes;
    public Node[] nodes;
    public Sampler[] samplers;
    public int? scene;
    public Scene[] scenes;
    public Skin[] skins;
    public Texture[] textures;
    public String[] extensions_used;
    public String[] extensions_required;
    public Extensions extensions;        
    public Extras extras;
    public Json.JsonElement json_value;

    public ~this()
    {
        delete accessors;
        delete animations;
        delete buffers;
        delete buffer_views;
        delete cameras;
        delete images;
        delete materials;
        delete meshes;
        delete nodes;
        delete samplers;
        delete scenes;
        delete skins;
        delete textures;
        delete extensions_used;
        delete extensions_required;
    }
}
