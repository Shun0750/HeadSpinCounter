//
//  ViewController.m
//  HeadSpinCounter
//
//  Created by Nagao Shun on 2016/03/26.
//  Copyright © 2016年 Shun Nagao. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController
@synthesize videoImageView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //動画ファイルの読み込み
    NSString *videoFilePath = [[NSBundle mainBundle] pathForResource:@"head" ofType:@"MOV"];
    if(videoCapture.open(std::string([videoFilePath UTF8String]))){
        NSLog(@"Opened");
    }else{
        NSLog(@"Failed to open");
    }

    //変数の初期化
    frame_num = 0;
    count = 0;
    status = 0;
    head_center.x = 0;
    head_center.y = 0;
    head_radius   = 0;
    
    [NSTimer scheduledTimerWithTimeInterval:0.05
                                     target:self
                                   selector:@selector(opticalFlow:)
                                   userInfo:nil
                                    repeats:YES];


}

-(void)opticalFlow:(id)sender{
    cv::Mat frame;      //元画像
    cv::Mat grayMat;    //グレースケール
    cv::Mat grayBinaryMat;  //2値化画像

    // 画像の取得
    videoCapture >> frame;

    // 色空間をRGBにし、画像を回転
    cv::cvtColor(frame, frame, CV_BGR2RGB);
    cv::transpose(frame,frame);
    cv::flip(frame, frame, 1);
    
    // グレースケール化
    cv::cvtColor(frame, grayMat, CV_BGR2GRAY);
    
    // エッジ抽出をして２値化
    cv::threshold(grayMat,grayBinaryMat,40,150,cv::THRESH_BINARY);
    cv::Canny( grayBinaryMat, grayBinaryMat, 40, 150, 3 );
    cv::GaussianBlur( grayBinaryMat, grayBinaryMat, cv::Size(3, 3), 2, 2 );
    
    // FAST特徴量を取得
    if(frame_num == 0){
        preGrayMat = grayMat;
    }
    std::vector<cv::Point2f> prevCorners;
    std::vector<cv::Point2f> currCorners;
    std::vector<cv::KeyPoint> keypoint;
    std::vector<cv::KeyPoint> preKeypoint;
    
    cv::FAST(preGrayMat, preKeypoint, 20);
    cv::FAST(grayMat, keypoint, 20);
    
    cv::KeyPoint::convert(preKeypoint, prevCorners);
    cv::KeyPoint::convert(keypoint, currCorners);
    
    cv::cornerSubPix(preGrayMat, prevCorners, cv::Size(5, 5), cv::Size(-1, -1), cv::TermCriteria(cv::TermCriteria::COUNT | cv::TermCriteria::EPS, 30, 0.01));
    cv::cornerSubPix(grayMat, currCorners, cv::Size(5, 5), cv::Size(-1, -1), cv::TermCriteria(cv::TermCriteria::COUNT | cv::TermCriteria::EPS, 30, 0.01));
    
    std::vector<uchar> featuresFound;
    std::vector<float> featuresErrors;
    
    // オプティカルフローを求める
    cv::calcOpticalFlowPyrLK(
                             preGrayMat,
                             grayMat,
                             prevCorners,
                             currCorners,
                             featuresFound,
                             featuresErrors);
    
    // 胴体部分の矩形を取得
    float diffx_sum = 0.0;
    for (int i = 0; i < keypoint.size(); i++) {
        cv::Point p1 = cv::Point((int) prevCorners[i].x, (int) prevCorners[i].y);
        cv::Point p2 = cv::Point((int) currCorners[i].x, (int) currCorners[i].y);
        float diffx = currCorners[i].x - prevCorners[i].x;
        float dist  = pow((currCorners[i].x - prevCorners[i].x),2) + pow((currCorners[i].y - prevCorners[i].y),2);
        
        int dist_from_x = abs((int)currCorners[i].x - body_center.x);
        int dist_from_y = abs((int)currCorners[i].y - body_center.y);
        
        // 極端に小さい/大きいベクトル以外をキューに入れる
        if(dist > 100 && dist < 5000){
            diffx_sum += diffx;
            
            if(frame_num < 10){
                cv::line(frame, p1, p2, cv::Scalar(255, 0, 0), 10);
                featx_arr.push_back((int) currCorners[i].x);
                featy_arr.push_back((int) currCorners[i].y);
                dist_c_x_arr.push_back((int) dist_from_x);
                dist_c_y_arr.push_back((int) dist_from_y);
            }else{
                if(dist_from_x < dist_c_x + 100 && dist_from_y < dist_c_y + 200){
                    float kei = (float)dist_from_x / (float)dist_c_x;
                    kei = kei * 2.0;
                    cv::line(frame, p1, p2, cv::Scalar(255, 0, 0), 10);
                    featx_arr.push_back((int)currCorners[i].x);
                    featy_arr.push_back((int)currCorners[i].y);
                    dist_c_x_arr.push_back((int)((float) dist_from_x* kei));
                    dist_c_y_arr.push_back((int)((float) dist_from_y* kei * 1.5));
                }
            }
            if(featx_arr.size() > 100){
                featx_arr.pop_front();
                featy_arr.pop_front();
                dist_c_x_arr.pop_front();
                dist_c_y_arr.pop_front();
            }
        }
    }
    
    if (featx_arr.size() != 0) {
        body_center.x   = [self calcDequeueAverage:featx_arr];
        body_center.y   = [self calcDequeueAverage:featy_arr];
        dist_c_x  = [self calcDequeueAverage:dist_c_x_arr];
        dist_c_y  = [self calcDequeueAverage:dist_c_y_arr];
        
        body_left_top     = cv::Point([self calcDequeueMin:featx_arr:body_center.x - dist_c_x], [self calcDequeueMin:featy_arr:body_center.y - dist_c_y]);
        body_right_bottom = cv::Point([self calcDequeueMax:featx_arr:body_center.x + dist_c_x], [self calcDequeueMax:featy_arr:body_center.y + dist_c_y]);
        if(head_radius > 0){
            body_right_bottom.y = head_center.y - head_radius;
        }
        
        cv::rectangle(frame, body_left_top, body_right_bottom, cv::Scalar(255, 255, 0),10);
        body_width  = body_right_bottom.x - body_left_top.x;
        body_height = body_right_bottom.y - body_left_top.y;
        
        
    }
    
    // 円形状の認識（頭部認識）
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(grayBinaryMat, circles, CV_HOUGH_GRADIENT, 10, grayBinaryMat.rows /5, 150, 80, 30, 100 );
    for( size_t i = 0; i < circles.size(); i++ )
    {
        cv::Point tmpCenter = cv::Point(cvRound(circles[i][0]),  cvRound(circles[i][1]));
        int radius = cvRound(circles[i][2]);
        cv::Vec3b rgb = frame.ptr<cv::Vec3b>( tmpCenter.y )[tmpCenter.x];
        
        // 円と認識され、黒か肌色のときに頭部と判定
        int is_head = 0;
        if(rgb[0] < 120 && rgb[0] > 60 && rgb[1] > 20 && rgb[1] < 80 && rgb[2] > 0 && rgb[2] < 60){
            is_head = 1;
        }
        if(rgb[0] < 50 && rgb[1] < 50 && rgb[2] < 50){
            is_head = 1;
        }

        if(tmpCenter.y > body_right_bottom.y - body_height / 2 && tmpCenter.y < body_right_bottom.y + body_height / 2 && is_head == 1){
            if(frame_num > 0 && tmpCenter.x < head_center.x + body_width / 3 && tmpCenter.x > head_center.x - body_width / 3 && tmpCenter.y < head_center.y + head_radius && tmpCenter.y > head_center.y - head_radius){
                head_center = tmpCenter;
                head_radius = radius;
            }
        }
        if(frame_num == 0 && is_head == 1){
            head_center = tmpCenter;
            head_radius = radius;
        }
    }
    circle( frame, head_center, head_radius, cvScalar(255,255,0), 3, 8, 0 ); // 円の描画
    
    // 頭部の色分布を取得
    int black_num = 0;
    int brown_num = 0;
    for (int i = head_center.y - head_radius; i < head_center.y + head_radius; i++) {
        cv::Vec3b* ptr = frame.ptr<cv::Vec3b>( i );
        for (int j = head_center.x - head_radius; j < head_center.x + head_radius; j++) {
            cv::Vec3b rgb = ptr[j];
            if(rgb[0] < 120 && rgb[0] > 60 && rgb[1] > 20 && rgb[1] < 80 && rgb[2] > 0 && rgb[2] < 60){
                brown_num++;
            }
            if(rgb[0] < 50 && rgb[1] < 50 && rgb[2] < 50){
                black_num++;
            }
        }
    }
    
    // 顔部分の黒の割合を求める
    int black_rate = 0;
    if(black_num != 0 && brown_num !=0){
        black_rate = black_num * 100 / (brown_num + black_num);
    }
    black_rate_arr.push_back(black_rate);
    if(black_rate_arr.size() > 3){
        black_rate_arr.pop_front();
    }
    int black_rate_sum = 0;
    for(int i = 0;i < black_rate_arr.size();i++){
        black_rate_sum += black_rate_arr[i];
    }
    
    // 回数のカウント
    if(black_rate_sum > 200 && status == 0){
        count++;
        [countLabel setText:[NSString stringWithFormat:@"%d",count]];
        status = 1;
    }
    if(black_rate_sum < 150 && status == 1){
        status = 0;
    }
    
    
    // １コマ前の画像を保存
    preGrayMat = grayMat.clone();
    
    [self.videoImageView setImage:MatToUIImage(frame)];
    frame_num++;
}


- (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                              //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

- (int)calcDequeueAverage:(std::deque< int >) queue
{
    int sum = 0;
    for (int i = 0; i < queue.size(); i++) {
        sum += queue[i];
    }
    return (int)(sum / queue.size());
}

- (int)calcDequeueMin:(std::deque< int >)queue :(int)threshold
{
    int min = 100000;
    for (int i = 0; i < queue.size(); i++) {
        if(min > queue[i] && queue[i] > threshold){
            min = queue[i];
        }
    }
    return min;
}

- (int)calcDequeueMax:(std::deque< int >)queue :(int)threshold
{
    int max = 0;
    for (int i = 0; i < queue.size(); i++) {
        if(max < queue[i] && queue[i] < threshold){
            max = queue[i];
        }
    }
    return max;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
