//
//  ELAudioRecorder.h
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/13.
//  Copyright © 2018年 enli. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ELAudioRecognitioner.h"

@class ELAudioRecorder;
@protocol ELAudioRecorderDelegate
@required
-(void)ElAudioRecorderChangePower:(ELAudioRecorder *)recorder power:(int)power msg:(NSString *)msg;
@optional
@end


@interface ELAudioRecorder : NSObject<ELAudioRecognitionerDelegate>
@property (atomic,assign,readonly) BOOL isRecording;
@property (nonatomic,weak)id<ELAudioRecorderDelegate> delegate;
-(instancetype)initWithPath:(NSString *)filePath;
-(void)recordStart;
-(void)recordEnd;

@end
