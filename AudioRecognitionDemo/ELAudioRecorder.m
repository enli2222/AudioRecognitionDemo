//
//  ELAudioRecorder.m
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/13.
//  Copyright © 2018年 enli. All rights reserved.
// 参考https://blog.csdn.net/xiaoluodecai/article/details/47153945


#define kNumberAudioQueueBuffers 3  //定义了三个缓冲区
#define kDefaultBufferDurationSeconds 0.04//0.1279   //调整这个值使得录音的缓冲区大小为2048bytes
#define kDefaultSampleRate 8000   //定义采样率为8000
#define kDefaultChcannels 1


#import "ELAudioRecorder.h"

@interface ELAudioRecorder(){
    AudioStreamBasicDescription audioDescription; //音频格式
    AudioQueueRef audioQueue; //音频播放队列
    AudioQueueBufferRef audioQueueBuffers[kNumberAudioQueueBuffers]; //音频缓存
    NSString *_filePath;
    NSFileHandle *_audioFileHandle;
}
@end

@implementation ELAudioRecorder
@synthesize isRecording=_isRecording;
@synthesize delegate=_delegate;

-(instancetype)initWithPath:(NSString *)filePath{
    self = [super init];
    if (self) {
        _isRecording = false;
        _delegate = nil;
        _filePath = filePath;
        [self setupAudioFormat];
        [self createFile];
    }
    return self;
}

- (void)dealloc
{
    AudioQueueStop(audioQueue, true);
    AudioQueueDispose(audioQueue, true);
    if (_audioFileHandle) {
        [_audioFileHandle closeFile];
        _audioFileHandle = nil;
    }
}

-(void)createFile{
    _audioFileHandle = nil;
    NSError *err;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:_filePath]) {
        [fm removeItemAtPath:_filePath error:&err];
    }
    [fm createFileAtPath:_filePath contents:nil attributes:nil];
    _audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:_filePath];
}

-(void)recordStart{
    if (![self preStart]) {
        return;
    }
    
    //初始化音频输入队列
    //inputBufferHandler这个是回调函数名
    AudioQueueNewInput(&audioDescription, inputBufferHandler, (__bridge void *)(self), NULL, kCFRunLoopCommonModes, 0, &audioQueue);
    
    
    //计算估算的缓存区大小
    int frames = (int)ceil(kDefaultBufferDurationSeconds * audioDescription.mSampleRate);//返回大于或者等于指定表达式的最小整数
    int bufferByteSize = frames * audioDescription.mBytesPerFrame;//缓冲区大小在这里设置，这个很重要，在这里设置的缓冲区有多大，那么在回调函数的时候得到的inbuffer的大小就是多大。
    bufferByteSize = kDefaultChcannels * audioDescription.mBitsPerChannel * audioDescription.mSampleRate / 8 * 0.02;
    NSLog(@"缓冲区大小:%d",bufferByteSize);
    
    //创建缓冲器
    for (int i = 0; i < kNumberAudioQueueBuffers; i++){
        AudioQueueAllocateBuffer(audioQueue, bufferByteSize, &audioQueueBuffers[i]);
        AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffers[i], 0, NULL);//将 _audioBuffers[i]添加到队列中
    }
    
    //    AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning, adioQueueISRunningCallback, (__bridge void *)self);
    
    // 开始录音
    AudioQueueStart(audioQueue, NULL);
    _isRecording = YES;
    
}

-(void)recordEnd{
    if (self.isRecording) {
        _isRecording = NO;
        //停止录音队列和移除缓冲区,以及关闭session，这里无需考虑成功与否
        AudioQueueStop(audioQueue, true);
        AudioQueueDispose(audioQueue, true);
        if (_audioFileHandle) {
            [_audioFileHandle closeFile];
            _audioFileHandle = nil;
        }
        [self afterEnd];
    }
}

-(BOOL)preStart{
    NSError *error = nil;
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (!ret && error) {
        NSLog(@"设置PlayAndRecord: %@",error.localizedDescription);
        return false;
    }
    //启用audio session
    
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret && error )
    {
        NSLog(@"启动失败: %@",error.localizedDescription);
        return false;
    }
    return YES;
}

-(BOOL)afterEnd{
    NSError *error = nil;
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!ret && error) {
        NSLog(@"设置PlayAndRecord: %@",error.localizedDescription);
        return false;
    }
    ret = [[AVAudioSession sharedInstance] setActive:NO error:&error];
    if (!ret && error )
    {
        NSLog(@"启动失败: %@",error.localizedDescription);
        return false;
    }
    return YES;
}

// 设置录音格式
- (void)setupAudioFormat;
{
    //重置下
    memset(&audioDescription, 0, sizeof(audioDescription));
    
    //设置音频格式
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    
    //设置采样率
    //采样率的意思是每秒需要采集的帧数 8000、16000
    audioDescription.mSampleRate = 16000;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数
    audioDescription.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
    audioDescription.mFramesPerPacket = 1; //每一个packet一侦数据
    
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    //每个通道里，一帧采集的bit数目
    audioDescription.mBitsPerChannel = 16;//av_get_bytes_per_sample(AV_SAMPLE_FMT_S16)*8;//每个采样点16bit量化
    //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。 // 0 for compressed format
    //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
    
    audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel / 8) * audioDescription.mChannelsPerFrame;
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame;
    
    audioDescription.mReserved = 0;
    
}

-(void)processAudioBuffer:(AudioQueueBufferRef)inBuffer inStartTime:(const AudioTimeStamp *)inStartTime inNumPackets:(UInt32)inNumPackets{
    NSData *data = [[NSData alloc]initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
    if (_audioFileHandle && data.length > 0) {
        [_audioFileHandle writeData:data];
    }
    if (_delegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_delegate ElAudioRecorderChangePower:self power:inNumPackets msg:@"来啦"];
        });
    }
}


//相当于中断服务函数，每次录取到音频数据就进入这个函数
//inAQ 是调用回调函数的音频队列
//inBuffer 是一个被音频队列填充新的音频数据的音频队列缓冲区，它包含了回调函数写入文件所需要的新数据
//inStartTime 是缓冲区中的一采样的参考时间，对于基本的录制，你的毁掉函数不会使用这个参数
//inNumPackets是inPacketDescs参数中包描述符（packet descriptions）的数量，如果你正在录制一个VBR(可变比特率（variable bitrate））格式, 音频队列将会提供这个参数给你的回调函数，这个参数可以让你传递给AudioFileWritePackets函数. CBR (常量比特率（constant bitrate）) 格式不使用包描述符。对于CBR录制，音频队列会设置这个参数并且将inPacketDescs这个参数设置为NULL，官方解释为The number of packets of audio data sent to the callback in the inBuffer parameter.


void inputBufferHandler(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime,UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
    
    ELAudioRecorder * recorder = (__bridge ELAudioRecorder *) inUserData;
    if (inNumPackets > 0)
    {
        //在音频线程
        NSLog(@"inNumPackets: %u, DataByteSize:%u",(unsigned int)inNumPackets,(unsigned int)inBuffer->mAudioDataByteSize);
        [recorder processAudioBuffer:inBuffer inStartTime:inStartTime inNumPackets:inNumPackets];
    }
    
    if (recorder.isRecording) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}

@end
