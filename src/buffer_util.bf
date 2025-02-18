using System;

namespace gLTF;

enum BufferSliceType
{
	case u8(uint8 val);
	case i8(int8 val);
	case u16(uint16 val);
	case i16(int16 val);
	case u32(uint32 val); 
	case f32(float val);

	case u8_2(uint8[2] val);
	case i8_2(int8[2] val);
	case u16_2(uint16[2] val);
	case i16_2(int16[2] val);
	case u32_2(uint32[2] val);
	case f32_2(float[2] val);

	case u8_3(uint8[3] val);
	case i8_3(int8[3] val);
	case u16_3(uint16[3] val);
	case i16_3(int16[3] val);
	case u32_3(uint32[3] val);
	case f32_3(float[3] val);

	case u8_4(uint8[4] val);
	case i8_4(int8[4] val);
	case u16_4(uint16[4] val);
	case i16_4(int16[4] val);
	case u32_4(uint32[4] val);
	case f32_4(float[4] val);

	case u8_9(uint8[9] val);
	case i8_9(int8[9] val);
	case u16_9(uint16[9] val);
	case i16_9(int16[9] val);
	case u32_9(uint32[9] val);
	case f32_9(float[9] val);

	case u8_16(uint8[16] val);
	case i8_16(int8[16] val);
	case u16_16(uint16[16] val);
	case i16_16(int16[16] val);
	case u32_16(uint32[16] val);
	case f32_16(float[16] val);
}

class BufferUtil
{
	public static BufferSliceType? SliceBuffer(GLTFData data, int accessor_index)
	{
		Accessor accessor = data.accessors[accessor_index];
		Runtime.Assert(accessor.buffer_view != null, "buf_iter_make: selected accessor doesn't have buffer_view");

		Buffer_View buffer_view = Buffer_View();
		if (accessor.buffer_view != null)
		{
			buffer_view = data.buffer_views[(int)accessor.buffer_view];
		}

		if (accessor.indices != null || accessor.values != null)
		{
		    Runtime.Assert(false, "Sparse not supported");
		    return null;
		}

		if (buffer_view.byte_stride != null)
		{
		   	Runtime.Assert(false, "Cannot use a stride");
		    return null;
		}

		int start_byte = accessor.byte_offset + buffer_view.byte_offset;
		Uri uri = data.buffers[buffer_view.buffer].uri;

		switch (uri)
		{
			case .Str:
				Runtime.Assert(false, "URI is string");
				return null;

			case .Byte(let v):
                int bytesize = 0;
                int bytemult = 1;
                switch(accessor.type)
                {
                    case .Vector2:
                		bytemult = 2;
                		break;
    
                	case .Vector3:
                		bytemult = 3;
                		break;
    
                	case .Vector4:
                	case .Matrix2:
                		bytemult = 4;
                		break;
    
                	case .Matrix3:
                		bytemult = 9;
                		break;
    
                	case .Matrix4:
                       bytemult = 16;
                        break;
    
                    default:
                        break;
                }

                switch(accessor.component_type)
                {
                    case .Unsigned_Byte:
                        bytesize = sizeof(uint8);
                        break;
                    case .Byte:
                        bytesize = sizeof(int8);
                        break;
                    case .Short:
                        bytesize = sizeof(uint16);
                        break;
                    case .Unsigned_Short:
                        bytesize = sizeof(int16);
                        break;
                    case .Unsigned_Int:
                        bytesize = sizeof(uint32);
                        break;
                    case .Float:
                        bytesize = sizeof(float);
                        break;
                	default: break;
                }

                Span<uint8> bytespan = v.Slice(start_byte,  bytesize * bytemult);

                switch(accessor.component_type)
                {
                    case .Unsigned_Byte:
                        switch(bytemult)
                        {
                            case 2:
                                return BufferSliceType.u8_2(*(uint8[2]*)bytespan.Ptr);
                            case 3:
                                return BufferSliceType.u8_3(*(uint8[3]*)bytespan.Ptr);
                            case 4:
                                return BufferSliceType.u8_4(*(uint8[4]*)bytespan.Ptr);
                            case 9:
                                return BufferSliceType.u8_9(*(uint8[9]*)bytespan.Ptr);
                            case 16:
                                return BufferSliceType.u8_16(*(uint8[16]*)bytespan.Ptr);
                            default:
                                return BufferSliceType.u8(*(uint8*)bytespan.Ptr);
                        }
                    case .Byte:
                        switch(bytemult)
                        {
                            case 2:
                                return BufferSliceType.i8_2(*(int8[2]*)bytespan.Ptr);
                            case 3:
                                return BufferSliceType.i8_3(*(int8[3]*)bytespan.Ptr);
                            case 4:
                                return BufferSliceType.i8_4(*(int8[4]*)bytespan.Ptr);
                            case 9:
                                return BufferSliceType.i8_9(*(int8[9]*)bytespan.Ptr);
                            case 16:
                                return BufferSliceType.i8_16(*(int8[16]*)bytespan.Ptr);
                            default:
                                return BufferSliceType.i8(*(int8*)bytespan.Ptr);    
                        }
                    case .Short:
                        switch(bytemult)
                        {
                            case 2:
                                return BufferSliceType.u16_2(*(uint16[2]*)bytespan.Ptr);
                            case 3:
                                return BufferSliceType.u16_3(*(uint16[3]*)bytespan.Ptr);
                            case 4:
                                return BufferSliceType.u16_4(*(uint16[4]*)bytespan.Ptr);
                            case 9:
                                return BufferSliceType.u16_9(*(uint16[9]*)bytespan.Ptr);
                            case 16:
                                return BufferSliceType.u16_16(*(uint16[16]*)bytespan.Ptr);
                            default:
                                return BufferSliceType.u16(*(uint16*)bytespan.Ptr);
                        }
                    case .Unsigned_Short:
                        switch(bytemult)
                        {
                            case 2:
                                return BufferSliceType.i16_2(*(int16[2]*)bytespan.Ptr);
                            case 3:
                                return BufferSliceType.i16_3(*(int16[3]*)bytespan.Ptr);
                            case 4:
                                return BufferSliceType.i16_4(*(int16[4]*)bytespan.Ptr);
                            case 9:
                                return BufferSliceType.i16_9(*(int16[9]*)bytespan.Ptr);
                            case 16:
                                return BufferSliceType.i16_16(*(int16[16]*)bytespan.Ptr);
                            default:
                                return BufferSliceType.i16(*(int16*)bytespan.Ptr);
                        } 
                    case .Unsigned_Int:
                        switch(bytemult)
                        {
                            case 2:
                                return BufferSliceType.u32_2(*(uint32[2]*)bytespan.Ptr);
                            case 3:
                                return BufferSliceType.u32_3(*(uint32[3]*)bytespan.Ptr);
                            case 4:
                                return BufferSliceType.u32_4(*(uint32[4]*)bytespan.Ptr);
                            case 9:
                                return BufferSliceType.u32_9(*(uint32[9]*)bytespan.Ptr);
                            case 16:
                                return BufferSliceType.u32_16(*(uint32[16]*)bytespan.Ptr);
                            default:
                                return BufferSliceType.u32(*(uint32*)bytespan.Ptr);    
                        }    
                    case .Float:
                        switch(bytemult)
                        {
                            case 2:
                                return BufferSliceType.f32_2(*(float[2]*)bytespan.Ptr);
                            case 3:
                                return BufferSliceType.f32_3(*(float[3]*)bytespan.Ptr);
                            case 4:
                                return BufferSliceType.f32_4(*(float[4]*)bytespan.Ptr);
                            case 9:
                                return BufferSliceType.f32_9(*(float[9]*)bytespan.Ptr);
                            case 16:
                                return BufferSliceType.f32_16(*(float[16]*)bytespan.Ptr);
                            default:
                                return BufferSliceType.f32(*(float*)bytespan.Ptr);
                        }  
                	default: break;
                }

			default: break;
		}

		return null;
	}	
}
