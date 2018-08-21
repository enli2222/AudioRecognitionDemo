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
//音频转文字
-(void)ResponseASR:(NSString *)msg result:(NSString *)err;
//文字转音频
-(void)ResponseTTS:(NSData *)data result:(NSString *)err;
@end

@interface ELAudioRecognitioner : NSObject<NSXMLParserDelegate>
@property (nonatomic,weak)id<ELAudioRecognitionerDelegate> delegate;
-(instancetype)initWithURL:(NSString *)url;
-(void)ASR:(NSData *)data identify:(NSInteger)identify endFlag:(BOOL)flag;
-(void)ASR:(NSData *)data;
-(void)TTS:(NSString *)Msg;

@end
