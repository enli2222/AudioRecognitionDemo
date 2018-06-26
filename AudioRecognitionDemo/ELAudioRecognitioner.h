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
-(void)ResponseTTS:(NSData *)data result:(NSString *)msg;
@end

@interface ELAudioRecognitioner : NSObject<NSXMLParserDelegate>
@property (nonatomic,weak)id<ELAudioRecognitionerDelegate> delegate;
-(instancetype)initWithURL:(NSString *)url;
-(void)ASR:(NSData *)data;
-(void)TTS:(NSString *)Msg;

@end
