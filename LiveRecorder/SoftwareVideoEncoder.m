//
//  SoftwareVideoEncoder.m
//  LiveRecorder
//
//  Created by Yingming Fan on 15/9/21.
//  Copyright © 2015年 Shengbin Meng. All rights reserved.
//

#import "SoftwareVideoEncoder.h"
#include "x264.h"
@implementation SoftwareVideoEncoder
{
    x264_t *h;
    x264_param_t param;
    uint8_t *u_plane;
    uint8_t *v_plane;
}

static void  int_to_str(int value, char *str) {
    sprintf(str, "%d", value);
}

- (int) open {
    [super open];
    
    char bitrate_str[20];
    char fps_str[20];
    char vbv_bufsize_str[20];
    char vbv_maxrate[20];
    int x264_bitrate = self.bitrate;
    int b_cbr = 0;
    
    //The default value when user didn't set.
    if (self.bitrate == 0) {
        self.bitrate = 500;
        x264_bitrate = self.bitrate;
    }
    if (self.frameRate == 0) {
        self.frameRate = 15;
    }
    
    if (x264_bitrate <= 0 || self.frameRate <= 0)
        return -1;
    
    int_to_str(self.frameRate, fps_str);
    int_to_str(x264_bitrate, bitrate_str);
    int_to_str(x264_bitrate*2, vbv_maxrate);
    int_to_str(x264_bitrate/self.frameRate, vbv_bufsize_str);
    
    if( x264_param_default_preset( &param, "superfast", "zerolatency" ) < 0 )
        return -1;
    
    x264_param_parse( &param, "bitrate", bitrate_str );
    x264_param_parse( &param, "vbv-maxrate", vbv_maxrate);
    x264_param_parse( &param, "vbv-bufsize", b_cbr ? vbv_bufsize_str : bitrate_str);
    
    x264_param_parse( &param, "fps", fps_str );
    x264_param_parse( &param, "keyint", fps_str);
    
    param.i_width = self.width;
    param.i_height= self.height;
    
    NSLog(@"fps_num = %d, fps_den = %d, bitrate = %d, rc method = %d\n", param.i_fps_num, param.i_fps_den, param.rc.i_bitrate, param.rc.i_rc_method);
    NSLog(@"b_deblocking_filter = %d, i_deblocking_filter_alphac0 = %d, i_deblocking_filter_beta = %d", param.b_deblocking_filter, param.i_deblocking_filter_alphac0, param.i_deblocking_filter_beta);
    NSLog(@"b_cabac = %d, i_threads = %d", param.b_cabac, param.i_threads);
    NSLog(@"b_repeat_headers = %d", param.b_repeat_headers);
    h = x264_encoder_open( &param );
    
    if (!h)
        return -1;
    
    u_plane = malloc(param.i_width*param.i_height/4);
    v_plane = malloc(param.i_width*param.i_height/4);
    
    return 0;
}

- (int) encode:(CMSampleBufferRef)sampleBuffer {
    [super encode:sampleBuffer];
    
    if (h == NULL)
        return -1;
    
    int i_nal_size = 0;
    x264_nal_t *nal;
    int i_nal;
    x264_picture_t pic_out;
    x264_picture_t pic;
    int i;
    int payload_size = 0;
    CMTime time;
    
    if (sampleBuffer != NULL) {
        int x, y;
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        time = pts;
        uint8_t* pixel_y = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        uint8_t* pixel_uv = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        
        size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        size_t bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
        //TODO: let x264 use nv12 directly and avoid color space conversion.
        //NV12 to i420
        for (y = 0; y < param.i_height/2; y++) {
            for (x = 0; x < param.i_width; x += 2) {
                u_plane[y*param.i_width/2 + x/2] = pixel_uv[y*bytesPerRowUV + x];
                v_plane[y*param.i_width/2 + x/2] = pixel_uv[y*bytesPerRowUV + x+1];
            }
        }
        
        //fill pic as x264 input
        x264_picture_init(&pic);
        pic.i_pts = pts.value;//TODO: is this correct?
        
        pic.img.i_csp = param.i_csp;
        pic.img.i_plane = 3;
        pic.img.i_stride[0] = bytesPerRow;
        pic.img.i_stride[1] = param.i_width/2;
        pic.img.i_stride[2] = param.i_width/2;
        pic.img.plane[0] = pixel_y;
        pic.img.plane[1] = u_plane;
        pic.img.plane[2] = v_plane;
        
        i_nal_size = x264_encoder_encode( h, &nal, &i_nal, &pic, &pic_out );
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    } else {
        NSLog(@"input NULL, do encoder flush\n");
        i_nal_size = x264_encoder_encode( h, &nal, &i_nal, NULL, &pic_out );
    }

    if (i_nal_size > 0) {
        //output bitstream
        payload_size = 0;
        for (i = 0; i < i_nal; i++) {
            payload_size += nal[i].i_payload;
        }
        NSLog(@"nal size: %d", payload_size);
        
        NSMutableData *videoData = [NSMutableData dataWithLength:0];
        [videoData appendData:[NSData dataWithBytes:nal[0].p_payload length:payload_size]];
        //TODO: is this correct?
        time.value = pic_out.i_pts;

        [[self output] didReceiveEncodedVideo:videoData presentationTime:time isKeyFrame:pic_out.b_keyframe];
        
        return payload_size;
    } else if (i_nal_size < 0) {
        NSLog(@"x264 encode error.\n");
        goto end;
    }
    
    return i_nal_size;
    
end:
    return -1;
}

- (int) close {
    [super close];
    if (h) {
        while (x264_encoder_delayed_frames(h)) {
            [self encode:nil];
        }
        x264_encoder_close(h);
        free(u_plane);
        free(v_plane);
        h = NULL;
    }
    return 0;
}

@end
