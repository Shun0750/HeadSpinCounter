//
//  ViewController.h
//  HeadSpinCounter
//
//  Created by Nagao Shun on 2016/03/26.
//  Copyright © 2016年 Shun Nagao. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <opencv2/opencv.hpp>
#import <opencv2/highgui.hpp>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgcodecs/ios.h>
#include "opencv2/video.hpp"
#include "opencv2/videoio.hpp"
#include "opencv2/videoio/cap_ios.h"

@interface ViewController : UIViewController{
    IBOutlet UIImageView *videoImageView;
    IBOutlet UILabel *countLabel;

    // 画像関係
    cv::VideoCapture videoCapture;
    cv::Mat preGrayMat;

    //カウント系
    int frame_num;
    int count;
    int status;

    //胴体部分
    cv::Point body_center;
    cv::Point body_left_top;
    cv::Point body_right_bottom;
    int       body_height;
    int       body_width;

    //頭部
    cv::Point head_center;
    int head_radius;
    std::deque< int > black_rate_arr;

    //計算用
    int dist_c_x;
    int dist_c_y;
    std::deque< int > featx_arr;
    std::deque< int > featy_arr;
    std::deque< int > dist_c_x_arr;
    std::deque< int > dist_c_y_arr;
}

#pragma mark - Protocol CvVideoCameraDelegate


@property (nonatomic, retain) UIImageView *videoImageView;

@end

