//
//  ViewController.m
//  OpenCVTest
//
//  Created by 彭科铭 on 2018/11/23.
//  Copyright © 2018年 彭科铭. All rights reserved.
//

#import "ViewController.h"
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>

using namespace cv;
using namespace std;

#define SWidth [UIScreen mainScreen].bounds.size.width
#define SHeight [UIScreen mainScreen].bounds.size.height

@interface ViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    vector<Mat> _scaledTempls;
}

@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) UIImageView *templImgView;
@property (nonatomic, strong) UIButton *chooseBtn;
@property (nonatomic, strong) UIButton *matchBtn;

@property (nonatomic, strong) UIImagePickerController *bgPicker;
@property (nonatomic, strong) UIImagePickerController *templPicker;

@property (nonatomic, strong) UIAlertController *alertController;

@end

@implementation ViewController

static const int match_method = CV_TM_CCOEFF_NORMED;        //使用的算法
static const float matchValue = 0.8;                        //识别度80%

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupUI];
}

//UI
- (void)setupUI {
    [self.view addSubview:self.bgImageView];
    [self.view addSubview:self.chooseBtn];
    [self.view addSubview:self.matchBtn];
    [self.view addSubview:self.templImgView];
}

#pragma mark Action
- (void)didClickBtn:(UIButton *)btn {
    if (btn == self.chooseBtn) {
        self.bgImageView.layer.sublayers  = nil;
        [self chooseBGImage];
    } else if (btn == self.matchBtn) {
        if (self.bgImageView.image) {
            if (!self.templImgView.image) {
                self.alertController.message = @"The template image is nil";
                [self presentViewController:self.alertController animated:YES completion:nil];
            } else {
                //创建原始矩阵
                Mat bgMat;
                //将UIImage转为矩阵，并输出在bgMat中
                UIImageToMat(self.bgImageView.image, bgMat);
                //创建缩放矩阵
                Mat bgResize;
                //将bgMat等比例缩放0.5倍，并输出到bgResize中
                resize(bgMat, bgResize, cv::Size(0,0),0.5,0.5);
                //进行模版匹配
                cv::Rect cvRect = [self matchWithMat:bgResize];
                CGRect rect = CGRectMake(cvRect.x, cvRect.y, cvRect.width, cvRect.height);
                
                if (!CGRectEqualToRect(rect, CGRectZero)) {
                    NSLog(@"rect : %@",NSStringFromCGRect(rect));
                    //绘制图框
                    CALayer *matchLayer = [CALayer layer];
                    matchLayer.borderWidth = 1;
                    matchLayer.borderColor = [UIColor redColor].CGColor;
                    matchLayer.frame = rect;
                    
                    [self.bgImageView.layer addSublayer:matchLayer];
                } else {
                    self.alertController.message = @"No match successed";
                    [self presentViewController:self.alertController animated:YES completion:nil];
                }
                
            }
            
        } else {
            self.alertController.message = @"The view doesn't have any image";
            [self presentViewController:self.alertController animated:YES completion:nil];
        }
        
    }
}

//选择背景图
- (void)chooseBGImage {
    [self presentViewController:self.bgPicker animated:YES completion:nil];
}

//选择模版图
- (void)chooseTemplImage {
    [self presentViewController:self.templPicker animated:YES completion:nil];
}

#pragma mark OpenCV Action

//setup Template设置模版
- (void)setupTemplate {
    //定义模版矩阵
    Mat templUp;
    UIImageToMat(self.templImgView.image, templUp);
    
    //设置新模版，清空旧模板
    _scaledTempls.clear();
    
    //将templUp等比例缩放0.5倍，并输出到templateResize中
    Mat templateResize;
    resize(templUp, templateResize, cv::Size(0,0),0.5,0.5);
    //将模版存放模版数组
    _scaledTempls.push_back(templateResize);
    
}

//OpenCV - match 调用OpenCV进行匹配
- (cv::Rect)matchWithMat:(Mat)img {
    //定义结果数据
    double minVal, maxVal;
    cv::Point minLoc, maxLoc, matchLoc;
    
    //取得模版矩阵
    Mat templ = _scaledTempls[0];
    
    //创建结果矩阵，存放匹配到的位置信息
    int result_cols = img.cols - templ.cols + 1;
    int result_rows = img.rows - templ.rows + 1;
    Mat result;
    result.create(result_rows, result_cols, CV_32FC4);
    
    //OpenCV 匹配核心方法
    matchTemplate(img, templ, result, match_method);
    
    //整理出匹配的最大值和最小值
    minMaxLoc(result, &minVal, &maxVal, &minLoc, &maxLoc, Mat());
    
    //对于SQDIFF 和 SQDIFF_NORMED,越小的数值代表更高的匹配效果。其他算法的结果，数值越大越好。
    if (match_method == CV_TM_SQDIFF || match_method == CV_TM_SQDIFF_NORMED) {
        matchLoc = minLoc;
    } else {
        matchLoc = maxLoc;
    }
    
    //识别度达到要求，匹配成功
    if (maxVal >= matchValue) {
        NSLog(@"match point:(%d,%d) minVal:%f, maxVal:%f",matchLoc.x,matchLoc.y,minVal,maxVal);
        return cv::Rect(matchLoc,cv::Size(templ.cols, templ.rows));
    }
    
    //识别度为达到要求，匹配失败
    return cv::Rect();
}


#pragma mark delegate
//选择图片
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
    if (picker == self.bgPicker) {
        self.bgImageView.image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    } else if (picker == self.templPicker) {
        self.templImgView.image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
        
        [self setupTemplate];
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark getter & setter
- (UIImageView *)bgImageView {
    if (!_bgImageView) {
        _bgImageView = [[UIImageView alloc] init];
        _bgImageView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    }
    return _bgImageView;
}

- (UIImageView *)templImgView {
    if (!_templImgView) {
        _templImgView = [[UIImageView alloc] init];
        _templImgView.backgroundColor = [UIColor lightGrayColor];
        _templImgView.frame = CGRectMake(self.view.center.x - 25, (SHeight - 70), 50, 50);
        _templImgView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(chooseTemplImage)];
        [_templImgView addGestureRecognizer:tap];
    }
    return _templImgView;
}

- (UIButton *)chooseBtn {
    if (!_chooseBtn) {
        _chooseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _chooseBtn.frame = CGRectMake(20, (SHeight - 70), (SWidth/2 - 100), 50);
        _chooseBtn.layer.cornerRadius = 5;
        _chooseBtn.layer.masksToBounds = YES;
        [_chooseBtn setTitle:@"choose" forState:UIControlStateNormal];
        [_chooseBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _chooseBtn.backgroundColor = [UIColor redColor];
        [_chooseBtn addTarget:self action:@selector(didClickBtn:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _chooseBtn;
}

- (UIButton *)matchBtn {
    if (!_matchBtn) {
        _matchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _matchBtn.frame = CGRectMake((SWidth/2 + 80), (SHeight - 70), (SWidth/2 - 100), 50);
        _matchBtn.layer.cornerRadius = 5;
        _matchBtn.layer.masksToBounds = YES;
        [_matchBtn setTitle:@"match" forState:UIControlStateNormal];
        [_matchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _matchBtn.backgroundColor = [UIColor greenColor];
        [_matchBtn addTarget:self action:@selector(didClickBtn:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _matchBtn;
}

- (UIImagePickerController *)bgPicker {
    if (!_bgPicker) {
        _bgPicker = [[UIImagePickerController alloc] init];
        _bgPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        _bgPicker.delegate = self;
    }
    return _bgPicker;
}

- (UIImagePickerController *)templPicker {
    if (!_templPicker) {
        _templPicker = [[UIImagePickerController alloc] init];
        _templPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        _templPicker.delegate = self;
    }
    return _templPicker;
}

- (UIAlertController *)alertController {
    if (!_alertController) {
        _alertController = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ensure = [UIAlertAction actionWithTitle:@"ensure" style:UIAlertActionStyleDefault handler:nil];
        
        [_alertController addAction:ensure];
        
    }
    return _alertController;
}

@end
