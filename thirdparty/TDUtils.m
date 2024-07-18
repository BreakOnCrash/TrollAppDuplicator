#import "TDUtils.h"
#import "LSApplicationProxy+AltList.h"
#include <Foundation/NSString.h>

NSArray *appList(void) {
  NSMutableArray *apps = [NSMutableArray array];

  NSArray<LSApplicationProxy *> *installedApplications =
      [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
  [installedApplications enumerateObjectsUsingBlock:^(LSApplicationProxy *proxy,
                                                      NSUInteger idx,
                                                      BOOL *stop) {
    if ([proxy atl_isHidden])
      return;

    NSString *bundleID = bundleID = [proxy atl_bundleIdentifier];

    if (![proxy.applicationType isEqualToString:@"User"]) {
      if ([bundleID hasPrefix:@"com.apple."])
        return;
      if ([bundleID hasPrefix:@"com.opa334."])
        return;
      if ([bundleID isEqualToString:@"com.zznq.trollappduplicator"])
        return;
    }

    NSURL *appURL = [proxy performSelector:@selector(bundleURL)];
    if (![appURL.path hasPrefix:@"/private/var/containers/Bundle/Application/"])
      return;

    NSString *path = appURL.path;
    NSString *name = [proxy atl_nameToDisplay];
    NSString *version = [proxy atl_shortVersionString];

    if (!bundleID || !name || !version || !path)
      return;

    NSDictionary *item = @{
      @"bundleID" : bundleID,
      @"name" : name,
      @"path" : path,
      @"version" : version
    };

    [apps addObject:item];
  }];

  NSSortDescriptor *descriptor = [[NSSortDescriptor alloc]
      initWithKey:@"name"
        ascending:YES
         selector:@selector(localizedCaseInsensitiveCompare:)];
  [apps sortUsingDescriptors:@[ descriptor ]];

  return [apps copy];
}

NSUInteger iconFormat(void) {
  return (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
             ? 8
             : 10;
}

NSString *docPath(void) {
    NSError * error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/mobile/Library/TrollAppDuplicator/duplicated" withIntermediateDirectories:YES attributes:nil error:&error];
    if (error != nil) {
        NSLog(@"[TrollAppDuplicator] error creating directory: %@", error);
    }

    return @"/var/mobile/Library/TrollAppDuplicator/duplicated";
}

NSArray *duplicatedFileList(void) {
    NSMutableArray *files = [NSMutableArray array];
    NSMutableArray *fileNames = [NSMutableArray array];

    // iterate through all files in the Documents directory
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtPath:docPath()];

    NSString *file;
    while (file = [directoryEnumerator nextObject]) {
        if ([[file pathExtension] isEqualToString:@"ipa"]) {
            NSString *filePath = [[docPath() stringByAppendingPathComponent:file] stringByStandardizingPath];

            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            NSDate *modificationDate = fileAttributes[NSFileModificationDate];

            NSDictionary *fileInfo = @{@"fileName": file, @"modificationDate": modificationDate};
            [files addObject:fileInfo];
        }
    }

    // Sort the array based on modification date
    NSArray *sortedFiles = [files sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDate *date1 = [obj1 objectForKey:@"modificationDate"];
        NSDate *date2 = [obj2 objectForKey:@"modificationDate"];
        return [date2 compare:date1];
    }];

    // Get the file names from the sorted array
    for (NSDictionary *fileInfo in sortedFiles) {
        [fileNames addObject:[fileInfo objectForKey:@"fileName"]];
    }

    return [fileNames copy];
}