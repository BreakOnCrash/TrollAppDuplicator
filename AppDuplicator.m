#import "AppDuplicator.h"
#import "thirdparty/SSZipArchive/SSZipArchive.h"
#import "thirdparty/TDUtils.h"

@implementation AppDuplicator

- (NSString *)duplicateAppWithBundleID:(NSString *)appDirectory
                              bundleID:(NSString *)bundleID
                                  name:(NSString *)name {
  uint32_t num = arc4random_uniform(99999) + 1;
  bundleID = [NSString stringWithFormat:@"%@.%u", bundleID, num];

  NSString *tmpPath = [docPath() stringByAppendingPathComponent:bundleID];
  NSString *zipDir = [NSString stringWithFormat:@"%@/ipa", tmpPath];
  NSString *dstAppPath =
      [NSString stringWithFormat:@"%@/Payload/%@", zipDir,
                                 [appDirectory lastPathComponent]];
  if (![self copyDirectoryFromPath:appDirectory toPath:dstAppPath]) {
    NSLog(@"Failed to copy Application directory.");
    return nil;
  }

  NSString *infoPlistPath =
      [dstAppPath stringByAppendingPathComponent:@"Info.plist"];
  NSMutableDictionary *infoPlist =
      [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
  if (!infoPlist) {
    NSLog(@"Failed to read Info.plist file.");
    return nil;
  }

  infoPlist[@"CFBundleDisplayName"] = name;
  infoPlist[@"CFBundleIdentifier"] = bundleID;

  BOOL success = [infoPlist writeToFile:infoPlistPath atomically:YES];
  if (!success) {
    NSLog(@"Failed to write modified Info.plist file.");
    return nil;
  }

  NSString *IPAFile = [NSString
      stringWithFormat:@"%@/%@_%@_duplicated.ipa", docPath(), bundleID, name];
  @try {
    BOOL success = [SSZipArchive createZipFileAtPath:IPAFile
                             withContentsOfDirectory:zipDir
                                 keepParentDirectory:NO
                                    compressionLevel:1
                                            password:nil
                                                 AES:NO
                                     progressHandler:nil];
    return success ? IPAFile : nil;
  } @catch (NSException *e) {
    NSLog(@"[appduplicator] BAAAAAAAARF during ZIP operation!!! , %@", e);
    return nil;
  }
}

- (BOOL)copyDirectoryFromPath:(NSString *)srcPath toPath:(NSString *)dstPath {

  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL isDirectory;
  if (![fileManager fileExistsAtPath:srcPath isDirectory:&isDirectory] ||
      !isDirectory) {
    return NO;
  }

  [fileManager removeItemAtPath:dstPath error:nil];

  if (![fileManager createDirectoryAtPath:dstPath
              withIntermediateDirectories:YES
                               attributes:nil
                                    error:nil]) {
    return NO;
  }

  NSArray *contents = [fileManager contentsOfDirectoryAtPath:srcPath error:nil];
  if (!contents) {
    return NO;
  }

  for (NSString *item in contents) {
    NSString *sourceItemPath = [srcPath stringByAppendingPathComponent:item];
    NSString *destinationItemPath =
        [dstPath stringByAppendingPathComponent:item];
    if (![fileManager copyItemAtPath:sourceItemPath
                              toPath:destinationItemPath
                               error:nil]) {
      return NO;
    }
  }

  return YES;
}

@end
