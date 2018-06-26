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
    NSString *requestASRURL,*requestTTSURL,*dev_key,*node_name;
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
        requestASRURL = @"http://服务器地址/asr/Recognise";
        requestTTSURL = @"http://服务器地址/tts/SynthText";
        dev_key = @"developer_key";
        node_name = @"";
    }
    return self;
}

-(void)dealloc
{
    NSLog(@"%s",__func__);
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
//    AFHTTPResponseSerializer *responseSerializer = [AFHTTPResponseSerializer serializer];
    AFHTTPResponseSerializer *responseSerializer = [AFXMLParserResponseSerializer serializer];
    responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",
                                                 @"text/html",
                                                 @"text/json",
                                                 @"text/javascript",
                                                 @"text/plain",
                                                 nil];
    manager.responseSerializer = responseSerializer;
    [[manager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (!error) {
//            NSString * str  =[[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
//            NSLog(@"ok,%@",str);
//            NSXMLParser *parser = [[NSXMLParser alloc]initWithData:responseObject];
            NSXMLParser *parser = (NSXMLParser *)responseObject;
             parser.delegate = self;
            [parser setShouldProcessNamespaces:YES];
            if (![parser parse]) {
                NSLog(@"解析失败:%@",parser.parserError);
                if (weakSelf.delegate) {
                    [weakSelf.delegate ResponseASR:parser.parserError.description];
                }
            }
            
        } else {
            NSLog(@"请求失败:%@",error.description);
            if (weakSelf.delegate) {
                [weakSelf.delegate ResponseASR:error.description];
            }
        }

    }] resume];
}

-(void)TTS:(NSString *)Msg{
    __weak typeof(self) weakSelf = self;
    NSDateFormatter *formater = [[NSDateFormatter alloc]init];
    [formater setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *currentDate = [formater stringFromDate:[NSDate date]];
    NSString *config = [NSString stringWithFormat:@"capkey=tts.cloud.synth,property=cn_wangjingv9_common,audioformat=auto,identify=%d",arc4random()*10000];
    NSString *session = [self md5:[NSString stringWithFormat:@"%@%@",currentDate,dev_key]];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:requestTTSURL parameters:nil error:nil];
    request.timeoutInterval = 40;
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"ac5d5452" forHTTPHeaderField:@"x-app-key"];
    [request setValue:@"5.0" forHTTPHeaderField:@"x-sdk-version"];
    [request setValue:currentDate forHTTPHeaderField:@"x-request-date"];
    [request setValue:config forHTTPHeaderField:@"x-task-config"];
    [request setValue:session forHTTPHeaderField:@"x-session-key"];
    [request setValue:@"101:1234567890" forHTTPHeaderField:@"x-udid"];
    [request setHTTPBody:[Msg dataUsingEncoding:NSUTF8StringEncoding]];
    AFHTTPResponseSerializer *responseSerializer = [AFHTTPResponseSerializer serializer];
    manager.responseSerializer = responseSerializer;
    [[manager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (!error) {
            NSData *data = (NSData *)responseObject;
            /*
             内容包头是XML, 携带的语音数据接在</ResponseInfo>标记后
             */
            const char *bytes = [data bytes];
            unsigned int ipos = 0;
            for (int i=0; i<[data length]; i++) {
                char ibuffer = bytes[i];
                if ((ibuffer & 0x80) != 0) {
                    ipos = i - 1;
                    break;
                }
            }
            NSString* tmp = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, ipos)] encoding:NSUTF8StringEncoding];
            NSRange iEnd = [tmp rangeOfString:@"</ResponseInfo>"];
            NSLog(@"ok,%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            if (weakSelf.delegate && ([data length] > (iEnd.location + iEnd.length))) {
                [weakSelf.delegate ResponseTTS:[data subdataWithRange:NSMakeRange(iEnd.location + iEnd.length, [data length]- iEnd.location - iEnd.length)]];
            }
        } else {
            NSLog(@"request error = %@",error.description);
        }

    }] resume];
}

-(void)parserDidStartDocument:(NSXMLParser *)parser{
    NSLog(@"开始解析文件");
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict{
    NSLog(@"开始解析:%@",elementName);
    if ([elementName isEqualToString: @"Result"]) {
        node_name = elementName;
    }
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    NSLog(@"解析结束:%@",elementName);
    node_name = @"";
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
    NSLog(@"发现:%@",string);
    /*
     <...>
     <Result>
     <Text>识别内容</Text>
     <Score>结果得分</Score>
     </Result>
     <...>
     */
    if (_delegate && [node_name length] > 0) {
        [_delegate ResponseASR:string];
    }
}

-(void)parserDidEndDocument:(NSXMLParser *)parser{
    NSLog(@"结束解析文件");
}



@end
