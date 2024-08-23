#import "TDUtils.h"
#include <Foundation/Foundation.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import "LSApplicationProxy+AltList.h"

NSArray *appList(void) {
    NSMutableArray *apps = [NSMutableArray array];

    NSArray<LSApplicationProxy *> *installedApplications =
        [[LSApplicationWorkspace defaultWorkspace] atl_allInstalledApplications];
    [installedApplications enumerateObjectsUsingBlock:^(LSApplicationProxy *proxy, NSUInteger idx,
                                                        BOOL *stop) {
      if ([proxy atl_isHidden]) return;

      NSString *bundleID = bundleID = [proxy atl_bundleIdentifier];

      if (![proxy.applicationType isEqualToString:@"User"]) {
          if ([bundleID hasPrefix:@"com.apple."]) return;   // system App
          if ([bundleID hasPrefix:@"com.opa334."]) return;  // some like trollstore App
          if ([bundleID isEqualToString:@"com.zznq.trollappduplicator"]) return;  // Self
      }

      NSURL *appURL = [proxy performSelector:@selector(bundleURL)];
      if (![appURL.path hasPrefix:@"/private/var/containers/Bundle/Application/"]) return;

      NSMutableDictionary *infoPlist = [NSMutableDictionary
          dictionaryWithContentsOfFile:[appURL.path stringByAppendingPathComponent:@"Info.plist"]];
      if (!infoPlist || !infoPlist[@"CFBundleExecutable"]) return;

      NSString *path = appURL.path;
      NSString *name = [proxy atl_nameToDisplay];
      NSString *version = [proxy atl_shortVersionString];

      if (!bundleID || !name || !version || !path) return;

      NSDictionary *item = @{
          @"bundleID" : bundleID,
          @"name" : name,
          @"path" : path,
          @"version" : version,
          @"encrypted" : [NSNumber
              numberWithBool:isBinaryEncrypted([path stringByAppendingPathComponent:
                                                         infoPlist[@"CFBundleExecutable"]])]
      };

      [apps addObject:item];
    }];

    NSSortDescriptor *descriptor =
        [[NSSortDescriptor alloc] initWithKey:@"name"
                                    ascending:YES
                                     selector:@selector(localizedCaseInsensitiveCompare:)];
    [apps sortUsingDescriptors:@[ descriptor ]];

    return [apps copy];
}

NSUInteger iconFormat(void) {
    return (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) ? 8 : 10;
}

NSString *docPath(void) {
    NSError *error = nil;
    [[NSFileManager defaultManager]
              createDirectoryAtPath:@"/var/mobile/Library/TrollAppDuplicator/duplicated"
        withIntermediateDirectories:YES
                         attributes:nil
                              error:&error];
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
            NSString *filePath =
                [[docPath() stringByAppendingPathComponent:file] stringByStandardizingPath];

            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            NSDate *modificationDate = fileAttributes[NSFileModificationDate];

            NSDictionary *fileInfo = @{@"fileName" : file, @"modificationDate" : modificationDate};
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

BOOL isArchitectureEncrypted(FILE *binary, uint32_t offset) {
    fseek(binary, offset, SEEK_SET);

    struct mach_header_64 header;
    fread(&header, sizeof(struct mach_header_64), 1, binary);

    if (header.magic != MH_MAGIC_64 && header.magic != MH_MAGIC) {
        return NO;
    }

    fseek(binary, offset + sizeof(struct mach_header_64), SEEK_SET);

    struct load_command lc;
    for (uint32_t i = 0; i < header.ncmds; i++) {
        fread(&lc, sizeof(struct load_command), 1, binary);

        if (lc.cmd == LC_ENCRYPTION_INFO_64) {
            struct encryption_info_command_64 encryptCmd;
            fseek(binary, -sizeof(struct load_command), SEEK_CUR);
            fread(&encryptCmd, sizeof(struct encryption_info_command_64), 1, binary);
            return encryptCmd.cryptid != 0;
        } else if (lc.cmd == LC_ENCRYPTION_INFO) {
            struct encryption_info_command encryptCmd;
            fseek(binary, -sizeof(struct load_command), SEEK_CUR);
            fread(&encryptCmd, sizeof(struct encryption_info_command), 1, binary);
            return encryptCmd.cryptid != 0;
        }

        fseek(binary, lc.cmdsize - sizeof(struct load_command), SEEK_CUR);
    }

    return NO;
}

BOOL isBinaryEncrypted(NSString *path) {
    FILE *binary = fopen([path fileSystemRepresentation], "rb");
    if (!binary) return NO;

    struct fat_header fatHeader;
    fread(&fatHeader, sizeof(struct fat_header), 1, binary);

    if (fatHeader.magic == FAT_MAGIC || fatHeader.magic == FAT_CIGAM) {
        uint32_t nfat_arch = OSSwapBigToHostInt32(fatHeader.nfat_arch);
        if (nfat_arch > 1) {
            struct fat_arch arch;
            fread(&arch, sizeof(struct fat_arch), 1, binary);
            uint32_t offset = OSSwapBigToHostInt32(arch.offset);
            if (isArchitectureEncrypted(binary, offset)) {
                fclose(binary);
                return YES;
            }
        }
    } else {
        // Not a FAT binary, check as regular Mach-O
        if (isArchitectureEncrypted(binary, 0)) {
            fclose(binary);
            return YES;
        }
    }

    fclose(binary);
    return NO;
}