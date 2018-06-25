//
//  ViewController.h
//  AudioRecognitionDemo
//
//  Created by enli on 2018/6/13.
//  Copyright © 2018年 enli. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ELAudioRecorder.h"
#import "ELAudioPlayer.h"

@interface ViewController : UIViewController<ELAudioRecorderDelegate,ELAudioPlayerDelegate,UITextViewDelegate>


@end

