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
-(void)ElAudioRecorderChangePower:(NSString *)msg result:(NSString *)err;
@optional
@end


@interface ELAudioRecorder : NSObject<ELAudioRecognitionerDelegate>
@property (atomic,assign,readonly) BOOL isRecording;
@property (nonatomic,assign)id<ELAudioRecorderDelegate> delegate;
-(instancetype)initWithPath:(NSString *)filePath;
-(void)recordStart;
-(BOOL)recordEnd;

@end
