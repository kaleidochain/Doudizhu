/****************************************************************************
 Copyright (c) 2013      cocos2d-x.org
 Copyright (c) 2013-2016 Chukong Technologies Inc.
 Copyright (c) 2017-2018 Xiamen Yaji Software Co., Ltd.

 http://www.cocos2d-x.org

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
****************************************************************************/

#import "RootViewController.h"
#import "cocos2d.h"

#include "platform/CCApplication.h"
#include "platform/ios/CCEAGLView-ios.h"

#include <Gengine/Gengine.h>
#import "NativeGengine.h"
#import <CommonCrypto/CommonDigest.h>

@implementation RootViewController

/*
// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
// Custom initialization
}
return self;
}
*/

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    // Set EAGLView as view of RootViewController
    self.view = (__bridge CCEAGLView *)cocos2d::Application::getInstance()->getView();
}

- (NSString*)fileMD5:(NSString*)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if( handle== nil ) return @"ERROR GETTING FILE MD5"; // file didnt exist

    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);

    BOOL done = NO;
    while(!done) {
        NSData* fileData = [handle readDataOfLength: 4096 ];
        CC_MD5_Update(&md5, [fileData bytes], (CC_LONG)[fileData length]);
        if( [fileData length] == 0 ) done = YES;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1],
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    return s;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];

    NSError *error = nil;
    NSString *dataDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *portalBundlePath = [[NSBundle mainBundle] pathForResource:@"portal" ofType:@"lua"];
    BOOL bExist = [[NSFileManager defaultManager] fileExistsAtPath:portalBundlePath];
    NSLog(@"portalBundlePath: %@, exists: %i", portalBundlePath, bExist);
    NSString *portalPath = dataDir;
    portalPath = [portalPath stringByAppendingString:@"/portal.lua"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:portalPath]) {
        BOOL retVal = [[NSFileManager defaultManager] copyItemAtPath:portalBundlePath toPath:portalPath error:&error];
        NSLog(@"copy return %i, error: %@", retVal, error);
    } else {
        NSString *srcMD5 = [self fileMD5:portalBundlePath];
        NSString *dstMD5 = [self fileMD5:portalPath];
        NSLog(@"MD5: %@, portalBundlePath: %@", srcMD5, portalBundlePath);
        NSLog(@"MD5: %@, portalPath: %@", dstMD5, portalPath);
        if (![srcMD5 isEqualToString:dstMD5]) {
            BOOL retVal = [[NSFileManager defaultManager] removeItemAtPath:portalPath error:&error];
            NSLog(@"delete return %i, error: %@", retVal, error);
            retVal = [[NSFileManager defaultManager] copyItemAtPath:portalBundlePath toPath:portalPath error:&error];
            NSLog(@"copy return %i, error: %@", retVal, error);
        }
    }
    BOOL b = GengineSetDataDirectory(dataDir, &error);
    NSLog(@"b: %i, error: %@", b, error);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}


// For ios6, use supportedInterfaceOrientations & shouldAutorotate instead
#ifdef __IPHONE_6_0
- (NSUInteger) supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}
#endif

- (BOOL) shouldAutorotate {
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

//fix not hide status on ios7
- (BOOL)prefersStatusBarHidden {
    return YES;
}

// Controls the application's preferred home indicator auto-hiding when this view controller is shown.
- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}


@end
