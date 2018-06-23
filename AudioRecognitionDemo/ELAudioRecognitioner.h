//
//  ELAudioRecognitioner.h
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/21.
//  Copyright © 2018年 enli. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ELAudioRecognitioner;
@protocol ELAudioRecognitionerDelegate
@required
@optional
-(void)ResponseASR:(NSString *)msg;
-(void)ResponseTTS:(NSData *)data;
@end

@interface ELAudioRecognitioner : NSObject
@property (nonatomic,weak)id<ELAudioRecognitionerDelegate> delegate;
-(instancetype)initWithURL:(NSURL *)url;
-(void)ASR:(NSData *)data;
-(void)TTS:(NSString *)Msg;




@end
