#import "TDUtils.h"
#include <Foundation/Foundation.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import "LSApplicationProxy+AltList.h"

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

    // 读取 mach_header 的前四个字节以确定是 32 位还是 64 位
    uint32_t magic;
    fread(&magic, sizeof(uint32_t), 1, binary);

    if (magic != MH_MAGIC && magic != MH_CIGAM && magic != MH_MAGIC_64 && magic != MH_CIGAM_64) {
        return NO;  // 非有效的 Mach-O 文件
    }
    BOOL is64Bit = (magic == MH_MAGIC_64 || magic == MH_CIGAM_64);

    if (is64Bit) {
        struct mach_header_64 header;
        fseek(binary, offset, SEEK_SET);
        fread(&header, sizeof(struct mach_header_64), 1, binary);
        fseek(binary, offset + sizeof(struct mach_header_64), SEEK_SET);
    } else {
        struct mach_header header;
        fseek(binary, offset, SEEK_SET);
        fread(&header, sizeof(struct mach_header), 1, binary);
        fseek(binary, offset + sizeof(struct mach_header), SEEK_SET);
    }

    struct load_command lc;
    for (uint32_t i = 0; i < (is64Bit ? ((struct mach_header_64 *)(&magic))->ncmds
                                      : ((struct mach_header *)(&magic))->ncmds);
         i++) {
        fread(&lc, sizeof(struct load_command), 1, binary);

        if (lc.cmd == LC_ENCRYPTION_INFO_64 && is64Bit) {
            struct encryption_info_command_64 encryptCmd;
            fseek(binary, -sizeof(struct load_command), SEEK_CUR);
            fread(&encryptCmd, sizeof(struct encryption_info_command_64), 1, binary);
            return encryptCmd.cryptid != 0;
        } else if (lc.cmd == LC_ENCRYPTION_INFO && !is64Bit) {
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