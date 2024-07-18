#import <Foundation/Foundation.h>

@interface AppDuplicator : NSObject

- (NSString *)duplicateAppWithBundleID:(NSString *)appDirectory
                              bundleID:(NSString *)bundleID
                                  name:(NSString *)name;

- (BOOL)copyDirectoryFromPath:(NSString *)srcPath toPath:(NSString *)dstPath;
@end