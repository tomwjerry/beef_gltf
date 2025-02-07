namespace gLTF;

using System;
using System.Collections;

struct Options
{
	public bool is_glb;
	public bool delete_content;
	public String gltf_dir;
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

struct Data
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
}

struct GLTF_Param_Error
{
	public String name;
	public int index;

    public this()
    {
        this = default;
    }
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
	Wrong_Chunk_Type
}

struct JSON_Error
{
	public Json.JsonError type;
	public Json.JsonTree parser;

    public this()
    {
        this = default;
    }

    public this(Json.JsonError type, Json.JsonTree parser)
    {
        this.type = type;
        this.parser = parser;
    }
}

struct GLTF_Error
{
	public Error_Type type;
	public String proc_name;
	public GLTF_Param_Error param;

    public this()
    {
        this = default;
    }

    public this(Error_Type type, String proc_name)
    {
        this.type = type;
        this.proc_name = proc_name;
        this.param = GLTF_Param_Error();
    }

    public this(Error_Type type, String proc_name, GLTF_Param_Error param)
    {
        this.type = type;
        this.proc_name = proc_name;
        this.param = param;
    }
}

enum DError
{
	case JsonError(JSON_Error err);
	case GLTFError(GLTF_Error err);
}

typealias Extensions = Json.JsonElement;
typealias Extras = Json.JsonElement;

struct Asset
{
	public float version;
	public float? min_version;
	public String copyright;
	public String generator;
	public Extensions extensions;
	public Extras extras;
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
	case Byte(uint8[] byte);
}

struct Accessor
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
    public Accessor_Sparse? sparse;
    public Extensions extensions;
    public Extras extras;
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

struct Accessor_Sparse
{
    public Accessor_Sparse_Indices[] indices; // Required
    public Accessor_Sparse_Values[] values; // Required
    public Extensions extensions;
    public Extras extras;
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

struct Animation
{
	public Animation_Channel[] channels;
	public Animation_Sampler[] samplers;
	public String name;
	public Extensions extensions;
	public Extras extras;
}

struct Animation_Channel
{
    public int sampler; // Required
    public Animation_Channel_Target target; // Required
    public Extensions extensions;
	public Extras extras;
}

struct Animation_Channel_Target
{
    public Animation_Channel_Path path; // Required
    public int? node;
    public Extensions extensions;
    public Extras extras;
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

struct Buffer
{
    public int byte_length;
    public String name;
    public Uri uri;
    public Extensions extensions;
    public Extras extras;
}

struct Buffer_View
{
    public int buffer;
    public int byte_offset;
    public int byte_length;
    public int? byte_stride;
    public Buffer_Type_Hint target;
    public String name;
    public Extensions extensions;
    public Extras extras;
}

enum Buffer_Type_Hint
{
    Array = 34962,
    Element_Array
}

/*
    Camera related data structures
*/
struct Camera
{
    public Camera_Type type;
    public String name;
    public Extensions extensions;
    public Extras extras;
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
struct Image
{
    public String name;
    public Uri uri;
    public Image_Type type;
    public int? buffer_view;
    public Extensions extensions;
    public Extras extras;
}

enum Image_Type
{
    JPEG,
    PNG
}

/*
    Material related data structures
*/
struct Material
{
    public float[3] emissive_factor;
    public Material_Alpha_Mode alpha_mode;
    public float alpha_cutoff; // Default 0.5
    public bool double_sided;
    public String name;
    public Texture_Info emissive_texture;
    public Material_Metallic_Roughness metallic_roughness;
    public Texture_Info normal_texture;
    public Texture_Info occlusion_texture;
    public Extensions extensions;
    public Extras extras;
}

enum Material_Alpha_Mode
{
    Opaque, // Default
    Mask,
    Alpha_Cutoff,
    Blend
}

struct Material_Metallic_Roughness
{
    public float[4] base_color_factor; // Default [1, 1, 1, 1]
    public float metallic_factor;
    public float roughness_factor; // Default 1
    public Texture_Info base_color_texture;
    public Texture_Info metallic_roughness_texture;
    public Extensions extensions;
    public Extras extras;
}

/*
    Mesh related data structures
*/
struct Mesh
{
    public Mesh_Primitive[] primitives;
    public float[] weights;
    public String name;
    public Extensions extensions;
    public Extras extras;
}

struct Mesh_Primitive
{
    public Dictionary<int, int> attributes; // Required
    public Mesh_Primitive_Mode mode; // Default Triangles(4)
    public int? indices;
    public int? material;
    public Mesh_Target[] targets;
    public Extensions extensions;
    public Extras extras;
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
struct Mesh_Target
{
    public Mesh_Target_Type type;
    public int index;
    public Accessor data;
    public String name;
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
struct Node
{
    public float[16] mat; // Default Identity Matrix
    public float[4] rotation; // Default [x = 0, y = 0, z = 0, w = 1]
    public float[3] scale; // Default [1, 1, 1]
    public float[3] translation;
    public int? camera;
    public int? mesh;
    public int? skin;
    public int[] children;
    public String name;
    public float[] weights;
    public Extensions extensions;
    public Extras extras;
}

/*
    Sampler data structure
*/
struct Sampler
{
    public Wrap_Mode wrapS;
    public Wrap_Mode wrapT; // Default Repeat(10497)
    public String name;
    public Magnification_Filter mag_filter;
    public Minification_Filter min_filter;
    public Extensions extensions;
    public Extras extras;
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
struct Scene
{
    public int[] nodes;
    public String name;
    public Extensions extensions;
    public Extras extras;
}

/*
    Skin data structure
*/
struct Skin
{
    public int[] joints;// Required
    public int? inverse_bind_matrices;
    public int? skeleton;
    public String name;
    public Extensions extensions;
    public Extras extras;
}

/*
    Texture related data structures
*/
struct Texture
{
    public int? sampler;
    public int? source;
    public String name;
    public Extensions extensions;
    public Extras extras;
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
