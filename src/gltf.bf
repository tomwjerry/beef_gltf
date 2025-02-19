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
	public static Result<void, GLTFError> load_from_file(String file_name, GLTFData gltfData)
    {
        if (!File.Exists(file_name))
        {
            return .Err(GLTFError(Error_Type.No_File, "load_from_file", file_name));
        }

        List<uint8> file_content = scope List<uint8>();

        let res = File.ReadAll(file_name, file_content);
	    if (res case .Err)
        {
            return .Err(GLTFError(Error_Type.Cant_Read_File, "load_from_file", file_name));
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
    	        return parse(file_content, options, gltfData);

    	    case ".glb":
    	        options.is_glb = true;
    	        return parse(file_content, options, gltfData);

    	    default:
                return .Err(GLTFError(Error_Type.Unknown_File_Type, "load_from_file", file_name));
    	}
    }

	public static Result<void, GLTFError> parse(List<uint8> file_content, Options opt, GLTFData gltfdata)
    {
        // Seems always be true? Why delete content before use? 
	    if (opt.delete_content)
        {
	        //file_content.Clear();
	    }

	    if (file_content.Count < GLB_HEADER_SIZE)
        {
	        return .Err(GLTFError(.Data_Too_Short, "parse"));
	    }

	    Span<uint8> json_data = file_content;
	    int content_index = 0;

	    if (opt.is_glb)
        {
	        GLB_Header header = *(GLB_Header*)file_content.GetRange(0, GLB_HEADER_SIZE).Ptr;
	        content_index += GLB_HEADER_SIZE;

		    if (header.magic != GLB_MAGIC)
            {
                return .Err(GLTFError(.Bad_GLB_Magic, "parse"));
            }

		    if (header.version < GLTF_MIN_VERSION)
            {
		        return .Err(GLTFError(.Unsupported_Version, "parse"));
            }

            // GLB file format expects 1 JSON chunk right after header
            GLB_Chunk_Header json_header = *(GLB_Chunk_Header*)file_content.GetRange(content_index, content_index + GLB_CHUNK_HEADER_SIZE).Ptr;
            if (json_header.type != Types.CHUNK_TYPE_JSON)
            {
                return .Err(GLTFError(Error_Type.Wrong_Chunk_Type, "parse", "JSON Chunk"));
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
            return .Err(GLTFError(.Cant_Read_File, "parse", errStr));
        }
	    Json.JsonTree jsonTree = new Json.JsonTree();
        let res = Json.Json.ReadJson(jsonStr, jsonTree);
        delete jsonStr;
	    gltfdata.json_value = jsonTree.root;

	    if (res case .Err(let json_err))
        {
	        return .Err(GLTFError(json_err, jsonTree));
	    }

        if (jsonTree.root case .Object(let keyObj))
        {
            List<GLTFError> errorList = scope List<GLTFError>();
            GLTFError err = GLTFError();
    	    if (asset_parse(keyObj, ref gltfdata.asset) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (accessors_parse(keyObj, ref gltfdata.accessors) case .Err(err))
            {
                errorList.Add(err);
            }
            
            if (animations_parse(keyObj, ref gltfdata.animations) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (buffers_parse(keyObj, opt.gltf_dir, ref gltfdata.buffers) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (buffer_views_parse(keyObj, ref gltfdata.buffer_views) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (cameras_parse(keyObj, ref gltfdata.cameras) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (images_parse(keyObj, opt.gltf_dir, ref gltfdata.images) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (materials_parse(keyObj, ref gltfdata.materials) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (meshes_parse(keyObj, ref gltfdata.meshes) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (nodes_parse(keyObj, ref gltfdata.nodes) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (samplers_parse(keyObj, ref gltfdata.samplers) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (scenes_parse(keyObj, ref gltfdata.scenes) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (skins_parse(keyObj, ref gltfdata.skins) case .Err(err))
            {
                errorList.Add(err);
            }
       
            if (textures_parse(keyObj, ref gltfdata.textures) case .Err(err))
            {
                errorList.Add(err);
            }

            extensions_names_parse(keyObj, Types.EXTENSIONS_USED_KEY, gltfdata.extensions_used);
    
            extensions_names_parse(keyObj, Types.EXTENSIONS_REQUIRED_KEY, gltfdata.extensions_required);

            if (TryGetNum(keyObj, Types.SCENE_KEY, let scene))
            {
                gltfdata.scene = (int)scene;
            }
        
            if (keyObj.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
            {
                gltfdata.extensions = extensions;
            }
            if (keyObj.TryGetValue(Types.EXTRAS_KEY, let extras))
            {
                gltfdata.extras = extras;
            }

            if (errorList.Count > 0)
            {
                return .Err(errorList[0]);
            }
        }

        delete jsonTree;

	    // Load remaining binary chunks.
	    for (int buf_idx = 0;
            opt.is_glb && buf_idx < gltfdata.buffers.Count && int(content_index) < file_content.Count;
            buf_idx += 1)
        {
	        GLB_Chunk_Header chunk_header = *(GLB_Chunk_Header*)file_content.GetRange(content_index, content_index + GLB_CHUNK_HEADER_SIZE).Ptr;
	        content_index += GLB_CHUNK_HEADER_SIZE;

            gltfdata.buffers[buf_idx].uri =
                .Byte(file_content.GetRange(content_index));
	        content_index += uint32(chunk_header.length);
	    }

	    return .Ok;
	}

	/*
	    Utilitiy procedures
	*/
	private static void extensions_names_parse(Json.JsonObjectData object, String name, List<String> extensions)
    {
	    if (TryGetArr(object, name, let arr))
        {
            for (int i = 0; i < arr.Count; i++)
            {
                extensions.Add(new String(arr[i].AsString()));
            }
        }
	}

	private static Uri uri_parse(Uri uri, String gltf_dir)
    {
	    if (uri case .Str(String str_data))
        {
    	    int type_idx = str_data.IndexOf(':');
	        if (type_idx == -1)
            {
                List<uint8> bytes = scope List<uint8>();
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
                    List<uint8> rdata = scope List<uint8>();
                    Base64.Decode(scope String(str_data.Substring(encoding_end_idx + 1)), rdata);
    	            return Uri.Byte(rdata);
    	        }
            }
        }

	    return uri;
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
	private static Result<void, GLTFError> asset_parse(Json.JsonObjectData object, ref Asset res)
    {
        res = Asset();
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
                return .Err(GLTFError(Error_Type.Missing_Required_Parameter, "asset_parse", "version"));
            }
            else if(res.version > GLTF_MIN_VERSION)
            {
                return .Err(GLTFError(Error_Type.Unsupported_Version, "asset_parse"));
            }

            return .Ok;
        }

        return .Err(GLTFError(Error_Type.JSON_Missing_Section, "asset_parse", Types.ASSET_KEY));
	}

	/*
	    Accessors parsing
	*/
	private static Result<void, GLTFError> accessors_parse(Json.JsonObjectData object, ref List<Accessor> res)
    {
	    if (TryGetArr(object, Types.ACCESSORS_KEY, let accessor_array))
        {
            for (int idx = 0; idx < accessor_array.Count; idx++)
            {
                res.Add(Accessor());
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
        	                    return .Err(GLTFError(
                                    .Invalid_Type, "accessors_parse", new String(type), idx));
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

                    if (TryGetObj(access, "sparse", let sparse))
                    {
                        if (sparse.TryGetValue("indices", let indices))
                        {
                            // Required
                            sparse_indices_parse(indices, ref res[idx].indices);
                        }

                        if (sparse.TryGetValue( "values", let values))
                        {
                            // Required
                            sparse_values_parse(values, ref res[idx].values);
                        }

                        if (sparse.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                        {
                            res[idx].accessorExtensions = extensions;
                        }

                        if (sparse.TryGetValue(Types.EXTRAS_KEY, let extras))
                        {
                            res[idx].accessorExtras = extras;
                        }

                        if (res[idx].indices.Count == 0)
                        {
                            return .Err(GLTFError(
                                .Missing_Required_Parameter, "accessor_sparse_parse", "indices"));
                        }
                        if (res[idx].values.Count == 0)
                        {
                            return .Err(GLTFError(
                                .Missing_Required_Parameter, "accessor_sparse_parse", "values"));
                        } 
                    }
                    else
                    {
                        return .Err(GLTFError(
	                        .JSON_Missing_Section, "accessor_sparse_parse", "accessor_sparse"));
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
        	            return .Err(GLTFError(
                            .Missing_Required_Parameter, "accessors_parse", "componentType", idx));
        	        }
        	        if (!count_set)
                    {
        	            return .Err(GLTFError(
                            .Missing_Required_Parameter, "accessors_parse", "count", idx));
        	        }
        	        if (!type_set)
                    {
        	            return .Err(GLTFError(
                            .Missing_Required_Parameter, "accessors_parse", "type", idx));
        	        }
                }
    	    }
    
    	    return .Ok;
        }

        return .Err(GLTFError(
            .JSON_Missing_Section, "accessors_parse", Types.ACCESSORS_KEY));
	}

	private static Result<void, GLTFError> sparse_indices_parse(Json.JsonElement jsonArr, ref List<Accessor_Sparse_Indices> res)
    {
        if (jsonArr case .Array(let accessorArray))
        {
            for (int i = 0; i < accessorArray.Count; i++)
            {
                res.Add(Accessor_Sparse_Indices());
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
    	            return .Err(GLTFError(
	                    .Missing_Required_Parameter,
	                    "sparse_indices_parse",
	                    "bufferView", i
	                ));
    	        }
    	        if (!component_type_set)
                {
    	            return .Err(GLTFError(
    	                .Missing_Required_Parameter,
    	                "sparse_indices_parse",
    	                "componentType", i
    	            ));
    	        }
            }
	    }

        return .Ok;
	}

	private static Result<void, GLTFError> sparse_values_parse(Json.JsonElement jsonArr, ref List<Accessor_Sparse_Values> res)
    {
        if (jsonArr case .Array(let accessorArray))
        {
            for (int i = 0; i < accessorArray.Count; i++)
            {
                res.Add(Accessor_Sparse_Values());
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
                    return .Err(GLTFError(
                        .Missing_Required_Parameter,
                        "sparse_values_parse",
                        "bufferView", i
                    ));
                }
		    }
		}

        return .Ok;
    }

	/*
	    Animations parsing
	*/
	private static Result<void, GLTFError> animations_parse(Json.JsonObjectData object, ref List<Animation> res)
    {
        if (TryGetArr(object, Types.ANIMATIONS_KEY, let animations_array))
        {
		    for (int i = 0; i < animations_array.Count; i++)
            {
                res.Add(Animation());
		        if (animations_array[i] case .Object(let ani))
                {
		            if (TryGetArr(ani, "channels", let parseChannels))
                    {
                        if (animation_channels_parse(parseChannels, ref res[i].channels) case .Err(let err))
                        {
                            return .Err(err);
                        }
                    }

                    if (TryGetArr(ani, "samplers", let samplersObj))
                    {
                        if (animation_samplers_parse(samplersObj, ref res[i].samplers) case .Err(let err))
                        {
                            return .Err(err);
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
		            return .Err(GLTFError(
                        .Missing_Required_Parameter, "animations_parse", "channels", i));
		        }
		        if (res[i].samplers.Count == 0)
                {
		            return .Err(GLTFError(
                        .Missing_Required_Parameter, "animations_parse", "samplers", i));
		        }
		    }
		}

        return .Ok;
    }
	
	private static Result<void, GLTFError> animation_channels_parse(List<Json.JsonElement> objArr, ref List<Animation_Channel> res)
    {
		for (int i = 0; i < objArr.Count; i++)
        {
            res.Add(Animation_Channel());
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
                    bool path_set = false;

                    if (TryGetNum(targetlookup, "node", let node))
                    {
                        res[i].node = (int)node;
                    }

                    if (TryGetStr(targetlookup, "path", let path))
                    {
                        path_set = true;

                        switch (scope String(path))
                        {
                            case "translation":
                                res[i].path = .Translation;
                                break;

                            case "rotation":
                                res[i].path = .Rotation;
                                break;

                            case "scale":
                                res[i].path = .Scale;
                                break;

                            case "weights":
                                res[i].path = .Weights;
                                break;

                            default:
                                path_set = false;
                                break;
                        }
                    }

                    if (targetlookup.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[i].targetExtensions = extensions;
                    }

                    if (targetlookup.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[i].targetExtras = extras;
                    }

                    if (!path_set)
                    {
                        return .Err(GLTFError(.Missing_Required_Parameter, "animation_channel_target_parse", "path"));
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
	            return .Err(GLTFError(
                    .Missing_Required_Parameter, "animation_channels_parse", "sampler", i));
	        }
	        if (!target_set)
            {
	            return .Err(GLTFError(
                    .Missing_Required_Parameter, "animation_channels_parse", "target", i));
	        }
		}

        return .Ok;
    }

	private static Result<void, GLTFError> animation_samplers_parse(List<Json.JsonElement> objArr, ref List<Animation_Sampler> res)
    {
        for (int idx = 0; idx < objArr.Count; idx++)
        {
            res.Add(Animation_Sampler());
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
		                    return .Err(GLTFError(
                                .Invalid_Type, "animation_samplers_parse", new String(interpolation), idx));
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
	            return .Err(
                    GLTFError(.Missing_Required_Parameter, "animation_samplers_parse", "input", idx));
	        }
	        if (!output_set)
            {
	            return .Err(GLTFError(.Missing_Required_Parameter, "animation_samplers_parse", "output", idx));
		    }
        }

        return .Ok;
    }

	private static Result<void, GLTFError> buffers_parse(Json.JsonObjectData obj, String gltf_dir, ref List<Buffer> res)
    {
        if (TryGetArr(obj, Types.BUFFERS_KEY, let buffers_array))
		{
		    for (int idx = 0; idx < buffers_array.Count; idx++)
            {
                res.Add(Buffer());
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
                        res[idx].uri = uri_parse(Uri.Str(scope String(uri)), gltf_dir);
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
		            return .Err(GLTFError(
		                .Missing_Required_Parameter,
		                "buffers_parse",
		                "byteLength",
                        idx
		            ));
		        }
		    }
        }

	    return .Ok;
	}

	/*
	    Buffer Views parsing
	*/
	private static Result<void, GLTFError> buffer_views_parse(Json.JsonObjectData object, ref List<Buffer_View> res)
    {
        if (TryGetArr(object, Types.BUFFER_VIEWS_KEY, let views_array))
        {
		    for (int idx = 0; idx < views_array.Count; idx++)
            {
                res.Add(Buffer_View());
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
		            return .Err(GLTFError(
                        .Missing_Required_Parameter, "buffer_views_parse", "buffer", idx));
		        }
		        if (!byte_length_set)
                {
		            return .Err(GLTFError(
                        .Missing_Required_Parameter,
                        "buffer_views_parse",
                        "byteLength", idx));
		        }
		    }
        }

	    return .Ok;
	}

	/*
	    Cameras parsing
	*/
	private static Result<void, GLTFError> cameras_parse(Json.JsonObjectData object, ref List<Camera> res)
    {
        if (TryGetArr(object, Types.CAMERAS_KEY, let cameras_array))
        {
		    for (int idx = 0; idx < cameras_array.Count; idx++)
            {
                res.Add(Camera());
		        if (cameras_array[idx] case .Object(let camobj))
                {
		            if (TryGetStr(camobj, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

		            if (TryGetObj(camobj, "orthographic", let orthographic))
                    {
                        Orthographic_Camera orthoType = Orthographic_Camera();
                        orthographic_camera_parse(orthographic, ref orthoType);
                        res[idx].type = .Orthographic(orthoType);
                    }

		            if (TryGetObj(camobj, "perspective", let perspective))
                    {
                        Perspective_Camera perspType = Perspective_Camera();
                        perspective_camera_parse(perspective, ref perspType);
                        res[idx].type = .Perspective(perspType);
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
		            return .Err(GLTFError(
                        .Missing_Required_Parameter, "cameras_parse", "type", idx));
		        }
		    }
        }

	    return .Ok;
	}

	private static Result<void, GLTFError> orthographic_camera_parse(Json.JsonObjectData parseObject, ref Orthographic_Camera res)
    {
		if (TryGetNum(parseObject, "xmag", let xmag))
        {
            // Required
            res.xmag = (float)xmag;
        }
        else
        {
            return .Err(GLTFError(
                .Missing_Required_Parameter, "orthographic_camera_parse", "xmag"));
        }

		if (TryGetNum(parseObject, "ymag", let ymag))
        {
            // Required
            res.ymag = (float)ymag;
        }
        else
        {
            return .Err(GLTFError(
                .Missing_Required_Parameter, "orthographic_camera_parse", "ymag"));
        }

		if (TryGetNum(parseObject, "zfar", let zfar))
        {
            // Required
            res.zfar = (float)zfar;
        }
        else
        {
            return .Err(GLTFError(
                .Missing_Required_Parameter, "orthographic_camera_parse", "zfar"));
        }

		if (TryGetNum(parseObject, "znear", let znear))
        {
            // Required
            res.znear = (float)znear;
        }
        else
        {
            return .Err(GLTFError(
                .Missing_Required_Parameter, "orthographic_camera_parse", "znear"));
        }

		if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
        {
            res.extensions = extensions;
        }

        if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
        {
            res.extras = extras;
        }

	    return .Ok;
	}

	private static Result<void, GLTFError> perspective_camera_parse(Json.JsonObjectData parseObject, ref Perspective_Camera res)
    {
        res = Perspective_Camera();

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
            return .Err(GLTFError(
	            .Missing_Required_Parameter, "orthographic_camera_parse", "yfov"));
        }    

        if (TryGetNum(parseObject, "zfar", let zfar))
        {
            // Required
            res.zfar = (float)zfar;
        }
        else
        {
            return .Err(GLTFError(
                .Missing_Required_Parameter, "orthographic_camera_parse", "zfar"));
        }

        if (TryGetNum(parseObject, "znear", let znear))
        {
            // Required
            res.znear = (float)znear;
        }
        else
        {
            return .Err(GLTFError(
                .Missing_Required_Parameter, "orthographic_camera_parse", "znear"));
        }

        if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
        {
            res.extensions = extensions;
        }

        if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
        {
            res.extras = extras;
        }

	    return .Ok;
	}

	/*
	    Images parsing
	*/
	private static Result<void, GLTFError> images_parse(Json.JsonObjectData object, String gltf_dir, ref List<Image> res)
    {
	    if (TryGetArr(object, Types.IMAGES_KEY, let obj_array))
        {
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Image());
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
    		                    return .Err(GLTFError(
                                    .Unknown_File_Type, "images_parse", new String(mimeType), idx));
    		            }
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

                    if (TryGetStr(parseObject, "uri", let uri))
                    {
                        res[idx].uri = uri_parse(Uri.Str(scope String(name)), gltf_dir);
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
        }

	    return .Ok;
	}

	/*
	    Materials parsing
	*/
	private static Result<void, GLTFError> materials_parse(Json.JsonObjectData object, ref List<Material> res)
    {
	    if (TryGetArr(object, Types.MATERIALS_KEY, let obj_array))
        {
		    for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Material());
                if (obj_array[idx] case .Object(let parseObject))
                {
		            res[idx].alpha_cutoff = 0.5f;
                    res[idx].metallic_base_color_factor = .(1, 1, 1, 1);
                    res[idx].metallic_factor = 1;
                    res[idx].metallic_roughness_factor = 1;

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
    		                    return .Err(GLTFError(
                                    .Invalid_Type, "materials_parse", new String(alphaMode), idx));
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
		                texture_info_parse(emissiveTexture, .Regular, ref res[idx].emissive_texture);
                    }

		            if (TryGetStr(parseObject, "name", let name))
                    {
		                res[idx].name = new String(name);
                    }

		            if (TryGetObj(parseObject, "normalTexture", let normalTexture))
                    {
		                texture_info_parse(normalTexture, .Normal, ref res[idx].normal_texture);
                    }

		            if (TryGetObj(parseObject, "occlusionTexture", let occlusionTexture))
                    {
		                texture_info_parse(occlusionTexture, .Occlusion, ref res[idx].occlusion_texture);
                    }

		            if (parseObject.TryGetValue(Types.EXTENSIONS_KEY, let extensions))
                    {
                        res[idx].extensions = extensions;
                    }

                    if (parseObject.TryGetValue(Types.EXTRAS_KEY, let extras))
                    {
                        res[idx].extras = extras;
                    }

                    if (TryGetObj(parseObject, "pbrMetallicRoughness", let pbrMetallicRoughness))
                    {
                		if (TryGetArr(pbrMetallicRoughness, "baseColorFactor", let baseColorFactor))
                        {
                            // Default [ 1, 1, 1, 1 ]
                            for (int i = 0; i < baseColorFactor.Count && i < 4; i++)
                            {
                                if (baseColorFactor[i] case .Number(double clrFactor))
                                {
                                    res[idx].metallic_base_color_factor[i] = (float)clrFactor;
                                }
                            }
                        }
                
                        if (TryGetObj(pbrMetallicRoughness, "baseColorTexture", let baseColorTexture))
                        {
                             texture_info_parse(baseColorTexture, .Regular, ref res[idx].metallic_base_color_texture);
                        }
                
                        if (TryGetNum(pbrMetallicRoughness, "metallicFactor", let metallicFactor))
                        {
                            // Default 1
                            res[idx].metallic_factor = (float)metallicFactor;
                        }
                
                        if (TryGetNum(pbrMetallicRoughness, "roughnessFactor", let roughnessFactor))
                        {
                            // Default 1
                            res[idx].metallic_roughness_factor = (float)roughnessFactor;
                        }
                
                        if (TryGetObj(pbrMetallicRoughness, "metallicRoughnessTexture", let metallicRoughnessTexture))
                        {
                             texture_info_parse(metallicRoughnessTexture, .Regular, ref res[idx].metallic_roughness_texture);
                        }
                
                		if (pbrMetallicRoughness.TryGetValue(Types.EXTENSIONS_KEY, let metallic_extensions))
                        {
                            res[idx].metallic_extensions = metallic_extensions;
                        }
                
                        if (pbrMetallicRoughness.TryGetValue(Types.EXTRAS_KEY, let metallic_extras))
                        {
                            res[idx].metallic_extras = metallic_extras;
                        }
                    }
                }
            }
        }

        return .Ok;
    }

    private static Result<void, GLTFError> texture_info_parse(Json.JsonObjectData parseObject, TextureType textureType, ref Texture_Info res)
    {
        res = Texture_Info();
        res.textureType = textureType;

        if (TryGetNum(parseObject, "index", let index))
        {
            //Required
            res.index = (int)index;
        }
        else
        {
            return .Err(GLTFError(.Missing_Required_Parameter, "texture_info_parse", "index"));
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

        return .Ok;
    }

	/*
	    Meshes parsing
	*/
	private static Result<void, GLTFError> meshes_parse(Json.JsonObjectData object, ref List<Mesh> res)
    {
        if (TryGetArr(object, Types.MESHES_KEY, let obj_array))
        {
		    for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Mesh());
                if (obj_array[idx] case .Object(let parseObject))
                {
		            if (TryGetStr(parseObject, "name", let name))
                    {
                        res[idx].name = new String(name);
                    }

		            if (TryGetArr(parseObject, "primitives", let parsePrimitives))
                    {
		                // Required
                        if (mesh_primitives_parse(parsePrimitives, ref res[idx].primitives) case .Err(let err))
                        {
                            return .Err(err);
                        }
                    }

		            if (TryGetArr(parseObject, "weights", let weights))
                    {
		                for (int j = 0; j < weights.Count; j++)
                        {
                            if (weights[j] case .Number(double w))
                            {
		                        res[idx].weights.Add((float)w);
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
		            return .Err(GLTFError(.Missing_Required_Parameter,
	                    "meshes_parse",
	                    "primitives", idx
	                ));
		        }
		    }
        }
	    return .Ok;
    }

	private static Result<void, GLTFError> mesh_primitives_parse(List<Json.JsonElement> array, ref List<Mesh_Primitive> res)
    {
		for (int idx = 0; idx < array.Count; idx++)
        {
            res.Add(Mesh_Primitive());
		    res[idx].mode = .Triangles;
            res[idx].attributes = new Dictionary<StringView, int>();

		    if (array[idx] case .Object(let parseObject))
            {
                if (TryGetObj(parseObject, "attributes", let attributes))
                {
	                // Required
	                for(let attr in attributes)
                    {
                        res[idx].attributes.Add(attr.key, (int)attr.value.AsNumber());
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
                return .Err(GLTFError(
                    .Missing_Required_Parameter,
                    "mesh_primitives_parse",
                    "attributes", idx
                ));
            }
        }

	    return .Ok;
	}

	/*
	    Nodes parsing
	*/
	private static Result<void, GLTFError> nodes_parse(Json.JsonObjectData object, ref List<Node> res)
    {
	    if (TryGetArr(object, Types.NODES_KEY, let obj_array))
        {
		    for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Node());
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
		                for (int j = 0; j < children.Count; j++)
                        {
                            if (children[j] case .Number(double c))
                            {
                                res[idx].children.Add((int)c);
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
                        for (int j = 0; j < weights.Count; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (weights[j] case .Number(double w))
                            {
                                res[idx].weights.Add((float)w);
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
        }

	    return .Ok;
	}

	/*
	    Samplers parsing
	*/
	private static Result<void, GLTFError> samplers_parse(Json.JsonObjectData object, ref List<Sampler> res)
    {
        if (TryGetArr(object, Types.SAMPLERS_KEY, let obj_array))
        {
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Sampler());
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
        }

	    return .Ok;
	}

	/*
	    Scenes parsing
	*/
	private static Result<void, GLTFError> scenes_parse(Json.JsonObjectData object, ref List<Scene> res)
    {
        if (TryGetArr(object, Types.SCENES_KEY, let obj_array))
        {
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Scene());
                if (obj_array[idx] case .Object(let parseObject))
                {
                    if (TryGetArr(parseObject, "nodes", let nodes))
                    {
                        for (int j = 0; j < nodes.Count; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (nodes[j] case .Number(double n))
                            {
                                res[idx].nodes.Add((int)n);
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
        }

	    return .Ok;
	}

	/*
	    Skins parsing
	*/
	private static Result<void, GLTFError> skins_parse(Json.JsonObjectData object, ref List<Skin> res)
    {
        if (TryGetArr(object, Types.SKINS_KEY, let obj_array))
        {
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Skin());
                if (obj_array[idx] case .Object(let parseObject))
                {
		            if (TryGetNum(parseObject, "inverseBindMatrices", let inverseBindMatrices))
                    {
		                res[idx].inverse_bind_matrices = (int)inverseBindMatrices;
                    }

                    if (TryGetArr(parseObject, "joints", let joints))
                    {
                        for (int j = 0; j < joints.Count; j++)
                        {
                            // Default [0, 0, 0, 1]
                            if (joints[j] case .Number(double joint))
                            {
                                res[idx].joints.Add((int)joint);
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
		            return .Err(GLTFError(
                        .Missing_Required_Parameter, "skins_parse", "joints", idx));
		        }
		    }
        }

	    return .Ok;
	}

	/*
	    Textures parsing
	*/
	private static Result<void, GLTFError> textures_parse(Json.JsonObjectData object, ref List<Texture> res)
    {
        if (TryGetArr(object, Types.TEXTURES_KEY, let obj_array))
        {
            for (int idx = 0; idx < obj_array.Count; idx++)
            {
                res.Add(Texture());
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
        }

	    return .Ok;
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
