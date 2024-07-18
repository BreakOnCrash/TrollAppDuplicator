#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:
                 (NSString *)bundleIdentifier
                                               format:(NSUInteger)format
                                                scale:(CGFloat)scale;
@end

NSUInteger iconFormat(void);
NSString *docPath(void);
NSArray *duplicatedFileList(void);