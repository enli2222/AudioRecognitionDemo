//
//  ELAudioPlayer.m
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/14.
//  Copyright © 2018年 enli. All rights reserved.
//  参考 https://blog.csdn.net/qq_32081025/article/details/78248335
//  参考 https://blog.csdn.net/cairo123/article/details/53839980
//  参考 https://blog.csdn.net/cairo123/article/details/53996551
//  pcm参考 https://www.jianshu.com/p/b01268eb440d
//  官方参考 https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQPlayback/PlayingAudio.html


#import "ELAudioPlayer.h"

@implementation ELAudioPlayer{
    AudioFileStreamID audioFileStreamID;
    AudioQueueBufferRef audioQueueBuffers[kNumberOfBuffers]; //音频缓存
    BOOL inuse[kNumberOfBuffers];
    AudioStreamPacketDescription audioStreamPacketDesc[kMaxPacketDesc];
    NSLock *sysnLock;
    UInt64 audioFileDataOffset; //音频文件的偏移量
    UInt64 audioPacketsFilled; //当前Buffer填充多少帧
    UInt64 audioDataBytesFilled; //当前Buffer填充的数据大小
    NSInteger audioQueueCurrentBufferIndex; //当前填充的buffer序号
    NSString *_filePath;
    AudioFileTypeID _audioFileType;
    ELAudioRecognitioner *recognitioner;
    BOOL _isFinishing,_isPCMFile;
}

@synthesize isPlaying=_isPlaying;
@synthesize audioDescription=_audioDescription;
@synthesize audioQueue=_audioQueue;
@synthesize audioFileLength=_audioFileLength;
@synthesize bitRate=_bitRate;
@synthesize delegate=_delegate;

-(instancetype)initWithURL:(NSString *)filePath{
    self = [super init];
    if (self) {
        _isPlaying = NO;
        _isFinishing = NO;
        _isPCMFile = NO;
        _filePath = filePath;
        _audioFileType = [self hintForFileExtension:[_filePath pathExtension]];
        _audioFileLength = 0;
        _bitRate = 0;
        audioQueueCurrentBufferIndex = 99;
        audioFileStreamID = NULL;
        sysnLock = [[NSLock alloc] init];
        [self setupAudioFormat];
        [self setRouteChange];
    }
    return self;
}

-(void)dealloc
{
    NSLog(@"%s",__func__);
    if (_audioQueue != nil) {
        AudioQueueStop(_audioQueue, true);
        _audioQueue = nil;
    }
    if (recognitioner) {
        recognitioner = nil;
    }
    sysnLock = nil;
}

//设置音频参数
- (void)setupAudioFormat;
{
    //重置下
    memset(&_audioDescription, 0, sizeof(_audioDescription));

    //设置音频格式
    _audioDescription.mFormatID = kAudioFormatLinearPCM;
    
    //设置采样率
    //采样率的意思是每秒需要采集的帧数 8000、16000
    _audioDescription.mSampleRate = 16000;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数
    _audioDescription.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
    _audioDescription.mFramesPerPacket = 1; //每一个packet一侦数据
    
    _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    //每个通道里，一帧采集的bit数目
    _audioDescription.mBitsPerChannel = 16;//av_get_bytes_per_sample(AV_SAMPLE_FMT_S16)*8;//每个采样点16bit量化
    //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。 // 0 for compressed format
    //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
    
    _audioDescription.mBytesPerFrame = (_audioDescription.mBitsPerChannel / 8) * _audioDescription.mChannelsPerFrame;
    _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame;
    _audioDescription.mReserved = 0;
}

-(void)createQueue{
    NSLog(@"%s",__func__);
    NSLog(@"SampleRate:%f,Channels: %u,BytesPerFrame: %u BytesPerPacket: %u ",_audioDescription.mSampleRate,(unsigned int)_audioDescription.mChannelsPerFrame,(unsigned int)_audioDescription.mBytesPerFrame,(unsigned int)_audioDescription.mBytesPerPacket);
    OSStatus status = AudioQueueNewOutput(&_audioDescription, ELAudioQueueOutputCallback, (__bridge void*)self, NULL, NULL, 0, &_audioQueue);
    if (status == noErr) {
        for (int i = 0; i < kNumberOfBuffers; ++i) {
            AudioQueueAllocateBuffer(_audioQueue, kAQBufSize, &audioQueueBuffers[i]);
            inuse[i]=NO;
        }
        audioQueueCurrentBufferIndex = 0;
        audioPacketsFilled = 0;
        audioDataBytesFilled = 0;
    }
}

-(BOOL)prePlay{
    NSLog(@"%s",__func__);
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    //    配置音频会话后，如果锁屏的话，播放依旧会停止，如果要继续播放音乐需要target->capabilities 钩上 Backgrounds Modes里面的第一个选项
    BOOL ret = [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!ret && error) {
        NSLog(@"设置Playback: %@",error.localizedDescription);
        return NO;
    }
    
    //启用audio session
    ret = [session setActive:YES error:&error];
    if (!ret && error )
    {
        NSLog(@"启动失败: %@",error.localizedDescription);
        return NO;
    }
    return YES;
    
}

-(void)play{
    if (![self prePlay]) return;
    [self playByThread];
}

-(void)playMsg:(NSString *)msg{
    NSError *err;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:_filePath]) {
        if ([msg length]>0) {
            [fm removeItemAtPath:_filePath error:&err];
            [self downloadAudio:msg];
        }else{
            [self play];
        }
    }else{
        if ([msg length]>0) {
            [self downloadAudio:msg];
        }
    }
}

-(void)downloadAudio:(NSString *)msg{
    if (!recognitioner) {
        recognitioner = [[ELAudioRecognitioner alloc]initWithURL:@"服务器地址"];
        recognitioner.delegate = self;
        [recognitioner TTS:msg];
    }
}

-(BOOL)ParsePCM:(NSData *)inInputData{
    OSStatus err;
    if(audioQueueCurrentBufferIndex==99) [self createQueue];
    UInt64 mDataByteSize = inInputData.length;
//    NSLog(@"mDataByteSize:%llu,audioDataBytesFilled:%llu",mDataByteSize,kAQBufSize - audioDataBytesFilled);
    if (mDataByteSize > kAQBufSize - audioDataBytesFilled){
        err = AudioQueueEnqueueBuffer(_audioQueue, audioQueueBuffers[audioQueueCurrentBufferIndex], 0, NULL);
        audioQueueCurrentBufferIndex = (audioQueueCurrentBufferIndex + 1) % kNumberOfBuffers;
        audioPacketsFilled = 0;
        audioDataBytesFilled = 0;
        
        if (!_isPlaying) {
            err = AudioQueueStart(_audioQueue, NULL);
            _isPlaying = YES;
        }
        while (inuse[audioQueueCurrentBufferIndex]){
            if (_isFinishing) {
                break;
            }
        }
    }
    if (_isFinishing) return NO;
    
    AudioQueueBufferRef currentFilledBuffer = audioQueueBuffers[audioQueueCurrentBufferIndex];
    if (!inuse[audioQueueCurrentBufferIndex] ) {
        [sysnLock lock];
        inuse[audioQueueCurrentBufferIndex] = YES;
        [sysnLock unlock];
    }
    currentFilledBuffer->mAudioDataByteSize = (UInt32)(audioDataBytesFilled + mDataByteSize);
    memcpy(currentFilledBuffer->mAudioData + audioDataBytesFilled , [inInputData bytes], mDataByteSize);
    audioDataBytesFilled = audioDataBytesFilled + mDataByteSize;
    audioPacketsFilled = audioPacketsFilled + 1;
    return YES;
}

-(BOOL)ParseNOPCM:(NSData *)inInputData{
    OSStatus err;
    if (!audioFileStreamID) {
        err = AudioFileStreamOpen((__bridge void*)self, AudioFileStreamPropertyListenerProc, AudioFileStreamPacketsProc, _audioFileType, &audioFileStreamID);
        if (err != noErr) {
            NSLog(@"AudioFileStreamOpen: %u",(unsigned int)err);
            return NO;
        }
    }
    err = AudioFileStreamParseBytes(audioFileStreamID, (UInt32)(inInputData.length), [inInputData bytes], 0);
    if (err != noErr) {
        NSLog(@"AudioFileStreamParseBytes: %d",(unsigned int)err);
        return NO;
    }
    return YES;
}

-(void)playByThread{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        OSStatus err;
        NSFileHandle *audioFileHandle = [NSFileHandle fileHandleForReadingAtPath:self->_filePath];
        if (!audioFileHandle) {
            NSLog(@"文件为空!%@",self->_filePath);
            return;
        }
        NSData *audioFileData=nil;  //每次读取的文件数据
        do{
            if (self->_isFinishing) {
                break;
            }
            audioFileData = [audioFileHandle readDataOfLength:kAudioFileBufferSize];
            NSLog(@"audioFileData: %lu",(unsigned long)(audioFileData.length));
            
            if (self->_isPCMFile) {
                if (![self ParsePCM:audioFileData]) break;
            }else{
                if (![self ParseNOPCM:audioFileData]) break;
            }
        }while(audioFileData && audioFileData.length >= kAudioFileBufferSize );
        
        [audioFileHandle closeFile];
        
        if (self->_isFinishing) return;
        if (self->audioPacketsFilled>0) {
            if (self->_isPCMFile) {
                err = AudioQueueEnqueueBuffer(self->_audioQueue, self->audioQueueBuffers[self->audioQueueCurrentBufferIndex], 0, NULL);
            }else{
                err = AudioQueueEnqueueBuffer(self->_audioQueue, self->audioQueueBuffers[self->audioQueueCurrentBufferIndex], (UInt32)self->audioPacketsFilled, self->audioStreamPacketDesc);
            }
            self->audioQueueCurrentBufferIndex = (self->audioQueueCurrentBufferIndex + 1) % kNumberOfBuffers;
            self->audioPacketsFilled = 0;
            self->audioDataBytesFilled = 0;
            if (!self->_isPlaying) {
                err = AudioQueueStart(self->_audioQueue, NULL);
                self->_isPlaying = YES;
            }
        }
        err = AudioQueueFlush(self->_audioQueue);
    });
}

-(void)pause{
    if (_audioQueue && _isPlaying) {
        AudioQueuePause(_audioQueue);
        _isPlaying = NO;
    }
}

-(void)stop{
    if (_audioQueue && _isPlaying) {
        _isFinishing =YES;
        AudioQueueStop(_audioQueue, YES);
    }
//    if (_audioQueue) {
//        AudioQueueReset(_audioQueue);
//    }
}


-(void)setRouteChange{
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    //建议在播放之前设置yes，播放结束设置NO。这个功能是开启红外感应
    NSNotificationCenter *nsnc = [NSNotificationCenter defaultCenter];
    //设置拔耳机静音
    [nsnc addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    //设置红外感应
    [nsnc addObserver:self selector:@selector(sensorStateChange:) name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
}

//处理监听触发事件
-(void)sensorStateChange:(NSNotificationCenter *)notification;
{
    //假设此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出。并将屏幕变暗（省电啊）
    if ([[UIDevice currentDevice] proximityState] == YES)
    {
        NSLog(@"人靠近设备");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    }
    else
    {
        NSLog(@"人远离设备");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

- (void)handleRouteChange:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    AVAudioSessionRouteChangeReason reason = [info[AVAudioSessionRouteChangeReasonKey] unsignedIntValue];
    //    拔出耳机的时候通知AVAudioSessionRouteChangeReasonOldDeviceUnavailable，指旧设备不可用，例如耳机拔出。插入耳机的时候通知AVAudioSessionRouteChangeReasonNewDeviceAvailable，指新设备可用，例如耳机插入。可以通过这个来控制音频的播放与暂停。
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *previousOutput = previousRoute.outputs[0];
        NSString *portType = previousOutput.portType;
        if ([portType isEqualToString:AVAudioSessionPortHeadphones]) {
            if (_isPlaying) {
                [self stop];//当拔出耳机的时候，停止播放
            }
        }
    }
}

-(void)handleStreamPacketsProc:(UInt32)inNumberBytes inNumberPackets:(UInt32)inNumberPackets inInputData:(const void*)inInputData inPacketDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions{
//    NSLog(@"inNumberBytes:%u inNumberPackets:%u",(unsigned int)inNumberBytes,(unsigned int)inNumberPackets);
    @synchronized(self){
        if (inNumberBytes == 0 || inNumberPackets == 0)
        {
            return;
        }
        
        BOOL deletePackDesc = NO;
        if (!inPacketDescriptions)
        {
            //如果packetDescriptioins不存在，就按照CBR处理，平均每一帧的数据后生成packetDescriptioins
            deletePackDesc = YES;
            UInt32 packetSize = inNumberBytes / inNumberPackets;
            AudioStreamPacketDescription *Descriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * inNumberPackets);
            
            for (int i = 0; i < inNumberPackets; i++)
            {
                UInt32 packetOffset = packetSize * i;
                Descriptions[i].mStartOffset = packetOffset;
                Descriptions[i].mVariableFramesInPacket = 0;
                if (i == inNumberPackets - 1)
                {
                    Descriptions[i].mDataByteSize = inNumberBytes - packetOffset;
                }
                else
                {
                    Descriptions[i].mDataByteSize = packetSize;
                }
            }
            inPacketDescriptions = Descriptions;
        }
        
        
        for (int i=0; i < inNumberPackets; i++) {
            SInt64 mStartOffset = inPacketDescriptions[i].mStartOffset;
            UInt64 mDataByteSize = inPacketDescriptions[i].mDataByteSize;
//            NSLog(@"inNumberPackets:%u mStartOffset:%lli mDataByteSize:%u",(unsigned int)inNumberPackets,mStartOffset,(unsigned int)mDataByteSize);
            
            if (mDataByteSize > kAQBufSize - audioDataBytesFilled) {
                //如果当前要填充的数据大于缓冲区剩余大小, 将当前Buffer送入播放队列,指示将当前帧放入到下一个buffer
                OSStatus err = AudioQueueEnqueueBuffer(_audioQueue, audioQueueBuffers[audioQueueCurrentBufferIndex], (UInt32)audioPacketsFilled, audioStreamPacketDesc);
                audioQueueCurrentBufferIndex = (audioQueueCurrentBufferIndex + 1) % kNumberOfBuffers;
                audioPacketsFilled = 0;
                audioDataBytesFilled = 0;
                
                if (!_isPlaying) {
                    err = AudioQueueStart(_audioQueue, NULL);
                }
                while (inuse[audioQueueCurrentBufferIndex]){
                    if (_isFinishing) {
                        break;
                    }
                }
            }
            if (_isFinishing) return;
            
            AudioQueueBufferRef currentFilledBuffer = audioQueueBuffers[audioQueueCurrentBufferIndex];
            if (!inuse[audioQueueCurrentBufferIndex] ) {
                [sysnLock lock];
                inuse[audioQueueCurrentBufferIndex] = YES;
                [sysnLock unlock];
            }
            
            currentFilledBuffer->mAudioDataByteSize = (UInt32)(audioDataBytesFilled + mDataByteSize);
            memcpy(currentFilledBuffer->mAudioData + audioDataBytesFilled , inInputData + mStartOffset, mDataByteSize);
            audioStreamPacketDesc[audioPacketsFilled] = inPacketDescriptions[i];
            audioStreamPacketDesc[audioPacketsFilled].mStartOffset = audioDataBytesFilled;
            audioDataBytesFilled = audioDataBytesFilled + mDataByteSize;
            audioPacketsFilled = audioPacketsFilled + 1;
            
        }
    }
}

-(void)AudioQueueOutputCallBack:(AudioQueueRef)inAQ inBuffer:(AudioQueueBufferRef)inBuffer{
    for (int i=0; i<kNumberOfBuffers; i++) {
        [sysnLock lock];
        if (inBuffer == audioQueueBuffers[i]) {
            inuse[i]=NO;
        }
        [sysnLock unlock];
    }
    if (_isPlaying) {
        BOOL flag = NO;
        for (int i=0; i<kNumberOfBuffers; i++){
            flag = inuse[i];
            if (flag) {
                break;
            }
        }
        if (!flag) {
            [self freeQueue];
            if (_delegate) {
                //通知主线程刷新
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate ELAudioPlayEnd:self];
                });
            }
        }
    }
}

-(void)AudioQueueIsRunningCallback:(AudioQueuePropertyID)inID {
    UInt32 isRunning, ioDataSize = sizeof(isRunning);
    OSStatus err = AudioQueueGetProperty(_audioQueue, inID, &isRunning, &ioDataSize);
    NSLog(@"isRunning:%u",(unsigned int)isRunning);
    if (err == noErr && isRunning == 1) {
        _isPlaying = YES;
    }
}

-(void)freeQueue{
    NSLog(@"%s",__func__);
    AudioQueueReset(_audioQueue);
    for (int i=0; i<kNumberOfBuffers; i++) {
        AudioQueueFreeBuffer(_audioQueue, audioQueueBuffers[i]);
    }
    AudioQueueDispose(_audioQueue, true);
    _audioQueue = nil;
    AudioFileStreamClose(audioFileStreamID);
}

-(void)ResponseTTS:(NSData *)data result:(NSString *)msg{
    if (data) {
        [data writeToFile:_filePath atomically:YES];
        [self play];
    }else{
        if (_delegate) {
            //通知主线程刷新
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate ELAudioPlayEnd:self];
            });
        }
    }

}

- (AudioFileTypeID)hintForFileExtension:(NSString *)fileExtension
{
    AudioFileTypeID fileTypeHint = kAudioFileAAC_ADTSType;
    if ([fileExtension isEqual:@"pcm"])
    {
        _isPCMFile = YES;
    }
    else if ([fileExtension isEqual:@"mp3"])
    {
        fileTypeHint = kAudioFileMP3Type;
    }
    else if ([fileExtension isEqual:@"wav"])
    {
        fileTypeHint = kAudioFileWAVEType;
    }
    else if ([fileExtension isEqual:@"aifc"])
    {
        fileTypeHint = kAudioFileAIFCType;
    }
    else if ([fileExtension isEqual:@"aiff"])
    {
        fileTypeHint = kAudioFileAIFFType;
    }
    else if ([fileExtension isEqual:@"m4a"])
    {
        fileTypeHint = kAudioFileM4AType;
    }
    else if ([fileExtension isEqual:@"mp4"])
    {
        fileTypeHint = kAudioFileMPEG4Type;
    }
    else if ([fileExtension isEqual:@"caf"])
    {
        fileTypeHint = kAudioFileCAFType;
    }
    else if ([fileExtension isEqual:@"aac"])
    {
        fileTypeHint = kAudioFileAAC_ADTSType;
    }
    return fileTypeHint;
}

void AudioFileStreamPropertyListenerProc(void *inClientData,AudioFileStreamID inAudioFileStream,AudioFileStreamPropertyID inPropertyID,AudioFileStreamPropertyFlags *  ioFlags){
    ELAudioPlayer *audioPlayer = (__bridge ELAudioPlayer*)inClientData;
    OSStatus err;
    switch (inPropertyID) {
        case kAudioFileStreamProperty_DataFormat:
        {
            AudioStreamBasicDescription audioDescription = audioPlayer.audioDescription;
            UInt32 ioPropertyDataSize = sizeof(audioDescription);
            
            AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &ioPropertyDataSize, &audioDescription);
            audioPlayer.audioDescription = audioDescription;
            
        }
            break;
        case kAudioFileStreamProperty_ReadyToProducePackets:
        {
            UInt32 packetsCount, ioPropertyDataSize = sizeof(packetsCount);
            AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &ioPropertyDataSize, &packetsCount);
            
            [audioPlayer createQueue];
            
            UInt32 cookieSize;
            Boolean writable;
            err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
            if (err == noErr && cookieSize>0) {
//                void* cookieData = calloc(1, cookieSize);
                void* cookieData = malloc(cookieSize);
                AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &cookieData);
                
                AudioQueueSetProperty(audioPlayer.audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
            }

            
            AudioQueueAddPropertyListener(audioPlayer.audioQueue, kAudioQueueProperty_IsRunning, ELAudioQueueIsRunningCallback, (__bridge void*)audioPlayer);
            
        }
            break;
        case kAudioFileStreamProperty_FileFormat:
        {
            UInt32 fileFormat, ioPropertyDataSize = sizeof(fileFormat);
            AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &ioPropertyDataSize, &fileFormat);
            NSLog(@"fileFormat:%u",(unsigned int)fileFormat);
        }
            break;
        case kAudioFileStreamProperty_AudioDataByteCount:
        {
            UInt64 dataBytesCount;
            UInt32 ioPropertyDataSize = sizeof(dataBytesCount);
            AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &ioPropertyDataSize, &dataBytesCount);
            audioPlayer.audioFileLength = dataBytesCount;
            if (dataBytesCount >0 && audioPlayer.bitRate >0) {
                NSLog(@"时长: %fs", (dataBytesCount * 8.0) / audioPlayer.bitRate);
                //时长:double duration = (audioDataByteCount * 8) / bitRate
            }
        }
            break;
        case kAudioFileStreamProperty_DataOffset:
        {
            SInt64 audioDataOffset;
            UInt32 ioPropertyDataSize = sizeof(audioPlayer);
            AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &ioPropertyDataSize, &audioDataOffset);
            NSLog(@"audioDataOffset:%lld",audioDataOffset);
        }
             break;
        case kAudioFileStreamProperty_BitRate:
        {
            UInt32 bitRate, ioPropertyDataSize = sizeof(bitRate);
            AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &ioPropertyDataSize, &bitRate);
            audioPlayer.bitRate = bitRate;
        }
             break;
        default:
            break;
    }
}

void AudioFileStreamPacketsProc(void * inClientData,
                              UInt32 inNumberBytes,
                              UInt32 inNumberPackets,
                              const void * inInputData,
                                AudioStreamPacketDescription *inPacketDescriptions){
    ELAudioPlayer *audioPlayer = (__bridge ELAudioPlayer*)inClientData;
    [audioPlayer handleStreamPacketsProc:inNumberBytes inNumberPackets:inNumberPackets inInputData:inInputData inPacketDescriptions:inPacketDescriptions];
}
             
void ELAudioQueueOutputCallback(void * inUserData, AudioQueueRef inAQ,AudioQueueBufferRef inBuffer){
    ELAudioPlayer *audioPlayer = (__bridge ELAudioPlayer*)inUserData;
    [audioPlayer AudioQueueOutputCallBack:inAQ inBuffer:inBuffer];
}

void ELAudioQueueIsRunningCallback(void * __nullable       inUserData,
                                      AudioQueueRef           inAQ,
                                      AudioQueuePropertyID    inID){
    ELAudioPlayer *audioPlayer = (__bridge ELAudioPlayer*)inUserData;
    [audioPlayer AudioQueueIsRunningCallback:inID];
    
}
             
             

@end
