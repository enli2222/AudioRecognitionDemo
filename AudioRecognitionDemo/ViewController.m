//
//  ViewController.m
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/13.
//  Copyright © 2018年 enli. All rights reserved.
//

#import "ViewController.h"

@interface ViewController (){
    UIButton *btnRecord,*btnPlay;
    UITextView *txtResult;
    ELAudioRecorder *_recorder;
    ELAudioPlayer *_player;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    int width = self.view.bounds.size.width;
    int top = self.view.bounds.size.height;
    
    btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    btnPlay.backgroundColor = [UIColor blueColor];
    btnPlay.frame = CGRectMake(20, top - 110 , width - 40, 40);
    [btnPlay addTarget:self action:@selector(onPlay:) forControlEvents:UIControlEventTouchUpInside];
    [btnPlay setTitle:@"播放" forState:UIControlStateNormal];
    btnPlay.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [self.view addSubview:btnPlay];
    
    btnRecord = [UIButton buttonWithType:UIButtonTypeCustom];
    btnRecord.backgroundColor = [UIColor blueColor];
    btnRecord.frame = CGRectMake(20, top - 50 , width - 40, 40);
    [btnRecord addTarget:self action:@selector(onRecordStart:) forControlEvents:UIControlEventTouchDown];
    [btnRecord addTarget:self action:@selector(onRecordEnd:) forControlEvents:UIControlEventTouchUpInside];
    [btnRecord setTitle:@"录音" forState:UIControlStateNormal];
    btnRecord.titleLabel.font = [UIFont systemFontOfSize:15.0];
    [self.view addSubview:btnRecord];
    
    txtResult = [[UITextView alloc] initWithFrame:CGRectMake(20, 32, width - 40, top - 180)];
    // 设置文本字体
    txtResult.font = [UIFont fontWithName:@"Arial" size:16.5f];
    // 设置文本颜色
    txtResult.textColor = [UIColor colorWithRed:51/255.0f green:51/255.0f blue:51/255.0f alpha:1.0f];
    // 设置文本框背景颜色
    txtResult.backgroundColor = [UIColor whiteColor];
    // 设置文本对齐方式
    txtResult.textAlignment = NSTextAlignmentLeft;
    // 设置自动纠错方式
    txtResult.autocorrectionType = UITextAutocorrectionTypeNo;
    
    //外框
    txtResult.layer.borderColor = [UIColor redColor].CGColor;
    txtResult.layer.borderWidth = 1;
    txtResult.layer.cornerRadius =5;
    txtResult.delegate =self;
    [self.view addSubview:txtResult];
}

-(IBAction)onRecordStart:(id)sender{
    if (!_recorder) {
        txtResult.text = @"";
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [path stringByAppendingPathComponent:@"FinalAudio.pcm"];
        _recorder = [[ELAudioRecorder alloc]initWithPath:filePath];
        _recorder.delegate = self;
        [_recorder recordStart];
        btnRecord.backgroundColor = [UIColor redColor];
    }
}

-(IBAction)onRecordEnd:(id)sender{
    if (_recorder) {
        [_recorder recordEnd];
        _recorder = nil;
        btnRecord.backgroundColor = [UIColor blueColor];
    }
}

-(IBAction)onPlay:(id)sender{
//    NSString *audioFile= [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
//    NSString *audioFile= [[NSBundle mainBundle] pathForResource:@"FinalAudio" ofType:@"wav"];
    NSString *audioFile= [[NSBundle mainBundle] pathForResource:@"zhong" ofType:@"pcm"];
//    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
//    NSString *audioFile = [path stringByAppendingPathComponent:@"FinalAudio.pcm"];
    if (_player) {
        btnPlay.backgroundColor = [UIColor blueColor];
        [btnPlay setTitle:@"播放" forState:UIControlStateNormal];
        [_player stop];
        _player = nil;
    }else{
        btnPlay.backgroundColor = [UIColor redColor];
        [btnPlay setTitle:@"停止" forState:UIControlStateNormal];
        _player = [[ELAudioPlayer alloc] initWithURL:audioFile];
        _player.delegate = self;
        [_player play];
    }
    

}

-(void)ElAudioRecorderChangePower:(ELAudioRecorder *)recorder power:(int)power msg:(NSString *)msg{
    NSString *_msg = [txtResult.text stringByAppendingString:msg];
    txtResult.text = _msg;
}

-(void)ELAudioPlayEnd:(ELAudioPlayer *)player{
    [btnPlay setTitle:@"播放" forState:UIControlStateNormal];
    btnPlay.backgroundColor = [UIColor blueColor];
    _player = nil;
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
