namespace GLTFExample;

using System;
using System.Collections;
using System.Diagnostics;
using System.IO;

using SDL3.Raw;
using GLTF;

class ExampleUsage
{
	private static String BasePath;
	private static SDL_GPUDevice* gpu;
	private static SDL_Window* window;
	private static SDL_GPUGraphicsPipeline* Pipeline;
    private static SDL_GPUBuffer* IndexBuffer;
    private static SDL_GPUBuffer* PositionBuffer;

    private static uint32 indicesCount = 0;
    private static Vector3 CamPos = Vector3(0, 0, 4);
    
	public static void Main()
	{
		if (!SDL_Init(.SDL_INIT_VIDEO))
		{
			Console.WriteLine("Unable to initialize sdl3");
			Console.Read();
		}

		gpu = SDL_CreateGPUDevice(
			SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV |
			SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL |
			SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL,
			true,
			null);

		if (gpu == null)
		{
			Debug.WriteLine("{}", scope String(SDL_GetError()));
			Console.WriteLine("{}", scope String(SDL_GetError()));
			Debug.Break();
		}	

		window = SDL_CreateWindow("SDL3 - gLTF", 1366, 768, 0);

		if (window == null)
		{
			Console.WriteLine("Unable to create a window");
			Console.Read();
		}

		if (!SDL_ClaimWindowForGPUDevice(gpu, window))
		{
			Console.WriteLine("GPUClaimWindow failed");
			Console.Read();
		}

		BasePath = scope String(scope String(SDL_GetBasePath()), "../../../");

        GLTFData gltfData = scope GLTFData();
        List<GLTFGPUData> glftgpu = scope List<GLTFGPUData>();
        if (GLTF.LoadFromFile(scope String(BasePath, "Content/Meshes/BarramundiFish.gltf"), gltfData) case .Err)
        {
            return;
        }
        if (GLTFGPUData.ConvertToGPUData(gltfData, glftgpu) case .Err)
        {
            return;
        }

		// Create the shaders
		SDL_GPUShader* vertexShader = LoadShader(gpu, "example.vert", 0, 1, 0, 0);
		if (vertexShader == null)
		{
			Console.WriteLine("Failed to create vertex shader!");
			Console.Read();
		}

		SDL_GPUShader* fragmentShader = LoadShader(gpu, "SolidColor.frag", 0, 0, 0, 0);
		if (fragmentShader == null)
		{
			Console.WriteLine("Failed to create fragment shader!");
			Console.Read();
		}
		
		// Create the pipeline
		SDL_GPUColorTargetDescription[1] colorTargets;
		colorTargets[0].format = SDL_GetGPUSwapchainTextureFormat(gpu, window);

		SDL_GPUVertexBufferDescription[1] vertexBufferDesc;
		vertexBufferDesc[0].slot = 0;
		vertexBufferDesc[0].input_rate = SDL_GPUVertexInputRate.SDL_GPU_VERTEXINPUTRATE_VERTEX;
		vertexBufferDesc[0].instance_step_rate = 0;
		vertexBufferDesc[0].pitch = sizeof(PositionColorVertex);

		SDL_GPUVertexAttribute[3] vertexAttri;
		vertexAttri[0].buffer_slot = 0;
		vertexAttri[0].format = SDL_GPUVertexElementFormat.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3;
		vertexAttri[0].location = 0;
		vertexAttri[0].offset = 0;

        vertexAttri[1].buffer_slot = 0;
        vertexAttri[1].format = SDL_GPUVertexElementFormat.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4;
        vertexAttri[1].location = 1;
        vertexAttri[1].offset = sizeof(float) * 3;

		SDL_GPUGraphicsPipelineCreateInfo pipelineCreateInfo;
		pipelineCreateInfo.target_info.num_color_targets = 1;
		pipelineCreateInfo.target_info.color_target_descriptions = &colorTargets;
 		pipelineCreateInfo.vertex_input_state.num_vertex_buffers = 1;
		pipelineCreateInfo.vertex_input_state.vertex_buffer_descriptions = &vertexBufferDesc;
		pipelineCreateInfo.vertex_input_state.num_vertex_attributes = 2;
		pipelineCreateInfo.vertex_input_state.vertex_attributes = &vertexAttri;
		pipelineCreateInfo.primitive_type = SDL_GPUPrimitiveType.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
		pipelineCreateInfo.vertex_shader = vertexShader;
		pipelineCreateInfo.fragment_shader = fragmentShader;

		Pipeline = SDL_CreateGPUGraphicsPipeline(gpu, &pipelineCreateInfo);
		if (Pipeline == null)
		{
			Console.WriteLine("Failed to create pipeline!");
			Console.Read();
		}

		SDL_ReleaseGPUShader(gpu, vertexShader);
		SDL_ReleaseGPUShader(gpu, fragmentShader);

        uint32 vertexCount = (uint32)glftgpu[0].positions.Count;
        indicesCount = (uint32)glftgpu[0].indices.Count;

        // Position buffer
        SDL_GPUBufferCreateInfo vertexBufferInfo;
        vertexBufferInfo.usage = SDL_GPUBufferUsageFlags.SDL_GPU_BUFFERUSAGE_VERTEX;
        vertexBufferInfo.size = sizeof(PositionColorVertex) * vertexCount;
        PositionBuffer = SDL_CreateGPUBuffer(
        	gpu,
        	&vertexBufferInfo
        );

        // Index buffer
        SDL_GPUBufferCreateInfo indexBufferInfo;
        indexBufferInfo.usage = SDL_GPUBufferUsageFlags.SDL_GPU_BUFFERUSAGE_INDEX;
        indexBufferInfo.size = sizeof(uint16) * indicesCount;
        IndexBuffer = SDL_CreateGPUBuffer(
        	gpu,
        	&indexBufferInfo
        );

        // To get data into the vertex buffer, we have to use a transfer buffer
        SDL_GPUTransferBufferCreateInfo transferBufferInfo;
        transferBufferInfo.usage = SDL_GPUTransferBufferUsage.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
        transferBufferInfo.size = (sizeof(PositionColorVertex) * vertexCount) +
            (sizeof(uint16) * indicesCount);
        SDL_GPUTransferBuffer* transferBuffer = SDL_CreateGPUTransferBuffer(
        	gpu,
        	&transferBufferInfo
        );

        // Map buffers
        PositionColorVertex* transferBufferData = (PositionColorVertex*)SDL_MapGPUTransferBuffer(
        	gpu,
        	transferBuffer,
        	false
        );

        int i = 0;
        for (; i < glftgpu[0].positions.Count; i++) {
            transferBufferData[i] = PositionColorVertex(
                glftgpu[0].positions[i][0],
                glftgpu[0].positions[i][1],
                glftgpu[0].positions[i][2],
                1.0f,
                0.5f,
                0.7f,
                1.0f);

        }

        uint16* indexData = (uint16*) &transferBufferData[i];
        for (int j = 0; j < indicesCount; j++)
        {
           indexData[j] = glftgpu[0].indices[j];
        }

        SDL_UnmapGPUTransferBuffer(gpu, transferBuffer);

		// Upload the transfer data to the vertex buffer
		SDL_GPUCommandBuffer* uploadCmdBuf = SDL_AcquireGPUCommandBuffer(gpu);
		SDL_GPUCopyPass* copyPass = SDL_BeginGPUCopyPass(uploadCmdBuf);

        SDL_GPUTransferBufferLocation gpuVertexCopy;
        gpuVertexCopy.transfer_buffer = transferBuffer;
        gpuVertexCopy.offset = 0;

        SDL_GPUBufferRegion bufVertexReg;
        bufVertexReg.buffer = PositionBuffer;
        bufVertexReg.offset = 0;
        bufVertexReg.size = sizeof(PositionColorVertex) * vertexCount;

        SDL_UploadToGPUBuffer(
        	copyPass,
        	&gpuVertexCopy,
        	&bufVertexReg,
        	false
        );

        SDL_GPUTransferBufferLocation gpuIndexCopy;
        gpuIndexCopy.transfer_buffer = transferBuffer;
        gpuIndexCopy.offset = sizeof(PositionColorVertex) * vertexCount;

        SDL_GPUBufferRegion bufIndexReg;
        bufIndexReg.buffer = IndexBuffer;
        bufIndexReg.offset = 0;
        bufIndexReg.size = sizeof(uint16) * indicesCount;

        SDL_UploadToGPUBuffer(
        	copyPass,
        	&gpuIndexCopy,
        	&bufIndexReg,
        	false
        );

		SDL_EndGPUCopyPass(copyPass);
		SDL_SubmitGPUCommandBuffer(uploadCmdBuf);
		SDL_ReleaseGPUTransferBuffer(gpu, transferBuffer);

		bool quit = false;
		SDL_Event e = .();

		while(!quit)
		{
			while(SDL_PollEvent(&e))
			{
				if ((SDL_EventType)e.type == SDL_EventType.SDL_EVENT_QUIT)
				{	
					quit = true;
				}
                else if (e.key.key == SDL_Keycode.SDLK_LEFT)
				{
					CamPos.x -= 0.1f;
				}
				else if (e.key.key == SDL_Keycode.SDLK_RIGHT)
				{
					CamPos.x += 0.1f;
				}
				else if (e.key.key == SDL_Keycode.SDLK_DOWN)
				{
					CamPos.z += 0.1f;
				}
				else if (e.key.key == SDL_Keycode.SDLK_UP)
				{
					CamPos.z -= 0.1f;
				}
			}

			Draw();
		}

		SDL_ReleaseGPUGraphicsPipeline(gpu, Pipeline);
		SDL_ReleaseGPUBuffer(gpu, PositionBuffer);
        SDL_ReleaseGPUBuffer(gpu, IndexBuffer);

        ClearAndDeleteItems!(glftgpu);

		SDL_ReleaseWindowFromGPUDevice(gpu, window);
		SDL_DestroyWindow(window);
		SDL_DestroyGPUDevice(gpu);
		
		SDL_Quit();
	}

    static int Draw()
    {
        SDL_GPUCommandBuffer* cmdbuf = SDL_AcquireGPUCommandBuffer(gpu);
        if (cmdbuf == null)
        {
            SDL_Log("AcquireGPUCommandBuffer failed: %s", SDL_GetError());
            return -1;
        }

        SDL_GPUTexture* swapchainTexture = null;

        if (!SDL_WaitAndAcquireGPUSwapchainTexture(cmdbuf, window, &swapchainTexture, null, null))
    	{
            SDL_Log("WaitAndAcquireGPUSwapchainTexture failed: %s", SDL_GetError());
            return -1;
        }

    	if (swapchainTexture != null)
    	{
            Matrix4x4 proj = Matrix4x4_CreatePerspectiveFieldOfView(
                75.0f * (float)(3.14 / 180.0f),
                640.0f / 480.0f,
                0.01f,
                100.0f
            );
            Matrix4x4 view = Matrix4x4_CreateLookAt(
                CamPos,
                Vector3(0, 0, 0),
                Vector3(0, 1, 0)
            );

            Matrix4x4 viewProj = Matrix4x4_Multiply(view, proj);

    		SDL_GPUColorTargetInfo colorTargetInfo;
    		colorTargetInfo.texture = swapchainTexture;
    		colorTargetInfo.clear_color.r = 0.0f;
    		colorTargetInfo.clear_color.g = 0.0f;
    		colorTargetInfo.clear_color.b = 0.0f;
    		colorTargetInfo.clear_color.a = 1.0f;
    		colorTargetInfo.load_op = SDL_GPULoadOp.SDL_GPU_LOADOP_CLEAR;
    		colorTargetInfo.store_op = SDL_GPUStoreOp.SDL_GPU_STOREOP_STORE;

    		SDL_GPURenderPass* renderPass = SDL_BeginGPURenderPass(
    			cmdbuf,
    			&colorTargetInfo,
    			1,
    			null
    		);

    		SDL_BindGPUGraphicsPipeline(renderPass, Pipeline);
            SDL_GPUBufferBinding bufferVertexBind;
            bufferVertexBind.buffer = PositionBuffer;
            bufferVertexBind.offset = 0;
    		SDL_GPUBufferBinding bufferIndexBind;
    		bufferIndexBind.buffer = IndexBuffer;
    		bufferIndexBind.offset = 0;
            SDL_BindGPUVertexBuffers(renderPass, 0, &bufferVertexBind, 1);
    		SDL_BindGPUIndexBuffer(renderPass, &bufferIndexBind, SDL_GPUIndexElementSize.SDL_GPU_INDEXELEMENTSIZE_16BIT);
    		SDL_PushGPUVertexUniformData(cmdbuf, 0, &viewProj, sizeof(Matrix4x4));
            SDL_DrawGPUIndexedPrimitives(renderPass, indicesCount, 1, 0, 0, 0);

    		SDL_EndGPURenderPass(renderPass);
    	}

    	SDL_SubmitGPUCommandBuffer(cmdbuf);

    	return 0;
    }

	static SDL_GPUShader* LoadShader(
		SDL_GPUDevice* device,
		String shaderFilename,
		uint32 samplerCount,
		uint32 uniformBufferCount,
		uint32 storageBufferCount,
		uint32 storageTextureCount
	)
	{
		// Auto-detect the shader stage from the file name for convenience
		SDL_GPUShaderStage stage;
		if (shaderFilename.EndsWith(".vert"))
		{
			stage = SDL_GPUShaderStage.SDL_GPU_SHADERSTAGE_VERTEX;
		}
		else if (shaderFilename.EndsWith(".frag"))
		{
			stage = SDL_GPUShaderStage.SDL_GPU_SHADERSTAGE_FRAGMENT;
		}
		else
		{
			SDL_Log("Invalid shader stage!");
			return null;
		}

		String fullPath = scope String();
		SDL_GPUShaderFormat backendFormats = SDL_GetGPUShaderFormats(device);
		SDL_GPUShaderFormat format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_INVALID;
		String entrypoint;

		if (backendFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV != 0)
		{
			fullPath.AppendF("{}Content/Shaders/Compiled/SPIRV/{}.spv", BasePath, shaderFilename);
			format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV;
			entrypoint = "main";
		}
		else if (backendFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL != 0)
		{
			fullPath.AppendF("{}Content/Shaders/Compiled/MSL/{}.msl", BasePath, shaderFilename);
			format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL;
			entrypoint = "main0";
		}
		else if (backendFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL != 0)
		{
			fullPath.AppendF("{}Content/Shaders/Compiled/DXIL/{}.dxil", BasePath, shaderFilename);
			format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL;
			entrypoint = "main";
		}
		else
		{
			SDL_Log("%s", "Unrecognized backend shader format!");
			return null;
		}

		uint codeSize = 0;
		void* code = SDL_LoadFile(fullPath, &codeSize);
		if (code == null)
		{
			SDL_Log("Failed to load shader from disk! %s", fullPath);
			return null;
		}

		SDL_GPUShaderCreateInfo shaderInfo;
		shaderInfo.code = (uint8*)code;
		shaderInfo.code_size = codeSize;
		shaderInfo.entrypoint = entrypoint;
		shaderInfo.format = format;
		shaderInfo.stage = stage;
		shaderInfo.num_samplers = samplerCount;
		shaderInfo.num_uniform_buffers = uniformBufferCount;
		shaderInfo.num_storage_buffers = storageBufferCount;
		shaderInfo.num_storage_textures = storageTextureCount;

		SDL_GPUShader* shader = SDL_CreateGPUShader(device, &shaderInfo);
		if (shader == null)
		{
			SDL_Log("Failed to create shader!");
			SDL_free(code);
			return null;
		}

		SDL_free(code);
		return shader;
	}

	static SDL_GPUComputePipeline* CreateComputePipelineFromShader(
		SDL_GPUDevice* device,
		String shaderFilename,
		SDL_GPUComputePipelineCreateInfo *createInfo
	)
	{
		String fullPath = scope String();
		SDL_GPUShaderFormat backendFormats = SDL_GetGPUShaderFormats(device);
		SDL_GPUShaderFormat format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_INVALID;
		String entrypoint;

		if (backendFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV != 0)
		{
			fullPath.AppendF("{}Content/Shaders/Compiled/SPIRV/{}.spv", BasePath, shaderFilename);
			format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_SPIRV;
			entrypoint = "main";
		}
		else if (backendFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL != 0)
		{
			fullPath.AppendF("{}Content/Shaders/Compiled/MSL/{}.msl", BasePath, shaderFilename);
			format = SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_MSL;
			entrypoint = "main0";
		}
		else if (backendFormats & SDL_GPUShaderFormat.SDL_GPU_SHADERFORMAT_DXIL != 0)
		{
			fullPath.AppendF("{}Content/Shaders/Compiled/DXIL/{}.dxil", BasePath, shaderFilename);
			entrypoint = "main";
		}
		else
		{
			SDL_Log("%s", "Unrecognized backend shader format!");
			return null;
		}

		uint codeSize = 0;
		void* code = SDL_LoadFile(fullPath, &codeSize);
		if (code == null)
		{
			SDL_Log("Failed to load compute shader from disk! %s", fullPath);
			return null;
		}

		// Make a copy of the create data, then overwrite the parts we need
		SDL_GPUComputePipelineCreateInfo newCreateInfo = *createInfo;
		newCreateInfo.code = (uint8*)code;
		newCreateInfo.code_size = codeSize;
		newCreateInfo.entrypoint = entrypoint;
		newCreateInfo.format = format;

		SDL_GPUComputePipeline* pipeline = SDL_CreateGPUComputePipeline(device, &newCreateInfo);
		if (pipeline == null)
		{
			SDL_Log("Failed to create compute pipeline!");
			SDL_free(code);
			return null;
		}

		SDL_free(code);
		return pipeline;
	}

	static SDL_Surface* LoadImage(String imageFilename, int desiredChannels)
	{
		String fullPath = scope String()..AppendF("{}Content/{}", BasePath, imageFilename);
		SDL_Surface *result;
		SDL_PixelFormat format;

		result = SDL_LoadBMP(fullPath);
		if (result == null)
		{
			SDL_Log("Failed to load BMP: %s", SDL_GetError());
			return null;
		}

		if (desiredChannels == 4)
		{
			format = SDL_PixelFormat.SDL_PIXELFORMAT_ABGR8888;
		}
		else
		{
			SDL_Log("Unexpected desiredChannels");
			SDL_DestroySurface(result);
			return null;
		}
		if (result.format != format)
		{
			SDL_Surface *next = SDL_ConvertSurface(result, format);
			SDL_DestroySurface(result);
			result = next;
		}

		return result;
	}
	
	struct PositionColorVertex
	{
		public float x, y, z;
        public float r, g, b, a;

		public this()
		{
		    this = default;
		}

		public this(float x, float y, float z,
            float r, float g, float b, float a)
		{
			this.x = x;
			this.y = y;
			this.z = z;
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
		}
	}

	struct Matrix4x4
	{
		public float m11, m12, m13, m14;
		public float m21, m22, m23, m24;
		public float m31, m32, m33, m34;
		public float m41, m42, m43, m44;

		public this()
		{
		    this = default;
		}

		/* Constructor that takes values */
		public this(float m11, float m12, float m13, float m14,
					float m21, float m22, float m23, float m24,
					float m31, float m32, float m33, float m34,
					float m41, float m42, float m43, float m44)
		{
		    this.m11 = m11;
			this.m12 = m12;
			this.m13 = m13;
			this.m14 = m14;

			this.m21 = m21;
			this.m22 = m22;
			this.m23 = m23;
			this.m24 = m24;

			this.m31 = m31;
			this.m32 = m32;
			this.m33 = m33;
			this.m34 = m34;

			this.m41 = m41;
			this.m42 = m42;
			this.m43 = m43;
			this.m44 = m44;
		}
	}

	struct Vector3
	{
		public float x, y, z;

		public this()
		{
		    this = default;
		}

		/* Constructor that takes values */
		public this(float x, float y, float z)
		{
			this.x = x;
			this.y = y;
			this.z = z;
		}
	}

	// Matrix Math
	static Matrix4x4 Matrix4x4_Multiply(Matrix4x4 matrix1, Matrix4x4 matrix2)
	{
		Matrix4x4 result;

		result.m11 = (
			(matrix1.m11 * matrix2.m11) +
			(matrix1.m12 * matrix2.m21) +
			(matrix1.m13 * matrix2.m31) +
			(matrix1.m14 * matrix2.m41)
		);
		result.m12 = (
			(matrix1.m11 * matrix2.m12) +
			(matrix1.m12 * matrix2.m22) +
			(matrix1.m13 * matrix2.m32) +
			(matrix1.m14 * matrix2.m42)
		);
		result.m13 = (
			(matrix1.m11 * matrix2.m13) +
			(matrix1.m12 * matrix2.m23) +
			(matrix1.m13 * matrix2.m33) +
			(matrix1.m14 * matrix2.m43)
		);
		result.m14 = (
			(matrix1.m11 * matrix2.m14) +
			(matrix1.m12 * matrix2.m24) +
			(matrix1.m13 * matrix2.m34) +
			(matrix1.m14 * matrix2.m44)
		);
		result.m21 = (
			(matrix1.m21 * matrix2.m11) +
			(matrix1.m22 * matrix2.m21) +
			(matrix1.m23 * matrix2.m31) +
			(matrix1.m24 * matrix2.m41)
		);
		result.m22 = (
			(matrix1.m21 * matrix2.m12) +
			(matrix1.m22 * matrix2.m22) +
			(matrix1.m23 * matrix2.m32) +
			(matrix1.m24 * matrix2.m42)
		);
		result.m23 = (
			(matrix1.m21 * matrix2.m13) +
			(matrix1.m22 * matrix2.m23) +
			(matrix1.m23 * matrix2.m33) +
			(matrix1.m24 * matrix2.m43)
		);
		result.m24 = (
			(matrix1.m21 * matrix2.m14) +
			(matrix1.m22 * matrix2.m24) +
			(matrix1.m23 * matrix2.m34) +
			(matrix1.m24 * matrix2.m44)
		);
		result.m31 = (
			(matrix1.m31 * matrix2.m11) +
			(matrix1.m32 * matrix2.m21) +
			(matrix1.m33 * matrix2.m31) +
			(matrix1.m34 * matrix2.m41)
		);
		result.m32 = (
			(matrix1.m31 * matrix2.m12) +
			(matrix1.m32 * matrix2.m22) +
			(matrix1.m33 * matrix2.m32) +
			(matrix1.m34 * matrix2.m42)
		);
		result.m33 = (
			(matrix1.m31 * matrix2.m13) +
			(matrix1.m32 * matrix2.m23) +
			(matrix1.m33 * matrix2.m33) +
			(matrix1.m34 * matrix2.m43)
		);
		result.m34 = (
			(matrix1.m31 * matrix2.m14) +
			(matrix1.m32 * matrix2.m24) +
			(matrix1.m33 * matrix2.m34) +
			(matrix1.m34 * matrix2.m44)
		);
		result.m41 = (
			(matrix1.m41 * matrix2.m11) +
			(matrix1.m42 * matrix2.m21) +
			(matrix1.m43 * matrix2.m31) +
			(matrix1.m44 * matrix2.m41)
		);
		result.m42 = (
			(matrix1.m41 * matrix2.m12) +
			(matrix1.m42 * matrix2.m22) +
			(matrix1.m43 * matrix2.m32) +
			(matrix1.m44 * matrix2.m42)
		);
		result.m43 = (
			(matrix1.m41 * matrix2.m13) +
			(matrix1.m42 * matrix2.m23) +
			(matrix1.m43 * matrix2.m33) +
			(matrix1.m44 * matrix2.m43)
		);
		result.m44 = (
			(matrix1.m41 * matrix2.m14) +
			(matrix1.m42 * matrix2.m24) +
			(matrix1.m43 * matrix2.m34) +
			(matrix1.m44 * matrix2.m44)
		);

		return result;
	}

	static Matrix4x4 Matrix4x4_CreateRotationZ(float radians)
	{
		return Matrix4x4(
			 SDL_cosf(radians), SDL_sinf(radians), 0, 0,
			-SDL_sinf(radians), SDL_cosf(radians), 0, 0,
							 0, 				0, 1, 0,
							 0,					0, 0, 1
		);
	}

	static Matrix4x4 Matrix4x4_CreateTranslation(float x, float y, float z)
	{
		return Matrix4x4(
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			x, y, z, 1
		);
	}

	static Matrix4x4 Matrix4x4_CreateOrthographicOffCenter(
		float left,
		float right,
		float bottom,
		float top,
		float zNearPlane,
		float zFarPlane
	) {
		return Matrix4x4(
			2.0f / (right - left), 0, 0, 0,
			0, 2.0f / (top - bottom), 0, 0,
			0, 0, 1.0f / (zNearPlane - zFarPlane), 0,
			(left + right) / (left - right), (top + bottom) / (bottom - top), zNearPlane / (zNearPlane - zFarPlane), 1
		);
	}

	static Matrix4x4 Matrix4x4_CreatePerspectiveFieldOfView(
		float fieldOfView,
		float aspectRatio,
		float nearPlaneDistance,
		float farPlaneDistance
	) {
		float num = 1.0f / ((float) SDL_tanf(fieldOfView * 0.5f));
		return Matrix4x4(
			num / aspectRatio, 0, 0, 0,
			0, num, 0, 0,
			0, 0, farPlaneDistance / (nearPlaneDistance - farPlaneDistance), -1,
			0, 0, (nearPlaneDistance * farPlaneDistance) / (nearPlaneDistance - farPlaneDistance), 0
		);
	}

	static Matrix4x4 Matrix4x4_CreateLookAt(
		Vector3 cameraPosition,
		Vector3 cameraTarget,
		Vector3 cameraUpVector
	) {
		Vector3 targetToPosition = Vector3(
			cameraPosition.x - cameraTarget.x,
			cameraPosition.y - cameraTarget.y,
			cameraPosition.z - cameraTarget.z
		);
		Vector3 vectorA = Vector3_Normalize(targetToPosition);
		Vector3 vectorB = Vector3_Normalize(Vector3_Cross(cameraUpVector, vectorA));
		Vector3 vectorC = Vector3_Cross(vectorA, vectorB);

		return Matrix4x4(
			vectorB.x, vectorC.x, vectorA.x, 0,
			vectorB.y, vectorC.y, vectorA.y, 0,
			vectorB.z, vectorC.z, vectorA.z, 0,
			-Vector3_Dot(vectorB, cameraPosition), -Vector3_Dot(vectorC, cameraPosition), -Vector3_Dot(vectorA, cameraPosition), 1
		);
	}

	static Vector3 Vector3_Normalize(Vector3 vec)
	{
		float magnitude = SDL_sqrtf((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z));
		return Vector3(
			vec.x / magnitude,
			vec.y / magnitude,
			vec.z / magnitude
		);
	}

	static float Vector3_Dot(Vector3 vecA, Vector3 vecB)
	{
		return (vecA.x * vecB.x) + (vecA.y * vecB.y) + (vecA.z * vecB.z);
	}

	static Vector3 Vector3_Cross(Vector3 vecA, Vector3 vecB)
	{
		return Vector3(
			vecA.y * vecB.z - vecB.y * vecA.z,
			-(vecA.x * vecB.z - vecB.x * vecA.z),
			vecA.x * vecB.y - vecB.x * vecA.y
		);
	}
}
