#include <stdio.h>
#include <math.h>
typedef unsigned short UINT;
typedef unsigned long DWORD;
typedef unsigned char BYTE;

UINT Ue(const BYTE *pBuff, UINT nLen, UINT *nStartBit)
{
	UINT nZeroNum = 0;
	while (*nStartBit < nLen * 8)
	{
		if (pBuff[*nStartBit / 8] & (0x80 >> (*nStartBit % 8)))
		{
			break;
		}
		nZeroNum++;
		(*nStartBit)++;
	}
	(*nStartBit)++;


	DWORD dwRet = 0;
	for (UINT i=0; i<nZeroNum; i++)
	{
		dwRet <<= 1;
		if (pBuff[(*nStartBit) / 8] & (0x80 >> ((*nStartBit) % 8)))
		{
			dwRet += 1;
		}
		(*nStartBit)++;
	}
	return (1 << nZeroNum) - 1 + dwRet;
}


int Se(const BYTE *pBuff, UINT nLen, UINT *nStartBit)
{
	int UeVal=Ue(pBuff,nLen,nStartBit);
	double k=UeVal;
	int nValue=ceil(k/2);
	if (UeVal % 2==0)
		nValue=-nValue;
	return nValue;
}


DWORD u(UINT BitCount,const BYTE * buf,UINT *nStartBit)
{
	DWORD dwRet = 0;
	for (UINT i=0; i<BitCount; i++)
	{
		dwRet <<= 1;
		if (buf[(*nStartBit) / 8] & (0x80 >> ((*nStartBit) % 8)))
		{
			dwRet += 1;
		}
		nStartBit++;
	}
	return dwRet;
}


bool h264_decode_sps(const BYTE * buf,unsigned int nLen,int *width,int *height)
{
	UINT StartBit=0; 
    u(1,buf,&StartBit); // forbidden_zero_bit
	u(2,buf,&StartBit); // nal_ref_idc
	int nal_unit_type = (int)u(5,buf,&StartBit);
	if(nal_unit_type==7)
	{
		int profile_idc = (int)u(8,buf,&StartBit);
		u(1,buf,&StartBit);//(buf[1] & 0x80)>>7; constraint_set0_flag
		u(1,buf,&StartBit);//(buf[1] & 0x40)>>6; constraint_set1_flag
		u(1,buf,&StartBit);//(buf[1] & 0x20)>>5; constraint_set2_flag
		u(1,buf,&StartBit);//(buf[1] & 0x10)>>4; constraint_set3_flag
		u(4,buf,&StartBit);// reserved_zero_4bits
		u(8,buf,&StartBit);// level_idc

		Ue(buf,nLen,&StartBit);// seq_parameter_set_id
        int residual_colour_transform_flag;
        int log2_max_pic_order_cnt_lsb_minus4;

		if( profile_idc == 100 || profile_idc == 110 ||
			profile_idc == 122 || profile_idc == 144 )
		{
			int chroma_format_idc=Ue(buf,nLen,&StartBit);
			if( chroma_format_idc == 3 )
				residual_colour_transform_flag=(int)u(1,buf,&StartBit);
			Ue(buf,nLen,&StartBit);// bit_depth_luma_minus8
			Ue(buf,nLen,&StartBit);// bit_depth_chroma_minus8
			u(1,buf,&StartBit);// qpprime_y_zero_transform_bypass_flag
			int seq_scaling_matrix_present_flag=(int)u(1,buf,&StartBit);

			int seq_scaling_list_present_flag[8];
			if( seq_scaling_matrix_present_flag )
			{
				for( int i = 0; i < 8; i++ ) {
					seq_scaling_list_present_flag[i]=(int)u(1,buf,&StartBit);
				}
			}
		}
		Ue(buf,nLen,&StartBit);// log2_max_frame_num_minus4
		int pic_order_cnt_type=Ue(buf,nLen,&StartBit);
		if( pic_order_cnt_type == 0 )
			log2_max_pic_order_cnt_lsb_minus4=Ue(buf,nLen,&StartBit);
		else if( pic_order_cnt_type == 1 )
		{
			u(1,buf,&StartBit);// delta_pic_order_always_zero_flag
			Se(buf,nLen,&StartBit);// offset_for_non_ref_pic
			Se(buf,nLen,&StartBit);// offset_for_top_to_bottom_field
			int num_ref_frames_in_pic_order_cnt_cycle=Ue(buf,nLen,&StartBit);

            int * offset_for_ref_frame =  (int*)malloc(sizeof(int) * num_ref_frames_in_pic_order_cnt_cycle);
			for( int i = 0; i < num_ref_frames_in_pic_order_cnt_cycle; i++ )
				offset_for_ref_frame[i]=Se(buf,nLen,&StartBit);
			free(offset_for_ref_frame);
		}
		Ue(buf,nLen,&StartBit); // num_ref_frames
		u(1,buf,&StartBit); // gaps_in_frame_num_value_allowed_flag
		int pic_width_in_mbs_minus1=Ue(buf,nLen,&StartBit);
		int pic_height_in_map_units_minus1=Ue(buf,nLen,&StartBit);

		(*width) = (pic_width_in_mbs_minus1+1)*16;
		(*height) = (pic_height_in_map_units_minus1+1)*16;

		return true;
	}
	else
		return false;
}