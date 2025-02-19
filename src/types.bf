using System;
using System.Collections;

namespace gLTF;

struct Options : IDisposable
{
	public bool is_glb;
	public bool delete_content;
	public String gltf_dir;

    public void Dispose()
    {
        if (gltf_dir != null)
        {
            delete gltf_dir;
        }
    }
}

struct GLB_Header
{
	public uint32 magic;
	public uint32 version;
	public uint32 length;
}

struct GLB_Chunk_Header
{
	public uint32 length;
	public uint32 type;
}

enum Error_Type
{
	Bad_GLB_Magic,
	Cant_Read_File,
	Data_Too_Short,
	Missing_Required_Parameter,
	No_File,
	Invalid_Type,
	JSON_Missing_Section,
	Unknown_File_Type,
	Unsupported_Version,
	Wrong_Chunk_Type,
    JSONError
}
struct GLTFError : IDisposable
{
    public bool isJsonError;
	public Error_Type type;
    public String proc_name;
    public String errorName;
    public int errorIndex;
    public Json.JsonError jsonType;
    public Json.JsonTree jsonParser;

    public this()
    {
        this = default;
        isJsonError = false;
    }

    public this(Json.JsonError type, Json.JsonTree parser)
    {
        this = default;
        this.jsonType = type;
        this.jsonParser = parser;
        this.type = .JSONError;
        isJsonError = true;
    }


    public this(Error_Type type, String proc_name)
    {
        this = default;
        this.type = type;
        this.proc_name = proc_name;
        isJsonError = false;
    }

    public this(Error_Type type, String proc_name, String errorName)
    {
        this = default;
        this.type = type;
        this.proc_name = proc_name;
        this.errorName = errorName;
        isJsonError = false;
    }

    public this(Error_Type type, String proc_name, String errorName, int errorIndex)
    {
        this = default;
        this.type = type;
        this.proc_name = proc_name;
        this.errorName = errorName;
        this.errorIndex = errorIndex;
        isJsonError = false;
    }

    public void Dispose()
    {
        if (errorName != null)
        {
            delete errorName;
        }

        if (errorName != null)
        {
            delete errorName;
        }
    }
}

typealias Extensions = Json.JsonElement;
typealias Extras = Json.JsonElement;

struct Asset : IDisposable
{
	public float version;
	public float? min_version;
	public String copyright;
	public String generator;
	public Extensions extensions;
	public Extras extras;

    public void Dispose()
    {
        if (copyright != null)
        {
            delete copyright;
        }

        if (generator != null)
        {
            delete generator;
        }
    }    
}

enum Component_Type
{
	Byte = 5120,
	Unsigned_Byte,
	Short,
	Unsigned_Short,
	Unsigned_Int = 5125,
	Float
}

enum Uri
{
	case Str(String str);
	case Byte(Span<uint8> byte);
}

struct Accessor : IDisposable
{
	public int byte_offset;
    public Component_Type component_type; // Required
    public bool normalized;
    public int count; // Required
    public Accessor_Type type;// Required
    public int? buffer_view;
    public float[16]? max;
	public float[16]? min;
    public String name;
    public Extensions extensions;
    public Extras extras;
    public List<Accessor_Sparse_Indices> indices; // Required
    public List<Accessor_Sparse_Values> values; // Required
    public Extensions accessorExtensions;
    public Extras accessorExtras;

    public this()
    {
        this = default;
        indices = new .();
        values = new .();
    }

    public void Dispose()
    {
        if (indices != null)
        {
            delete indices;
        }

        if (values != null)
        {
            delete values;
        }
 
        if (name != null)
        {
            delete name;
        }
    }
}

enum Accessor_Type
{
	Scalar,
	Vector2,
	Vector3,
	Vector4,
	Matrix2,
	Matrix3,
	Matrix4
}

struct Accessor_Sparse_Indices
{
    public int buffer_view; // Required
    public int byte_offset;
    public Component_Type component_type; // Required
    public Extensions extensions;
    public Extras extras;
}

struct Accessor_Sparse_Values
{
    public int buffer_view;// Required
    public int byte_offset;
    public Extensions extensions;
    public Extras extras;
}

struct Animation : IDisposable
{
	public List<Animation_Channel> channels;
	public List<Animation_Sampler> samplers;
	public String name;
	public Extensions extensions;
	public Extras extras;

    public this()
    {
        this = default;
        channels = new .();
        samplers = new .();
    }

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }

        if (channels != null)
        {
            delete channels;
        }

        if (samplers != null)
        {
            delete channels;
        }
    }
}

struct Animation_Channel
{
    public int sampler; // Required
    public Extensions extensions;
	public Extras extras;
    public Animation_Channel_Path path; // Required
    public int? node;
    public Extensions targetExtensions;
    public Extras targetExtras;
}

struct Animation_Sampler
{
    public int input;
    public int output; // Required
    public Interpolation_Algorithm interpolation; // Default: Linear
    public Extensions extensions;
    public Extras extras;
}

enum Interpolation_Algorithm
{
    Linear = 0, // Default
    Step,
    Cubic_Spline
}

enum Animation_Channel_Path
{
    Translation,
    Rotation,
    Scale,
    Weights
}

struct Buffer : IDisposable
{
    public int byte_length;
    public String name;
    public Uri uri;
    public Extensions extensions;
    public Extras extras;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

struct Buffer_View : IDisposable
{
    public int buffer;
    public int byte_offset;
    public int byte_length;
    public int? byte_stride;
    public Buffer_Type_Hint target;
    public String name;
    public Extensions extensions;
    public Extras extras;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

enum Buffer_Type_Hint
{
    Array = 34962,
    Element_Array
}

/*
    Camera related data structures
*/
struct Camera : IDisposable
{
    public Camera_Type type;
    public String name;
    public Extensions extensions;
    public Extras extras;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

enum Camera_Type
{
    case Null;
	case Perspective(Perspective_Camera camera);
    case Orthographic(Orthographic_Camera camera);
}

struct Perspective_Camera
{
    public float yfov;
    public float znear;
    public float? aspect_ratio;
    public float? zfar;
    public Extensions extensions;
    public Extras extras;
}

struct Orthographic_Camera
{
    public float xmag; 
    public float ymag;
    public float zfar; 
    public float znear;
    public Extensions extensions;
    public Extras extras;
}

/*
    Image related data structures
*/
struct Image : IDisposable
{
    public String name;
    public Uri uri;
    public Image_Type type;
    public int? buffer_view;
    public Extensions extensions;
    public Extras extras;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

enum Image_Type
{
    JPEG,
    PNG
}

/*
    Material related data structures
*/
struct Material : IDisposable
{
    public float[3] emissive_factor;
    public Material_Alpha_Mode alpha_mode;
    public float alpha_cutoff; // Default 0.5
    public bool double_sided;
    public String name;
    public Texture_Info emissive_texture;
    public Texture_Info normal_texture;
    public Texture_Info occlusion_texture;
    public Extensions extensions;
    public Extras extras;

    public float[4] metallic_base_color_factor; // Default [1, 1, 1, 1]
    public float metallic_factor;
    public float metallic_roughness_factor; // Default 1
    public Texture_Info metallic_base_color_texture;
    public Texture_Info metallic_roughness_texture;
    public Extensions metallic_extensions;
    public Extras metallic_extras;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

enum Material_Alpha_Mode
{
    Opaque, // Default
    Mask,
    Alpha_Cutoff,
    Blend
}

/*
    Mesh related data structures
*/
struct Mesh : IDisposable
{
    public List<Mesh_Primitive> primitives;
    public List<float> weights;
    public String name;
    public Extensions extensions;
    public Extras extras;

    public this()
    {
        this = default;
        primitives = new .();
        weights = new .();
    }

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }

        if (primitives != null)
        {
            DeleteContainerAndDisposeItems!(primitives);
        }

        if (weights != null)
        {
            delete weights;
        }
    }
}

struct Mesh_Primitive : IDisposable
{
    public Dictionary<StringView, int> attributes; // Required
    public Mesh_Primitive_Mode mode; // Default Triangles(4)
    public int? indices;
    public int? material;
    public List<Mesh_Target> targets;
    public Extensions extensions;
    public Extras extras;

    public this()
    {
        this = default;
        targets = new .();
    }

    public void Dispose()
    {
        if (attributes != null)
        {
            attributes.Clear();
            delete attributes;
        }

        if (targets != null)
        {
            DeleteContainerAndDisposeItems!(targets);
        }
    }
}

enum Mesh_Primitive_Mode
{
    Points,
    Lines,
    Line_Loop,
    Line_Strip,
    Triangles, // Default
    Triangle_Strip,
    Triangle_Fan
}

// TODO: Verify if this is correct
struct Mesh_Target : IDisposable
{
    public Mesh_Target_Type type;
    public int index;
    public Accessor data;
    public String name;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

// TODO: Verify if this is correct
enum Mesh_Target_Type
{
    Invalid,
    Position,
    Normal,
    Tangent,
    TexCoord,
    Color,
    Joints,
    Weights,
    Custom
}

/*
    Node data structure
*/
struct Node : IDisposable
{
    public float[16] mat; // Default Identity Matrix
    public float[4] rotation; // Default [x = 0, y = 0, z = 0, w = 1]
    public float[3] scale; // Default [1, 1, 1]
    public float[3] translation;
    public int? camera;
    public int? mesh;
    public int? skin;
    public List<int> children;
    public String name;
    public List<float> weights;
    public Extensions extensions;
    public Extras extras;

    public this()
    {
        this = default;
        children = new .();
        weights = new .();
    }

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }

        if (children != null)
        {
            delete children;
        }

        if (weights != null)
        {
            delete weights;
        }
    }
}

/*
    Sampler data structure
*/
struct Sampler : IDisposable
{
    public Wrap_Mode wrapS;
    public Wrap_Mode wrapT; // Default Repeat(10497)
    public String name;
    public Magnification_Filter mag_filter;
    public Minification_Filter min_filter;
    public Extensions extensions;
    public Extras extras;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

enum Wrap_Mode
{
    Repeat          = 10497, // Default
    Clamp_To_Edge   = 33071,
    Mirrored_Repeat = 33648
}

enum Magnification_Filter
{
    Nearest = 9728,
    Linear
}

enum Minification_Filter
{
    Nearest = 9728,
    Linear,
    Nearest_MipMap_Nearest = 9984,
    Linear_MipMap_Nearest,
    Nearest_MipMap_Linear,
    Linear_MipMap_Linear
}

/*
    Scene data structure
*/
struct Scene : IDisposable
{
    public List<int> nodes;
    public String name;
    public Extensions extensions;
    public Extras extras;

    public this()
    {
        this = default;
        nodes = new .();
    }

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }

        if (nodes != null)
        {
            delete nodes;
        }
    }
}

/*
    Skin data structure
*/
struct Skin : IDisposable
{
    public List<int> joints;// Required
    public int? inverse_bind_matrices;
    public int? skeleton;
    public String name;
    public Extensions extensions;
    public Extras extras;

    public this()
    {
        this = default;
        joints = new .();
    }

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }

        if (joints != null)
        {
            delete joints;
        }
    }
}

/*
    Texture related data structures
*/
struct Texture : IDisposable
{
    public int? sampler;
    public int? source;
    public String name;
    public Extensions extensions;
    public Extras extras;

    public void Dispose()
    {
        if (name != null)
        {
            delete name;
        }
    }
}

enum TextureType
{
    Regular,
    Normal,
    Occlusion
}

struct Texture_Info
{
    public TextureType textureType;
    public int index;
    public int tex_coord;
    public float scale; // Default 1
    public float strength; // Default 1
    public Extensions extensions;
    public Extras extras;
}

class Types
{
	public static String ACCESSORS_KEY = "accessors";
	public static String ANIMATIONS_KEY = "animations";
	public static String ASSET_KEY = "asset";
	public static String BUFFERS_KEY = "buffers";
	public static String BUFFER_VIEWS_KEY = "bufferViews";
	public static String CAMERAS_KEY = "cameras";
	public static String IMAGES_KEY = "images";
	public static String MATERIALS_KEY = "materials";
	public static String MESHES_KEY = "meshes";
	public static String NODES_KEY = "nodes";
	public static String SAMPLERS_KEY = "samplers";
	public static String SCENE_KEY = "scene";
	public static String SCENES_KEY = "scenes";
	public static String SKINS_KEY = "skins";
	public static String TEXTURES_KEY = "textures";
	public static String EXTENSIONS_KEY = "extensions";
	public static String EXTENSIONS_REQUIRED_KEY = "extensionsRequired";
	public static String EXTENSIONS_USED_KEY = "extensionsUsed";
	public static String EXTRAS_KEY = "extras";

	public static bool GLTF_DOUBLE_PRECISION = false;

	public static int CHUNK_TYPE_BIN = 0x004e4942;
	public static int CHUNK_TYPE_JSON = 0x4e4f534a;
}
