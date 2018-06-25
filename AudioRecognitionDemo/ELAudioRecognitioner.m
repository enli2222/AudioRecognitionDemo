//
//  ELAudioRecognitioner.m
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/21.
//  Copyright © 2018年 enli. All rights reserved.
//  参考 https://www.cnblogs.com/Mr-zyh/p/5853797.html
//  参考 https://blog.csdn.net/yaoliangjun306/article/details/53411279

#import "ELAudioRecognitioner.h"
#import <CommonCrypto/CommonDigest.h>
#import "AFNetworking.h"

@interface ELAudioRecognitioner(){
    NSString *requestASRURL,*requestTTSURL,*dev_key;
}
@end

@implementation ELAudioRecognitioner
@synthesize delegate = _delegate;

- (NSString *) md5:(NSString *) input {
    const char *cStr = [input UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (unsigned int)strlen(cStr), digest ); // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return  output;
}

-(instancetype)initWithURL:(NSString *)url{
    self = [super init];
    if (self) {
        requestASRURL = @"http:///asr/Recognise";
        requestTTSURL = @"http:///tts/SynthText";
        dev_key = @"developer_key";
    }
    return self;
}

-(void)ASR:(NSData *)data{
    __weak typeof(self) weakSelf = self;
    NSDateFormatter *formater = [[NSDateFormatter alloc]init];
    [formater setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *currentDate = [formater stringFromDate:[NSDate date]];
    NSString *config = [NSString stringWithFormat:@"audioformat=pcm16k16bit,capkey=asr.cloud.freetalk,property=chinese_16k_music,index=-1,identify=%d",arc4random()*10000];
    NSString *session = [self md5:[NSString stringWithFormat:@"%@%@",currentDate,dev_key]];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:requestASRURL parameters:nil error:nil];
    request.timeoutInterval = 30;
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"ac5d5452" forHTTPHeaderField:@"x-app-key"];
    [request setValue:@"5.0" forHTTPHeaderField:@"x-sdk-version"];
    [request setValue:currentDate forHTTPHeaderField:@"x-request-date"];
    [request setValue:config forHTTPHeaderField:@"x-task-config"];
    [request setValue:session forHTTPHeaderField:@"x-session-key"];
    [request setValue:@"101:1234567890" forHTTPHeaderField:@"x-udid"];
    [request setHTTPBody:data];
    AFHTTPResponseSerializer *responseSerializer = [AFHTTPResponseSerializer serializer];
//    AFHTTPResponseSerializer *responseSerializer = [AFXMLParserResponseSerializer serializer];
    responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",
                                                 @"text/html",
                                                 @"text/json",
                                                 @"text/javascript",
                                                 @"text/plain",
                                                 nil];
    manager.responseSerializer = responseSerializer;
    [[manager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (!error) {
            NSString * str  =[[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            NSLog(@"ok,%@",str);
//            NSXMLParser *parser = (NSXMLParser *)responseObject;
//            NSDictionary *dic = [NSDictionary dictionaryWithXMLParser:parser];
//            success([weakSelf processResponse:responseObject]);
        } else {
            NSLog(@"request error = %@",error);
        }
        if (weakSelf.delegate) {
            [weakSelf.delegate ResponseASR:@"完成"];
        }
    }] resume];
}

-(void)TTS:(NSString *)Msg{
    __weak typeof(self) weakSelf = self;
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:requestASRURL parameters:nil error:nil];
    request.timeoutInterval = 30;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//    [request setHTTPBody:msg];
    AFHTTPResponseSerializer *responseSerializer = [AFHTTPResponseSerializer serializer];
    responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",
                                                 @"text/html",
                                                 @"text/json",
                                                 @"text/javascript",
                                                 @"text/plain",
                                                 nil];
    manager.responseSerializer = responseSerializer;
    [[manager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (!error) {
            NSLog(@"ok");
            //            success([weakSelf processResponse:responseObject]);
        } else {
            NSLog(@"request error = %@",error);
        }
        if (weakSelf.delegate) {
            [weakSelf.delegate ResponseTTS:nil];
        }
    }] resume];
}



@end
