using System;
using System.Collections;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace gLTF;

using internal gLTF;

class gLTF
{
	private static int GLB_MAGIC = 0x46546c67;
	private static int GLB_HEADER_SIZE = sizeof(GLB_Header);
	private static int GLB_CHUNK_HEADER_SIZE = sizeof(GLB_Chunk_Header);
	private static int GLTF_MIN_VERSION = 2;

	/*
	    Main library interface procedures
	*/
	public static Result<GLTFData, DError> load_from_file(String file_name)
    {
        if (!File.Exists(file_name))
        {
            return .Err(DError.GLTFError(GLTF_Error(Error_Type.No_File, "load_from_file", GLTF_Param_Error() { name = file_name })));
        }

        List<uint8> file_content = new List<uint8>();

        let res = File.ReadAll(file_name, file_content);
	    if (res case .Err)
        {
            return .Err(DError.GLTFError(GLTF_Error(Error_Type.Cant_Read_File, "load_from_file", GLTF_Param_Error() { name = file_name })));
	    }

        String gltf_dir = scope String();
        Path.GetDirectoryPath(file_name, gltf_dir);

	    Options options = Options()
        {
	        delete_content = true,
	        gltf_dir       = gltf_dir,
	    };

        String fext = scope String();
        Path.GetExtension(file_name, fext);
        fext.ToLower();

	    switch (fext)
        {
    	    case ".gltf":
    	        return parse(file_content, options);

    	    case ".glb":
    	        options.is_glb = true;
    	        return parse(file_content, options);

    	    default:
                return .Err(DError.GLTFError(
                    GLTF_Error(Error_Type.Unknown_File_Type, "load_from_file", GLTF_Param_Error() { name = file_name })));
    	}
    }

	public static Result<GLTFData, DError> parse(List<uint8> file_content, Options opt)
    {
        // Seems always be true? Why delete content before use? 
	    if (opt.delete_content)
        {
	        //file_content.Clear();
	    }

        GLTFData retdata = new GLTFData();

	    if (file_content.Count < GLB_HEADER_SIZE)
        {
	        return .Err(DError.GLTFError(GLTF_Error(.Data_Too_Short, "parse")));
	    }

	    Span<uint8> json_data = file_content;
	    int content_index = 0;

	    if (opt.is_glb)
        {
	        GLB_Header header = *(GLB_Header*)file_content.GetRange(0, GLB_HEADER_SIZE).Ptr;
	        content_index += GLB_HEADER_SIZE;

		    if (header.magic != GLB_MAGIC)
            {
                return .Err(.GLTFError(GLTF_Error(.Bad_GLB_Magic, "parse")));
            }

		    if (header.version < GLTF_MIN_VERSION)
            {
		        return .Err(.GLTFError(GLTF_Error(.Unsupported_Version, "parse")));
            }

            // GLB file format expects 1 JSON chunk right after header
            GLB_Chunk_Header json_header = *(GLB_Chunk_Header*)file_content.GetRange(content_index, content_index + GLB_CHUNK_HEADER_SIZE).Ptr;
            if (json_header.type != Types.CHUNK_TYPE_JSON)
            {
                return .Err(.GLTFError(GLTF_Error(.Wrong_Chunk_Type, "parse", GLTF_Param_Error() { name = "JSON Chunk" })));
            }

	        content_index += GLB_CHUNK_HEADER_SIZE;
	        json_data = file_content.GetRange(content_index, content_index + uint32(json_header.length));
	        content_index += uint32(json_header.length);
	    }

        Encoding endcoding = Encoding.ASCII;
        String jsonStr = new String();
        if (endcoding.DecodeToUTF8(json_data, jsonStr) case .Err(let err))
        {
            String errStr = new String();
            err.ToString(errStr);
            return .Err(.GLTFError(GLTF_Error(.Cant_Read_File, "parse", GLTF_Param_Error() { name = errStr })));
        }
	    Json.JsonTree jsonTree = new Json.JsonTree();
        let res = Json.Json.ReadJson(jsonStr, jsonTree);
        delete jsonStr;
	    retdata.json_value = jsonTree.root;

	    if (res case .Err(let json_err))
        {
	        return .Err(.JsonError(JSON_Error(json_err, jsonTree)));
	    }

        if (retdata.json_value case .Object(let keyObj))
        {
    	    if (asset_parse(keyObj) case .Ok(let asset))
            {
                retdata.asset = asset;
            }
       
            if (accessors_parse(keyObj) case .Ok(let accessors))
            {
                retdata.accessors = accessors;
            }
    
            if (animations_parse(keyObj) case .Ok(let animations))
            {
                retdata.animations = animations;
            }
    
            if (buffers_parse(keyObj, opt.gltf_dir) case .Ok(let buffers))
            {
                retdata.buffers = buffers;
            }
    
            if (buffer_views_parse(keyObj) case .Ok(let bufferViews))
            {
                retdata.buffer_views = bufferViews;
            }
    
            if (cameras_parse(keyObj) case .Ok(let cameras))
            {
                retdata.cameras = cameras;
            }
    
            if (images_parse(keyObj, opt.gltf_dir) case .Ok(let images))
            {
                retdata.images = images;
            }
    
            if (materials_parse(keyObj) case .Ok(let materials))
            {
                retdata.materials = materials;
            }
    
            if (meshes_parse(keyObj) case .Ok(let meshes))
            {
                retdata.meshes = meshes;
            }
    
            if (nodes_parse(keyObj) case .Ok(let nodes))
            {
                retdata.nodes = nodes;
            }
    
            if (samplers_parse(keyObj) case .Ok(let samplers))
            {
                retdata.samplers = samplers;
            }
    	    
            if (scenes_parse(keyObj) case .Ok(let scenes))
            {
                retdata.scenes = scenes;
            }
    
            if (skins_parse(keyObj) case .Ok(let skins))
            {
                retdata.skins = skins;
            }
    
            if (textures_parse(keyObj) case .Ok(let textures))
            {
                retdata.textures = textures;
            }
    
            retdata.extensions_used = extensions_names_parse(keyObj, Types.EXTENSIONS_USED_KEY);
    
            retdata.extensions_required = extensions_names_parse(keyObj, Types.EXTENSIONS_REQUIRED_KEY);

            if (TryGetNum(keyObj, Types.SCENE_KEY, let scene))
            {
                retdata.scene = (int)scene;
            }
        
            if (keyObj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
            {
                retdata.extensions = extensions;
            }
            if (keyObj.TryGetValue(Types.EXTRAS_KEY, let extras))
            {
                retdata.extras = extras;
            }
        }

        delete jsonTree;

	    // Load remaining binary chunks.
	    for (int buf_idx = 0;
            opt.is_glb && buf_idx < retdata.buffers.Count && int(content_index) < file_content.Count;
            buf_idx += 1)
        {
	        GLB_Chunk_Header chunk_header = *(GLB_Chunk_Header*)file_content.GetRange(content_index, content_index + GLB_CHUNK_HEADER_SIZE).Ptr;
	        content_index += GLB_CHUNK_HEADER_SIZE;

            retdata.buffers[buf_idx].uri =
                .Byte(file_content.GetRange(content_index));
	        content_index += uint32(chunk_header.length);
	    }

	    return retdata;
	}

	// It is safe to pass null here
	public void unload(ref GLTFData data)
    {
	    if (data == null)
        {
	        return;
	    }

	    data.json_value = .Null;
	    accessors_free(data.accessors);
	    animations_free(data.animations);
	    buffers_free(data.buffers);
	    buffer_views_free(data.buffer_views);
	    cameras_free(data.cameras);
	    images_free(data.images);
	    materials_free(data.materials);
	    meshes_free(data.meshes);
	    nodes_free(data.nodes);
        samplers_free(data.samplers);
	    scenes_free(data.scenes);
	    skins_free(data.skins);
	    textures_free(data.textures);
	    extensions_names_free(data.extensions_required);
	    extensions_names_free(data.extensions_used);
	}

	/*
	    Utilitiy procedures
	*/
	private static String[] extensions_names_parse(Json.JsonObjectData object, String name)
    {
	    if (TryGetArr(object, name, let arr))
        {
            String[] retstr = new String[arr.Count];
            for (int i = 0; i < arr.Count; i++)
            {
                retstr[i] = new String(arr[i].AsString());
            }

            return retstr;
        }
        
        return new String[0];
	}

	private static void extensions_names_free(String[] names)
    {
	    if (names.Count == 0)
        {
	        return;
	    }
	    delete names;
	}

	private static Uri? uri_parse(Uri? uri, String gltf_dir)
    {
	    if (uri == null)
        {
	        return uri;
	    }
	    if (uri.Value case .Byte(var bytes))
        {
            bytes.Clear();
	        return uri;
	    }

	    if (uri.Value case .Str(String str_data))
        {
    	    int type_idx = str_data.IndexOf(':');
	        if (type_idx == -1)
            {
                List<uint8> bytes = new List<uint8>();
                // Check if this is possible file and if so load it
                let res = File.ReadAll(scope $"{gltf_dir}/{str_data}", bytes);
                if (res case .Err)
                {
                    return uri;
                }
    	        
	            return Uri.Byte(bytes);
	        }

    	    String type = scope String(str_data.Substring(type_idx));
    	    if (type == "data")
            {
    	        int encoding_start_idx = str_data.IndexOf(';') + 1;
    	        if (encoding_start_idx == 0)
                {
        	        return uri;
        	    }
    	        int encoding_end_idx = str_data.IndexOf(',');
    	        if (encoding_end_idx == -1)
                {
    	            return uri;
    	        }
        
    	        String encoding = scope String(str_data.Substring(encoding_start_idx, encoding_end_idx));
    
    	        if (encoding == "base64")
                {
                    List<uint8> rdata = new List<uint8>();
                    Base64.Decode(scope String(str_data.Substring(encoding_end_idx + 1)), rdata);
    	            return Uri.Byte(*(uint8[]*)rdata.Ptr);
    	        }
            }
        }

	    return uri;
	}

	private static void uri_free(Uri uri)
    {
	    if (uri case .Byte(var bytes))
        {
            bytes.Clear();
        }    
	}

	private static void warning_unexpected_data(String proc_name, String key, Json.JsonElement val, int idx = 0)
    {
        String err = scope String("WARINING: Unexpected data in proc: {} at index: {}\nKey: {}, value: {}\n",
            proc_name, scope String(idx), scope String(key), val.AsString());
        Debug.WriteLine(err);
        Console.WriteLine(err);
	}

	/*
	    Asseet parsing
	*/
	private static Result<Asset, DError> asset_parse(Json.JsonObjectData object)
    {
        Asset res = Asset();
	    if (TryGetObj(object, Types.ASSET_KEY, let lookingDict))
        {
            bool version_found = false;
            if (TryGetStr(lookingDict, "copyright", let copyright))
            {
                res.copyright = new String(copyright);
            }

            if (TryGetStr(lookingDict, "generator", let generator))
            {
                res.generator = new String(generator);
            }

            if (TryGetNum(lookingDict, "minVersion", let minVersion))
            {
                version_found = true;
                res.min_version = (float)minVersion;
                res.version = (float)minVersion;
            }

            if (TryGetNum(lookingDict, "version", let version))
            {
                version_found = true;
                res.version = (float)version;
            }

            if (lookingDict.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
            {
                res.extensions = extensions;
            }

            if (lookingDict.TryGetValue(Types.EXTRAS_KEY, let extras))
            {
                res.extras = extras;
            }

            if (!version_found)
            {
                return .Err(.GLTFError(GLTF_Error(.Missing_Required_Parameter, "asset_parse", GLTF_Param_Error(){ name = "version" })));
            }
            else if(res.version > GLTF_MIN_VERSION)
            {
                return .Err(.GLTFError(GLTF_Error(.Unsupported_Version, "asset_parse")));
            }

            return .Ok(res);
        }

        return .Err(.GLTFError(GLTF_Error(.JSON_Missing_Section, "asset_parse", GLTF_Param_Error(){ name = Types.ASSET_KEY })));
	}

	/*
	    Accessors parsing
	*/
	private static Result<Accessor[], DError> accessors_parse(Json.JsonObjectData object)
    {
	    if (TryGetArr(object, Types.ACCESSORS_KEY, let accessor_array))
        {
    	    Accessor[] res = new Accessor[(int)accessor_array.Count];

            for (int idx = 0; idx < accessor_array.Count; idx++)
            {
                if (accessor_array[idx] case .Object(let access))
                {
        	        bool component_type_set = false;
                    bool count_set = false;
                    bool type_set = false;
        
        	        if (TryGetNum(access, "bufferView", let bufferView))
                    {
        	            res[idx].buffer_view = (int)bufferView;
                    }
    
                    if (TryGetNum(access, "byteOffset", let byteOffset))
                    {
                        res[idx].byte_offset = (int)byteOffset;
                    }
    
                    if (TryGetNum(access, "componentType", let componentTypeset))
                    {
                        res[idx].component_type = (Component_Type)componentTypeset;
                        component_type_set = true;
                    }
    
                    if (TryGetBool(access, "normalized", let normalized))
                    {
                        res[idx].normalized = normalized;
                    }
    
                    if (TryGetNum(access, "count", let count))
                    {
                        res[idx].count = (int)count;
                        count_set = true;
                    }
    
                    if (TryGetStr(access, "type", let type))
                    {
    	                // Required
    	                switch (scope String(type))
                        {
        	                case "SCALAR":
        	                    res[idx].type = .Scalar;
        	                    type_set = true;
                                break;
        
        	                case "VEC2":
        	                    res[idx].type = .Vector2;
        	                    type_set = true;
                                break;
        
        	                case "VEC3":
        	                    res[idx].type = .Vector3;
        	                    type_set = true;
                                break;
        
        	                case "VEC4":
        	                    res[idx].type = .Vector4;
        	                    type_set = true;
                                break;
        
        	                case "MAT2":
        	                    res[idx].type = .Matrix2;
        	                    type_set = true;
                                break;
        
        	                case "MAT3":
        	                    res[idx].type = .Matrix3;
        	                    type_set = true;
                                break;
        
        	                case "MAT4":
        	                    res[idx].type = .Matrix4;
        	                    type_set = true;
                                break;
        
        	                default:
        	                    return .Err(.GLTFError(GLTF_Error(
                                    .Invalid_Type, "accessors_parse", GLTF_Param_Error(){ name = new String(type), index = idx})));
        	            }
                    }
    
    	            if (TryGetArr(access, "max", let maxArr))
                    {
    	                float[16] maxes = .(0,);
    	                for (int i = 0; i < maxArr.Count && i < 16; i++)
                        {
                            if (maxArr[i] case .Number(double num))
                            {
                                maxes[i] = (float)num;
                            }
    	                }
    	                res[idx].max = maxes;
                    }

                    if (TryGetArr(access, "min", let minArr))
                    {
                        float[16] mines = .(0,);
                        for (int i = 0; i < minArr.Count && i < 16; i++)
                        {
                            if (minArr[i] case .Number(double num))
                            {
                                mines[i] = (float)num;
                            }
                        }
                        res[idx].min = mines;
                    }

                    if (access.TryGetValue("sparse", let sparse))
                    {
                        res[idx].sparse = accessor_sparse_parse(sparse);
                    }

                    if (TryGetStr(access, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

                    if (access.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (access.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
                

        	        if (!component_type_set)
                    {
        	            return .Err(.GLTFError(GLTF_Error(
                            .Missing_Required_Parameter, "accessors_parse", GLTF_Param_Error(){ name = "componentType", index = idx })));
        	        }
        	        if (!count_set)
                    {
        	            return .Err(.GLTFError(GLTF_Error(
                            .Missing_Required_Parameter, "accessors_parse", GLTF_Param_Error(){ name = "count", index = idx})));
        	        }
        	        if (!type_set)
                    {
        	            return .Err(.GLTFError(GLTF_Error(
                            .Missing_Required_Parameter, "accessors_parse", GLTF_Param_Error(){ name = "type", index = idx})));
        	        }
                }
    	    }
    
    	    return .Ok(res);
        }

        return .Err(.GLTFError(GLTF_Error(
            .JSON_Missing_Section, "accessors_parse", GLTF_Param_Error(){ name = Types.ACCESSORS_KEY })));
	}

	private static void accessors_free(Accessor[] accessors)
    {
	    if (accessors.Count == 0)
        {
	        return;
	    }

	    for (let accessor in accessors)
        {
	        if (accessor.sparse == null)
            {
	            continue;
	        }
	        if (accessor.sparse.Value.indices.Count > 0)
            {
	            delete accessor.sparse.Value.indices;
	        }
	        if (accessor.sparse.Value.values.Count > 0)
            {
	            delete accessor.sparse.Value.values;
	        }
	    }
	    delete accessors;
	}

	private static Result<Accessor_Sparse, DError> accessor_sparse_parse(Json.JsonElement object)
    {
        if (object case .Object(let obj))
        {
            Accessor_Sparse res = Accessor_Sparse();
		    if (obj.TryGetValue("indices", let indices))
            {
	            // Required
	            res.indices = sparse_indices_parse(indices);
            }

		    if (obj.TryGetValue( "values", let values))
            {
		        // Required
		        res.values = sparse_values_parse(values);
            }

		    if (obj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
            {
		        res.extensions = extensions;
            }

		    if (obj.TryGetValue(Types.EXTRAS_KEY, let extras))
            {
                res.extras = extras;
		    }

		    if (res.indices.Count == 0)
            {
		        return .Err(.GLTFError(GLTF_Error(
                    .Missing_Required_Parameter, "accessor_sparse_parse", GLTF_Param_Error(){ name = "indices" })));
		    }
		    if (res.values.Count == 0)
            {
		        return .Err(.GLTFError(GLTF_Error(
                    .Missing_Required_Parameter, "accessor_sparse_parse", GLTF_Param_Error(){ name = "values"})));
		    }

		    return .Ok(res);
		}

        return .Err(.GLTFError(GLTF_Error(
            .JSON_Missing_Section, "accessor_sparse_parse", GLTF_Param_Error(){ name = "accessor_sparse" })));
    }

	private static Result<Accessor_Sparse_Indices[], DError> sparse_indices_parse(Json.JsonElement jsonArr)
    {
        if (jsonArr case .Array(let accessorArray))
        {
            Accessor_Sparse_Indices[] res = new Accessor_Sparse_Indices[(int)accessorArray.Count];
            for (int i = 0; i < accessorArray.Count; i++)
            {
	            bool buffer_view_set = false;
                bool component_type_set = false;

                if (accessorArray[i] case .Object(let indice))
                {
	                if (TryGetNum(indice, "bufferView", let bufferView))
                    {
    	                // Required
    	                res[i].buffer_view = (int)bufferView;
    	                buffer_view_set = true;
                    }

                    if (TryGetNum(indice, "byteOffset", let byteOffset))
                    {
                        // Default 0
                        res[i].byte_offset = (int)byteOffset;
                    }

                    if (TryGetNum(indice, "componentType", let componentType))
                    {
                        // Required
                        res[i].component_type = (Component_Type)componentType;
	                    component_type_set = true;
                    }

                    if (indice.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[i].extensions = extensions;
                    }

                    if (indice.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[i].extras = extras;
                    }
                }

    	        if (!buffer_view_set)
                {
    	            return .Err(.GLTFError(GLTF_Error(
	                    .Missing_Required_Parameter,
	                    "sparse_indices_parse",
	                    GLTF_Param_Error(){ name = "bufferView", index = i }
	                )));
    	        }
    	        if (!component_type_set)
                {
    	            return .Err(.GLTFError(GLTF_Error(
    	                .Missing_Required_Parameter,
    	                "sparse_indices_parse",
    	                GLTF_Param_Error(){ name = "componentType", index = i }
    	            )));
    	        }
            }

            return .Ok(res);
	    }

        return .Ok(new Accessor_Sparse_Indices[0]);
	}

	private static Result<Accessor_Sparse_Values[], DError> sparse_values_parse(Json.JsonElement jsonArr)
    {
        if (jsonArr case .Array(let accessorArray))
        {
            Accessor_Sparse_Values[] res = new Accessor_Sparse_Values[accessorArray.Count];
            for (int i = 0; i < accessorArray.Count; i++)
            {
                bool buffer_view_set = false;

                if (accessorArray[i] case .Object(let value))
                {
                    if (TryGetNum(value, "bufferView", let  bufferView))
                    {
                        // Required
                        res[i].buffer_view = (int)bufferView;
                        buffer_view_set = true;
                    }

                    if (TryGetNum(value, "byteOffset", let byteOffset))
                    {
                        // Default 0
                        res[i].byte_offset = (int)byteOffset;
                    }

                    if (value.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[i].extensions = extensions;
                    }

                    if (value.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[i].extras = extras;
                    }
		        }

                if (!buffer_view_set)
                {
                    return .Err(.GLTFError(GLTF_Error(
                        .Missing_Required_Parameter,
                        "sparse_values_parse",
                        GLTF_Param_Error(){ name = "bufferView", index = i }
                    )));
                }
		    }

            return .Ok(res);
		}

        return .Ok(new Accessor_Sparse_Values[0]);
    }

	/*
	    Animations parsing
	*/
	private static Result<Animation[], DError> animations_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.ANIMATIONS_KEY, let animations_array))
        {
            Animation[] res = new Animation[animations_array.Count];
		    for (int i = 0; i < animations_array.Count; i++)
            {
		        if (animations_array[i] case .Object(let ani))
                {
		            if (TryGetArr(ani, "channels", let parseChannels))
                    {
                        if (animation_channels_parse(parseChannels) case .Ok(let channels))
                        {
                            res[i].channels = channels;
                        }
                    }

                    if (TryGetArr(ani, "samplers", let samplersObj))
                    {
                        if (animation_samplers_parse(samplersObj) case .Ok(let samplers))
                        {
                            res[i].samplers = samplers;
                        }
                    }

                    if (TryGetStr(ani, "name", let  name))
                    {
                        res[i].name = new String(name);
                    }

		            if (ani.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[i].extensions = extensions;
                    }

		            if (ani.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
		                res[i].extras = extras;
		            }
		        }

		        if (res[i].channels.Count == 0)
                {
		            return .Err(.GLTFError(GLTF_Error(
                        .Missing_Required_Parameter, "animations_parse", GLTF_Param_Error(){ name = "channels", index = i })));
		        }
		        if (res[i].samplers.Count == 0)
                {
		            return .Err(.GLTFError(GLTF_Error(
                        .Missing_Required_Parameter, "animations_parse", GLTF_Param_Error(){ name = "samplers", index = i })));
		        }
		    }

            return .Ok(res);
		}

        return .Ok(new Animation[0]);
    }

	private static void animations_free(Animation[] animations)
    {
	    if (animations.Count == 0)
        {
	        return;
	    }
	    for (let animation in animations)
        {
	        if (animation.channels.Count > 0)
            {
	            delete animation.channels;
	        }
	        if (animation.samplers.Count > 0)
            {
	            delete animation.samplers;
	        }
	    }
	    delete animations;
	}
	
	private static Result<Animation_Channel[], DError> animation_channels_parse(List<Json.JsonElement> objArr)
    {
		Animation_Channel[] res = new Animation_Channel[objArr.Count];

		for (int i = 0; i < objArr.Count; i++)
        {
		    bool sampler_set = false;
            bool target_set = false;

            if (objArr[i] case .Object(let chan))
            {
                if (TryGetNum(chan, "sampler", let sampler))
                {
                    res[i].sampler = (int)sampler;
                    sampler_set = true;
                }

                if (TryGetObj(chan, "target", let targetlookup))
                {
                    if (animation_channel_target_parse(targetlookup) case .Ok(let target))
                    {
                        res[i].target = target;
                        target_set = true;
                    }
                }

                if (chan.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                {
                    res[i].extensions = extensions;
                }
    
                if (chan.TryGetValue(Types.EXTRAS_KEY, let extras))
                {
                    res[i].extras = extras;
                }
            }
		        
	        if (!sampler_set)
            {    
	            return .Err(.GLTFError(GLTF_Error(
                    .Missing_Required_Parameter, "animation_channels_parse", GLTF_Param_Error(){ name = "sampler", index = i })));
	        }
	        if (!target_set)
            {
	            return .Err(.GLTFError(GLTF_Error(
                    .Missing_Required_Parameter, "animation_channels_parse", GLTF_Param_Error(){ name = "target", index = i })));
	        }
		}

        return .Ok(res);
    }

	private static Result<Animation_Channel_Target, DError> animation_channel_target_parse(Json.JsonObjectData obj)
    {
		bool path_set = false;
        Animation_Channel_Target res = Animation_Channel_Target();

		if (TryGetNum(obj, "node", let node))
        {
            res.node = (int)node;
        }

        if (TryGetStr(obj, "path", let path))
        {
            path_set = true;

            switch (scope String(path))
            {
                case "translation":
                    res.path = .Translation;
                    break;

                case "rotation":
                    res.path = .Rotation;
                    break;

                case "scale":
                    res.path = .Scale;
                    break;

                case "weights":
                    res.path = .Weights;
                    break;

                default:
                    path_set = false;
                    break;
            }
        }

        if (obj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
        {
            res.extensions = extensions;
        }

        if (obj.TryGetValue(Types.EXTRAS_KEY, let extras))
        {
            res.extras = extras;
        }

	    if (!path_set)
        {
	        return .Err(.GLTFError(GLTF_Error(.Missing_Required_Parameter, "animation_channel_target_parse", GLTF_Param_Error(){ name = "path"})));
	    }

	    return .Ok(res);
	}

	private static Result<Animation_Sampler[], DError> animation_samplers_parse(List<Json.JsonElement> objArr)
    {
        Animation_Sampler[] res = new Animation_Sampler[objArr.Count];

        for (int idx = 0; idx < objArr.Count; idx++)
        {
		    bool input_set = false;
            bool output_set = false;

            if (objArr[idx] case .Object(let obj))
            {
    		    if (TryGetNum(obj, "input", let input))
                {
	                // Required
	                res[idx].input = (int)input;
	                input_set = true;
                }

                if (TryGetStr(obj, "interpolation", let interpolation))
		        {
	                // Default Linear(0)
	                switch (scope String(interpolation))
                    {
		                case "LINEAR":
		                    res[idx].interpolation = .Linear;
                            break;

		                case "STEP":
		                    res[idx].interpolation = .Step;
                            break;

		                case "CUBICSPLINE":
		                    res[idx].interpolation = .Cubic_Spline;
                            break;

		                default:
		                    return .Err(.GLTFError(GLTF_Error(
                                .Invalid_Type, "animation_samplers_parse", GLTF_Param_Error(){ name = new String(interpolation), index = idx })));
		            }
                }

	            
    		    if (TryGetNum(obj, "output", let output))
                {    
	                // Required
	                res[idx].output = (int)output;
	                output_set = true;
                }

	            if (obj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                {
                    res[idx].extensions = extensions;
                }

                if (obj.TryGetValue(Types.EXTRAS_KEY, let extras))
                {
                    res[idx].extras = extras;
                }
		    }

	        if (!input_set)
            {
	            return .Err(.GLTFError(
                    GLTF_Error(.Missing_Required_Parameter, "animation_samplers_parse", GLTF_Param_Error(){ name = "input", index = idx })));
	        }
	        if (!output_set)
            {
	            return .Err(.GLTFError(
                    GLTF_Error(.Missing_Required_Parameter, "animation_samplers_parse", GLTF_Param_Error(){ name = "output", index = idx })));
		    }
        }

        return res;
    }

	private static Result<Buffer[], DError> buffers_parse(Json.JsonObjectData obj, String gltf_dir)
    {
        if (TryGetArr(obj, Types.BUFFERS_KEY, let buffers_array))
		{
            Buffer[] res = new Buffer[buffers_array.Count];

		    for (int idx = 0; idx < buffers_array.Count; idx++)
            {
		        bool byte_length_set = false;

                if (buffers_array[idx] case .Object(let bufObj))
                {
                    if (TryGetNum(bufObj, "byteLength", let byte_length))
                    {
		                // Required
		                res[idx].byte_length = (int)byte_length;
		                byte_length_set = true;
                    }

		            if (TryGetStr(bufObj, "name", let name))
                    {
		                res[idx].name = new String(name);
                    }

                    if (TryGetStr(bufObj, "uri", let uri))
                    {
                        res[idx].uri = uri_parse(Uri.Str(new String(uri)), gltf_dir).Value;
                    }

		            if (bufObj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (bufObj.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }

		        if (!byte_length_set)
                {
		            return .Err(.GLTFError(GLTF_Error(
		                .Missing_Required_Parameter,
		                "buffers_parse",
		                GLTF_Param_Error(){ name = "byteLength", index = idx }
		            )));
		        }
		    }

            return .Ok(res);
        }

	    return .Ok(new Buffer[0]);
	}

	private static void buffers_free(Buffer[] buffers)
    {
	    if (buffers.Count == 0)
        {
	        return;
	    }
	    for (let buffer in buffers)
        {
	        uri_free(buffer.uri);
	    }
	    delete buffers;
	}

	/*
	    Buffer Views parsing
	*/
	private static Result<Buffer_View[], DError> buffer_views_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.BUFFER_VIEWS_KEY, let views_array))
        {
            Buffer_View[] res = new Buffer_View[views_array.Count];
		    for (int idx = 0; idx < views_array.Count; idx++)
            {
                bool buffer_set = false;
                bool byte_length_set = false;

                if (views_array[idx] case .Object(let viewObj))
                {
    		        if (TryGetNum(viewObj, "buffer", let buffer))
                    {
                        // Required
                        res[idx].buffer = (int)buffer;
                        buffer_set = true;
                    }
    
    		        if (TryGetNum(viewObj, "byteLength", let byteLength))
                    {    
    	                // Required
    	                res[idx].byte_length = (int)byteLength;
    	                byte_length_set = true;
                    }
    
    		        if (TryGetNum(viewObj, "byteOffset", let byteOffset))
                    {
    		            res[idx].byte_offset = (int)byteOffset;
                    }
    
    		        if (TryGetNum(viewObj, "byteStride", let byteStride))
                    {    
    		            res[idx].byte_stride = (int)byteStride;
                    }
    
    		        if (TryGetStr(viewObj, "name", let name))
                    {
    		            res[idx].name = new String(name);
                    }
    
    		        if (TryGetNum(viewObj, "target", let target))
                    {
    		            res[idx].target = (Buffer_Type_Hint)target;
                    }
    
    		        if (viewObj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (viewObj.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
                }

		        if (!buffer_set)
                {
		            return .Err(.GLTFError(GLTF_Error(
                        .Missing_Required_Parameter, "buffer_views_parse", GLTF_Param_Error(){ name = "buffer", index = idx })));
		        }
		        if (!byte_length_set)
                {
		            return .Err(.GLTFError(GLTF_Error(
		                    .Missing_Required_Parameter,
		                    "buffer_views_parse",
		                    GLTF_Param_Error(){ name = "byteLength", index = idx })));
		        }
		    }

            return .Ok(res);
        }

	    return .Ok(new Buffer_View[0]);
	}

	private static void buffer_views_free(Buffer_View[] views)
    {
	    if (views.Count == 0)
        {
	        return;
	    }
	    delete views;
	}

	/*
	    Cameras parsing
	*/
	private static Result<Camera[], DError> cameras_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.CAMERAS_KEY, let cameras_array))
        {
            Camera[] res = new Camera[cameras_array.Count];
		    for (int idx = 0; idx < cameras_array.Count; idx++)
            {
		        if (cameras_array[idx] case .Object(let camobj))
                {
		            if (TryGetStr(camobj, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

		            if (TryGetObj(camobj, "orthographic", let orthographic))
                    {
                        if (orthographic_camera_parse(orthographic) case .Ok(let orthoType))
                        {
                            res[idx].type = .Orthographic(orthoType);
                        }
                    }

		            if (TryGetObj(camobj, "perspective", let perspective))
                    {
                        if (perspective_camera_parse(perspective) case .Ok(let perspType))
                        {
		                    res[idx].type = .Perspective(perspType);
                        }
                    }

		            if (camobj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (camobj.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }

		        if (res[idx].type == .Null)
                {
		            return .Err(.GLTFError(GLTF_Error(
                        .Missing_Required_Parameter, "cameras_parse", GLTF_Param_Error(){ name = "type", index = idx })));
		        }
		    }

             return .Ok(res);
        }

	    return .Ok(new Camera[0]);
	}

	private static void cameras_free(Camera[] cameras)
    {
	    if (cameras.Count == 0)
        {
	        return;
	    }
	    delete cameras;
	}

	private static Result<Orthographic_Camera, DError> orthographic_camera_parse(Json.JsonObjectData parseObject)
    {
        Orthographic_Camera res = Orthographic_Camera();

		if (TryGetNum(parseObject, "xmag", let xmag))
        {
            // Required
            res.xmag = (float)xmag;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(
                .Missing_Required_Parameter, "orthographic_camera_parse", GLTF_Param_Error(){ name = "xmag" })));
        }

		if (TryGetNum(parseObject, "ymag", let ymag))
        {
            // Required
            res.ymag = (float)ymag;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(
                .Missing_Required_Parameter, "orthographic_camera_parse", GLTF_Param_Error(){ name = "ymag" })));
        }

		if (TryGetNum(parseObject, "zfar", let zfar))
        {
            // Required
            res.zfar = (float)zfar;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(
                .Missing_Required_Parameter, "orthographic_camera_parse", GLTF_Param_Error(){ name = "zfar" })));
        }

		if (TryGetNum(parseObject, "znear", let znear))
        {
            // Required
            res.znear = (float)znear;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(
                .Missing_Required_Parameter, "orthographic_camera_parse", GLTF_Param_Error(){ name = "znear" })));
        }

		if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
        {
            res.extensions = extensions;
        }

        if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
        {
            res.extras = extras;
        }

	    return .Ok(res);
	}

	private static Result<Perspective_Camera, DError> perspective_camera_parse(Json.JsonObjectData parseObject)
    {
        Perspective_Camera res = Perspective_Camera();

		if (TryGetNum(parseObject, "aspectRatio", let aspectRatio))
        {
		    res.aspect_ratio = (float)aspectRatio;
        }

		if (TryGetNum(parseObject, "yfov", let yfov))
        {
            // Required
            res.yfov = (float)yfov;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(
	            .Missing_Required_Parameter, "orthographic_camera_parse", GLTF_Param_Error(){ name = "yfov" })));
        }    

        if (TryGetNum(parseObject, "zfar", let zfar))
        {
            // Required
            res.zfar = (float)zfar;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(
                .Missing_Required_Parameter, "orthographic_camera_parse", GLTF_Param_Error(){ name = "zfar" })));
        }

        if (TryGetNum(parseObject, "znear", let znear))
        {
            // Required
            res.znear = (float)znear;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(
                .Missing_Required_Parameter, "orthographic_camera_parse", GLTF_Param_Error(){ name = "znear" })));
        }

        if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
        {
            res.extensions = extensions;
        }

        if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
        {
            res.extras = extras;
        }

	    return res;
	}

	/*
	    Images parsing
	*/
	private static Result<Image[], DError> images_parse(Json.JsonObjectData object, String gltf_dir)
    {
	    if (TryGetArr(object, Types.IMAGES_KEY, let obj_array))
        {
            Image[] res = new Image[obj_array.Count];
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
		        if (obj_array[idx] case .Object(let parseObject))
                {    
		            if (TryGetNum(parseObject, "bufferView", let bufferView))
                    {
		                res[idx].buffer_view = (int)bufferView;
                    }

		            if (TryGetStr(parseObject, "mimeType", let mimeType))
                    {    
		                switch (scope String(mimeType))
                        {
    		                case "image/jpeg":
    		                    res[idx].type = .JPEG;
                                break;
    		                case "image/png":
    		                    res[idx].type = .PNG;
                                break;
    		                default:
    		                    return .Err(.GLTFError(GLTF_Error(
                                    .Unknown_File_Type, "images_parse", GLTF_Param_Error(){ name = new String(mimeType), index = idx })));
    		            }
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

                    if (TryGetStr(parseObject, "uri", let uri))
                    {
                        res[idx].uri = uri_parse(Uri.Str(new String(name)), gltf_dir).Value;
                    }

		            if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }
		    }
            return .Ok(res);
        }

	    return .Ok(new Image[0]);
	}

	private static void images_free(Image[] images)
    {
	    if (images.Count == 0)
        {
	        return;
	    }
	    for (let image in images)
        {
	        uri_free(image.uri);
	    }
	    delete images;
	}

	/*
	    Materials parsing
	*/
	private static Result<Material[], DError> materials_parse(Json.JsonObjectData object)
    {
	    if (TryGetArr(object, Types.MATERIALS_KEY, let obj_array))
        {
            Material[] res = new Material[obj_array.Count];
		    for (int idx = 0; idx < obj_array.Count; idx++)
            {
                if (obj_array[idx] case .Object(let parseObject))
                {
		            res[idx].alpha_cutoff = 0.5f;

		            if (TryGetStr(parseObject, "alphaMode", let alphaMode))
                    {
		                // Default Opaque
		                switch (scope String(alphaMode))
                        {
    		                case "OPAQUE":
    		                    res[idx].alpha_mode = .Opaque;
                                break;
    		                case "MASK":
    		                    res[idx].alpha_mode = .Mask;
                                break;
    		                case "BLEND":
    		                    res[idx].alpha_mode = .Blend;
                                break;
    		                default:
    		                    return .Err(.GLTFError(GLTF_Error(
                                    .Invalid_Type, "materials_parse", GLTF_Param_Error(){ name = new String(alphaMode), index = idx })));
		                }
                    }

		            if (TryGetNum(parseObject, "alphaCutoff", let alphaCutoff))
                    {
		                // Default 0.5
		                res[idx].alpha_cutoff = (float)alphaCutoff;
                    }

		            if (TryGetBool(parseObject, "doubleSided", let doublesided))
                    {
		                // Default false
		                res[idx].double_sided = doublesided;
                    }

		            if (TryGetArr(parseObject, "emissiveFactor", let emissiveFactor))
                    {
    	                // Default [0, 0, 0]
    	                for (int j = 0; j < emissiveFactor.Count && j < 3; j++)
                        {
                            if (emissiveFactor[j] case .Number(double ef))
                            {
                                res[idx].emissive_factor[j] = (float)ef;
                            }
    	                }
                    }

		            if (TryGetObj(parseObject, "emissiveTexture", let emissiveTexture))
                    {
		                res[idx].emissive_texture = texture_info_parse(emissiveTexture, .Regular);
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
		                res[idx].name = new String(name);
                    }

		            if (TryGetObj(parseObject, "normalTexture", let normalTexture))
                    {
		                res[idx].normal_texture = texture_info_parse(normalTexture, .Normal);
                    }

		            if (TryGetObj(parseObject, "occlusionTexture", let occlusionTexture))
                    {
		                res[idx].occlusion_texture = texture_info_parse(occlusionTexture, .Occlusion);
                    }

		            if (TryGetObj(parseObject, "pbrMetallicRoughness", let pbrMetallicRoughness))
                    {
		                res[idx].metallic_roughness = pbr_metallic_roughness_parse(pbrMetallicRoughness);
                    }

		            if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }
		    }
            return .Ok(res);
        }

	    return .Ok(new Material[0]);
	}

	private static void  materials_free(Material[] materials)
    {
	    if (materials.Count == 0)
        {
	        return;
	    }
	    delete materials;
	}

	private static Result<Material_Metallic_Roughness, DError> pbr_metallic_roughness_parse(Json.JsonObjectData parseObject)
    {
        Material_Metallic_Roughness res = Material_Metallic_Roughness();
	    res.base_color_factor = .(1, 1, 1, 1);
	    res.metallic_factor = 1;
	    res.roughness_factor = 1;

		if (TryGetArr(parseObject, "baseColorFactor", let baseColorFactor))
        {
            // Default [ 1, 1, 1, 1 ]
            for (int i = 0; i < baseColorFactor.Count && i < 4; i++)
            {
                if (baseColorFactor[i] case .Number(double clrFactor))
                {
                    res.base_color_factor[i] = (float)clrFactor;
                }
            }
        }

        if (TryGetObj(parseObject, "baseColorTexture", let baseColorTexture))
        {
            res.base_color_texture = texture_info_parse(baseColorTexture, .Regular);
        }

        if (TryGetNum(parseObject, "metallicFactor", let metallicFactor))
        {
            // Default 1
            res.metallic_factor = (float)metallicFactor;
        }

        if (TryGetNum(parseObject, "roughnessFactor", let roughnessFactor))
        {
            // Default 1
            res.roughness_factor = (float)roughnessFactor;
        }

        if (TryGetObj(parseObject, "metallicRoughnessTexture", let metallicRoughnessTexture))
        {
            res.metallic_roughness_texture = texture_info_parse(metallicRoughnessTexture, .Regular);
        }

		if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
        {
            res.extensions = extensions;
        }

        if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
        {
            res.extras = extras;
        }

        return res;
    }

    private static Result<Texture_Info, DError> texture_info_parse(Json.JsonObjectData parseObject, TextureType textureType)
    {
        Texture_Info res = Texture_Info();

        res.textureType = textureType;

        if (TryGetNum(parseObject, "index", let index))
        {
            //Required
            res.index = (int)index;
        }
        else
        {
            return .Err(.GLTFError(GLTF_Error(.Missing_Required_Parameter, "texture_info_parse", GLTF_Param_Error(){ name = "index" })));
        }    

        if (TryGetNum(parseObject, "texCoord", let texCoord))
        {
            // Default 0
            res.tex_coord = (int)texCoord;
        }

        if (TryGetNum(parseObject, "scale", let scale))
        {
            // Default 1
            res.scale = (float)scale;
        }

        if (TryGetNum(parseObject, "strength", let strength))
        {
            // Default 1
            res.strength = (float)strength;
        }

        if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
        {
            res.extensions = extensions;
        }

        if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
        {
            res.extras = extras;
        }

        return res;
    }

	/*
	    Meshes parsing
	*/
	private static Result<Mesh[], DError> meshes_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.MESHES_KEY, let obj_array))
        {
            Mesh[] res = new Mesh[obj_array.Count];
		    for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res[idx].primitives = new Mesh_Primitive[0];

                if (obj_array[idx] case .Object(let parseObject))
                {
		            if (TryGetStr(parseObject, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

		            if (TryGetArr(parseObject, "primitives", let parsePrimitives))
                    {
		                // Required
                        if (mesh_primitives_parse(parsePrimitives) case .Ok(let primitives))
                        {
                            res[idx].primitives = primitives;
                        }
                    }

		            if (TryGetArr(parseObject, "weights", let weights))
                    {
		                res[idx].weights = new float[(int)weights.Count];
		                for (int j = 0; j < weights.Count; j++)
                        {
                            if (weights[j] case .Number(double w))
                            {
		                        res[idx].weights[j] = (float)w;
                            }
		                }
                    }

		            if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }

		        if (res[idx].primitives.Count == 0)
                {
		            return .Err(.GLTFError(GLTF_Error(.Missing_Required_Parameter,
	                    "meshes_parse",
	                    GLTF_Param_Error(){ name = "primitives", index = idx }
	                )));
		        }
		    }

            return .Ok(res);
        }
	    return .Ok(new Mesh[0]);
    }

	private static void meshes_free(Mesh[] meshes)
    {
	    if (meshes.Count == 0)
        {
	        return;
	    }
	    for (let mesh in meshes)
        {
	        if (mesh.weights.Count > 0)
            {
	            delete mesh.weights;
	        }
	        mesh_primitives_free(mesh.primitives);
	    }
	    delete meshes;
	}

	private static Result<Mesh_Primitive[], DError> mesh_primitives_parse(List<Json.JsonElement> array)
    {
		Mesh_Primitive[] res = new Mesh_Primitive[array.Count];

		for (int idx = 0; idx < array.Count; idx++)
        {
		    res[idx].mode = .Triangles;
            res[idx].attributes = new Dictionary<int, int>();

		    if (array[idx] case .Object(let parseObject))
            {
                if (TryGetArr(parseObject, "attributes", let attributes))
                {
	                // Required
	                for (int j = 0; j < attributes.Count; j++)
                    {
                        if (attributes[j] case .Number(let attrs))
                        {
		                    res[idx].attributes.Add(j, (int)attrs);
                        }
		            }
                }

		        if (TryGetNum(parseObject, "indices", let indices))
                {    
		            res[idx].indices = (int)indices;
                }

		        if (TryGetNum(parseObject, "material", let material))
                {    
		            res[idx].material = (int)material;
                }

	            if (TryGetNum(parseObject, "mode", let mode))
                {    
	                // Default Triangles(4)
	                res[idx].mode = (Mesh_Primitive_Mode)mode;
                }

	            if (TryGetObj(parseObject,  "targets", let targets))
                {
                    // TODO!
                }

		        if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                {
                    res[idx].extensions = extensions;
                }

                if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                {
                    res[idx].extras = extras;
                }
		    }

            if (res[idx].attributes.Count == 0)
            {
                return .Err(.GLTFError(GLTF_Error(
                    .Missing_Required_Parameter,
                    "mesh_primitives_parse",
                    GLTF_Param_Error(){ name = "attributes", index = idx }
                )));
            }
        }

	    return .Ok(res);
	}

	private static void mesh_primitives_free(Mesh_Primitive[] primitives)
    {
	    if (primitives.Count == 0)
        {
	        return;
	    }
	    for (let primitive in primitives)
        {
	        if (primitive.attributes.Count > 0)
            {
	            delete primitive.attributes;
	        }
	    }
	    delete primitives;
	}

	/*
	    Nodes parsing
	*/
	private static Result<Node[], DError> nodes_parse(Json.JsonObjectData object)
    {
	    if (TryGetArr(object, Types.NODES_KEY, let obj_array))
        {
            Node[] res = new Node[obj_array.Count];
		    for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res[idx].mat = .(1,);
                res[idx].rotation = .(1, 1, 1, 1);
                res[idx].scale = .(1, 1, 1);

                if (obj_array[idx] case .Object(let parseObject))
                {
		            if (TryGetNum(parseObject, "camera", let camid))
                    {
		                res[idx].camera = (int)camid;
                    }

		            if (TryGetArr(parseObject, "children", let children))
                    {
                        res[idx].children = new int[children.Count];
		                for (int j = 0; j < children.Count; j++)
                        {
                            if (children[j] case .Number(double c))
                            {
                                res[idx].children[j] = (int)c;
                            }
		                }
                    }

		            if (TryGetArr(parseObject, "matrix", let matrix))
                    {
		                for (int j = 0; j < matrix.Count && j < 16; j++)
                        {
                            if (matrix[j] case .Number(double m))
                            {
        		                // Default identity matrix
        		                // Matrices are stored in column-major order. Odin matrices are indexed like this [row, col]
        		                res[idx].mat[j] = (float)m;
                            }
		                }
                    }

		            if (TryGetNum(parseObject, "mesh", let meshid))
                    {
		                res[idx].mesh = (int)meshid;
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
		                res[idx].name = new String(name);
                    }

                    if (TryGetArr(parseObject, "scale", let scale))
                    {
                        for (int j = 0; j < scale.Count && j < 3; j++)
                        {
                            if (scale[j] case .Number(double s))
                            {
		                        res[idx].scale[j] = (float)s;
                            }
		                }
                    }

		            if (TryGetNum(parseObject, "skin", let skin))
                    {
		                res[idx].skin = (int)skin;
                    }

                    if (TryGetArr(parseObject, "rotation", let rotation))
                    {
                        for (int j = 0; j < rotation.Count && j < 4; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (rotation[j] case .Number(double r))
                            {
		                        res[idx].rotation[j] = (float)r;
                            }
		                }
                    }

                    if (TryGetArr(parseObject, "translation", let translation))
                    {
                        for (int j = 0; j < translation.Count && j < 3; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (translation[j] case .Number(double t))
                            {
                                res[idx].translation[j] = (float)t;
                            }
                        }
                    }

                    if (TryGetArr(parseObject, "weights", let weights))
                    {
                        res[idx].weights = new float[weights.Count];
                        for (int j = 0; j < weights.Count; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (weights[j] case .Number(double w))
                            {
                                res[idx].weights[j] = (float)w;
                            }
                        }
                    }

		            if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }
		    }
            return .Ok(res);
        }

	    return .Ok(new Node[0]);
	}

	private static void nodes_free(Node[] nodes)
    {
	    if (nodes.Count == 0)
        {
	        return;
	    }
	    for (let node in nodes)
        {
	        if (node.children.Count > 0)
            {
	            delete node.children;
	        }
	        if (node.weights.Count > 0)
            {
	            delete node.weights;
	        }
	    }
	    delete nodes;
	}

	/*
	    Samplers parsing
	*/
	private static Result<Sampler[], DError> samplers_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.SAMPLERS_KEY, let obj_array))
        {
            Sampler[] res = new Sampler[obj_array.Count];
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res[idx].wrapS = .Repeat;
	            res[idx].wrapT = .Repeat;

                if (obj_array[idx] case .Object(let parseObject))
                {
		            if (TryGetNum(parseObject, "magFilter", let magFilter))
                    {
		                res[idx].mag_filter = (Magnification_Filter)magFilter;
                    }

		            if (TryGetNum(parseObject, "minFilter", let minFilter))
                    {
		                res[idx].min_filter = (Minification_Filter)minFilter;
                    }

		            if (TryGetNum(parseObject, "wrapS", let wrapS))
                    {
		                // Default Repeat(10497)
		                res[idx].wrapS = (Wrap_Mode)wrapS;
                    }

		            if (TryGetNum(parseObject, "wrapT", let wrapT))
                    {
		                // Default Repeat(10497)
		                res[idx].wrapT = (Wrap_Mode)wrapT;
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
		                res[idx].name = new String(name);
                    }

		            if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }
		    }
            return .Ok(res);
        }

	    return .Ok(new Sampler[0]);
	}

	private static void samplers_free(Sampler[] samplers)
    {
	    if (samplers.Count == 0)
        {
	        return;
	    }
	    delete samplers;
	}

	/*
	    Scenes parsing
	*/
	private static Result<Scene[], DError> scenes_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.SCENES_KEY, let obj_array))
        {
            Scene[] res = new Scene[obj_array.Count];
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                if (obj_array[idx] case .Object(let parseObject))
                {
                    if (TryGetArr(parseObject, "nodes", let nodes))
                    {
                        res[idx].nodes = new int[nodes.Count];
                        for (int j = 0; j < nodes.Count; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (nodes[j] case .Number(double n))
                            {
                                res[idx].nodes[j] = (int)n;
                            }
                        }
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

                    if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }
		    }

            return .Ok(res);
        }

	    return .Ok(new Scene[0]);
	}

	private static void scenes_free(Scene[] scenes)
    {
	    if (scenes.Count == 0)
        {
	        return;
	    }
	    for (let scene in scenes)
        {
	        if (scene.nodes.Count > 0)
            {
	            delete scene.nodes;
	        }
	    }
	    delete scenes;
	}

	/*
	    Skins parsing
	*/
	private static Result<Skin[], DError> skins_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.SKINS_KEY, let obj_array))
        {
            Skin[] res = new Skin[obj_array.Count];
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                if (obj_array[idx] case .Object(let parseObject))
                {
		            if (TryGetNum(parseObject, "inverseBindMatrices", let inverseBindMatrices))
                    {
		                res[idx].inverse_bind_matrices = (int)inverseBindMatrices;
                    }

                    if (TryGetArr(parseObject, "joints", let joints))
                    {
                        res[idx].joints = new int[joints.Count];
                        for (int j = 0; j < joints.Count; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (joints[j] case .Number(double joint))
                            {
                                res[idx].joints[j] = (int)joint;
                            }
                        }
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
		                res[idx].name = new String(name);
                    }

		            if (TryGetNum(parseObject, "skeleton", let skeleton))
                    {
		                res[idx].skeleton = (int)skeleton;
                    }

		            if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }

		        if (res[idx].joints.Count == 0)
                {
		            return .Err(.GLTFError(GLTF_Error(
                        .Missing_Required_Parameter, "skins_parse", GLTF_Param_Error(){ name = "joints", index = idx })));
		        }
		    }
            return .Ok(res);
        }

	    return .Ok(new Skin[0]);
	}

	private static void skins_free(Skin[] skins)
    {
	    if (skins.Count == 0)
        {
	        return;
	    }
	    for (let skin in skins)
        {
	        if (skin.joints.Count > 0)
            {
	            delete skin.joints;
	        }
	    }
	    delete skins;
	}

	/*
	    Textures parsing
	*/
	private static Result<Texture[], DError> textures_parse(Json.JsonObjectData object)
    {
        if (TryGetArr(object, Types.TEXTURES_KEY, let obj_array))
        {
            Texture[] res = new Texture[obj_array.Count];
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                if (obj_array[idx] case .Object(let parseObject))
                {
		            if (TryGetNum(parseObject, "sampler", let sampler))
                    {
		                res[idx].sampler = (int)sampler;
                    }

		            if (TryGetNum(parseObject, "source", let source))
                    {
		                res[idx].source = (int)source;
                    }

                    if (TryGetStr(parseObject, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

                    if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }
		        }
		    }
            return .Ok(res);
        }

	    return .Ok(new Texture[0]);
	}

	private static void textures_free(Texture[] textures)
    {
        if (textures.Count == 0)
        {
            return;
        }
        delete textures;
    }

    private static bool TryGetObj(
        Json.JsonObjectData ele, String key, out Json.JsonObjectData obj)
    {
        if (ele.TryGetValue(key, let immeditary))
        {
            if (immeditary case .Object(out obj))
            {
                return true;
            }
        }
        obj = default;
        return false;
    }

    private static bool TryGetArr(
        Json.JsonObjectData ele, String key, out List<Json.JsonElement> arr)
    {
        if (ele.TryGetValue(key, let immeditary))
        {
            if (immeditary case .Array(out arr))
            {
                return true;
            }
        }
        arr = default;
        return false;
    }

    private static bool TryGetStr(
        Json.JsonObjectData ele, String key, out StringView str)
    {
        if (ele.TryGetValue(key, let immeditary))
        {
            if (immeditary case .String(out str))
            {
                return true;
            }
        }
        str = default;
        return false;
    }

    private static bool TryGetNum(
        Json.JsonObjectData ele, String key, out double num)
    {
        if (ele.TryGetValue(key, let immeditary))
        {
            if (immeditary case .Number(out num))
            {
                return true;
            }
            else if (immeditary case .String(let str))
            {
                num = Double.Parse(str);
                return true;
            }
        }
        num = default;
        return false;
    }

    private static bool TryGetBool(
        Json.JsonObjectData ele, String key, out bool boolVal)
    {
        if (ele.TryGetValue(key, let immeditary))
        {
            if (immeditary case .Bool(out boolVal))
            {
                return true;
            }
        }
        boolVal = default;
        return false;
    }
}
