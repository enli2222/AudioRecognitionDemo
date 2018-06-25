//
//  ELAudioPlayer.h
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/14.
//  Copyright © 2018年 enli. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ELAudioRecognitioner.h"

#define kNumberOfBuffers 3              //AudioQueueBuffer数量，一般指明为3
#define kAQBufSize  128*1024            //每个AudioQueueBuffer的大小
#define kAudioFileBufferSize 10*1048   //文件读取数据的缓冲区大小
#define kMaxPacketDesc 128*1048         //最大的AudioStreamPacketDescription个数

@class ELAudioPlayer;
@protocol ELAudioPlayerDelegate
@required
@optional
-(void)ELAudioPlayEnd:(ELAudioPlayer *)player;
@end

@interface ELAudioPlayer : NSObject<ELAudioRecognitionerDelegate>

@property (atomic,assign,readonly) BOOL isPlaying;
@property (nonatomic,assign)AudioStreamBasicDescription audioDescription;
@property (nonatomic,assign)AudioQueueRef audioQueue;
@property (nonatomic,assign)UInt64 audioFileLength;
@property (nonatomic,assign)UInt32 bitRate;
@property (nonatomic,assign)id<ELAudioPlayerDelegate> delegate;

-(instancetype)initWithURL:(NSString *)filePath;
-(void)play;
-(void)playMsg:(NSString *)msg;
-(void)stop;
-(void)pause;
@end
