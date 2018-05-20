//
//  KTVHCDataUnit.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/11.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCDataUnit.h"
#import "KTVHCURLTools.h"
#import "KTVHCPathTools.h"
#import "KTVHCLog.h"

@interface KTVHCDataUnit ()

@property (nonatomic, strong) NSRecursiveLock * coreLock;
@property (nonatomic, strong) NSMutableArray <KTVHCDataUnitItem *> * unitItemsInternal;

@end

@implementation KTVHCDataUnit

+ (instancetype)unitWithURL:(NSURL *)URL
{
    return [[self alloc] initWithURL:URL];
}

- (instancetype)initWithURL:(NSURL *)URL
{
    if (self = [super init])
    {
        KTVHCLogAlloc(self);
        _URL = URL;
        _uniqueIdentifier = [KTVHCURLTools uniqueIdentifierWithURL:self.URL];
        _createTimeInterval = [NSDate date].timeIntervalSince1970;
        [self prepare];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init])
    {
        _URL = [NSURL URLWithString:[aDecoder decodeObjectForKey:@"URLString"]];
        _uniqueIdentifier = [aDecoder decodeObjectForKey:@"uniqueIdentifier"];
        _createTimeInterval = [[aDecoder decodeObjectForKey:@"createTimeInterval"] doubleValue];
        _requestHeaders = [aDecoder decodeObjectForKey:@"requestHeaderFields"];
        _responseHeaders = [aDecoder decodeObjectForKey:@"responseHeaderFields"];
        _totalLength = [[aDecoder decodeObjectForKey:@"totalContentLength"] longLongValue];
        self.unitItemsInternal = [aDecoder decodeObjectForKey:@"unitItems"];
        [self prepare];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.URL.absoluteString forKey:@"URLString"];
    [aCoder encodeObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];
    [aCoder encodeObject:@(self.createTimeInterval) forKey:@"createTimeInterval"];
    [aCoder encodeObject:self.requestHeaders forKey:@"requestHeaderFields"];
    [aCoder encodeObject:self.responseHeaders forKey:@"responseHeaderFields"];
    [aCoder encodeObject:@(self.totalLength) forKey:@"totalContentLength"];
    [aCoder encodeObject:self.unitItemsInternal forKey:@"unitItems"];
}

- (void)dealloc
{
    KTVHCLogDealloc(self);
}

- (void)prepare
{
    [self lock];
    if (!self.unitItemsInternal) {
        self.unitItemsInternal = [NSMutableArray array];
    }
    if (self.unitItemsInternal.count > 0) {
        NSMutableArray * removeArray = [NSMutableArray array];
        for (KTVHCDataUnitItem * obj in self.unitItemsInternal) {
            if (obj.length <= 0) {
                [removeArray addObject:obj];
            }
        }
        [self.unitItemsInternal removeObjectsInArray:removeArray];
        [removeArray removeAllObjects];
        [self sortUnitItems];
    }
    KTVHCLogDataUnit(@"prepare result, %@, %ld", self.URL, (long)self.unitItemsInternal.count);
    [self unlock];
}

- (void)sortUnitItems
{
    [self lock];
    [self.unitItemsInternal sortUsingComparator:^NSComparisonResult(KTVHCDataUnitItem * obj1, KTVHCDataUnitItem * obj2) {
        NSComparisonResult result = NSOrderedDescending;
        if (obj1.offset < obj2.offset) {
            result = NSOrderedAscending;
        } else if ((obj1.offset == obj2.offset) && (obj1.length > obj2.length)) {
            result = NSOrderedAscending;
        }
        return result;
    }];
    [self unlock];
}

- (NSArray <KTVHCDataUnitItem *> *)unitItems
{
    [self lock];
    NSMutableArray * objs = [NSMutableArray array];
    [self.unitItemsInternal enumerateObjectsUsingBlock:^(KTVHCDataUnitItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [objs addObject:[obj copy]];
    }];
    [self unlock];
    return [objs copy];
}

- (void)insertUnitItem:(KTVHCDataUnitItem *)unitItem
{
    [self lock];
    [self.unitItemsInternal addObject:unitItem];
    [self sortUnitItems];
    KTVHCLogDataUnit(@"insert unit item, %lld", unitItem.offset);
    [self unlock];
    [self.fileDelegate unitShouldRearchive:self];
}

- (void)updateRequestHeaders:(NSDictionary *)requestHeaders
{
    [self lock];
    _requestHeaders = requestHeaders;
    KTVHCLogDataUnit(@"update request\n%@", self.requestHeaders);
    [self unlock];
    [self.fileDelegate unitShouldRearchive:self];
}

- (void)updateResponseHeaders:(NSDictionary *)responseHeaders totalLength:(long long)totalLength
{
    [self lock];
    _responseHeaders = responseHeaders;
    _totalLength = totalLength;
    KTVHCLogDataUnit(@"update response\n%@", self.responseHeaders);
    [self unlock];
    [self.fileDelegate unitShouldRearchive:self];
}

- (NSString *)filePath
{
    [self lock];
    NSString * filePath = nil;
    KTVHCDataUnitItem * item = self.unitItemsInternal.firstObject;
    if (item.offset == 0
        && item.length > 0
        && item.length == self.totalLength)
    {
        filePath = item.absolutePath;
    }
    [self unlock];
    return filePath;
}

- (long long)cacheLength
{
    [self lock];
    long long length = 0;
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        length += obj.length;
    }
    [self unlock];
    return length;
}

- (long long)validLength
{
    [self lock];
    long long offset = 0;
    long long length = 0;
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        long long invalidLength = MAX(offset - obj.offset, 0);
        long long vaildLength = MAX(obj.length - invalidLength, 0);
        offset = MAX(offset, obj.offset + obj.length);
        length += vaildLength;
    }
    [self unlock];
    return length;
}

- (NSTimeInterval)lastItemCreateInterval
{
    [self lock];
    NSTimeInterval timeInterval = self.createTimeInterval;
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
    {
        if (obj.createTimeInterval > timeInterval) {
            timeInterval = obj.createTimeInterval;
        }
    }
    [self unlock];
    return timeInterval;
}

- (void)workingRetain
{
    [self lock];
    _workingCount++;
    KTVHCLogDataUnit(@"working retain, %@, %ld", self.URL, (long)self.workingCount);
    [self unlock];
}

- (void)workingRelease
{
    [self lock];
    _workingCount--;
    KTVHCLogDataUnit(@"working release, %@, %ld", self.URL, (long)self.workingCount);
    if (self.workingCount <= 0) {
        if ([self mergeFilesIfNeeded]) {
            NSAssert(self.fileDelegate, @"archive callback can't be nil.");
            [self.fileDelegate unitShouldRearchive:self];
        }
    }
    [self unlock];
}

- (void)deleteFiles
{
    [self lock];
    NSString * path = [KTVHCPathTools absolutePathForDirectoryWithURL:self.URL];
    [KTVHCPathTools deleteFolderAtPath:path];
    [self unlock];
}

- (BOOL)mergeFilesIfNeeded
{
    [self lock];
    if (self.workingCount > 0 || self.unitItemsInternal.count <= 1)
    {
        [self unlock];
        return NO;
    }
    BOOL success = NO;
    if (self.totalLength == self.validLength)
    {
        long long offset = 0;
        NSString * path = [KTVHCPathTools absolutePathForCompleteFileWithURL:self.URL];
        [KTVHCPathTools deleteFileAtPath:path];
        [KTVHCPathTools createFileIfNeeded:path];
        NSFileHandle * writingHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        for (KTVHCDataUnitItem * obj in self.unitItemsInternal)
        {
            NSAssert(offset >= obj.offset, @"invaild unit item.");
            if (offset >= (obj.offset + obj.length)) {
                KTVHCLogDataUnit(@"merge files continue");
                continue;
            }
            NSFileHandle * readingHandle = [NSFileHandle fileHandleForReadingAtPath:obj.absolutePath];
            @try {
                [readingHandle seekToFileOffset:offset - obj.offset];
            } @catch (NSException * exception) {
                KTVHCLogDataUnit(@"merge files seek exception");
            }
            while (YES) {
                @autoreleasepool {
                    NSData * data = [readingHandle readDataOfLength:1024 * 1024];
                    if (data.length <= 0) {
                        KTVHCLogDataUnit(@"merge files break");
                        break;
                    }
                    KTVHCLogDataUnit(@"merge files write data, %lld", (long long)data.length);
                    [writingHandle writeData:data];
                }
            }
            [readingHandle closeFile];
            offset = obj.offset + obj.length;
            KTVHCLogDataUnit(@"merge files next, %lld", offset);
        }
        [writingHandle synchronizeFile];
        [writingHandle closeFile];
        KTVHCLogDataUnit(@"merge files finish, %@, %lld, %lld", path, self.cacheLength, offset);
        if ([KTVHCPathTools sizeOfItemAtFilePath:path] == self.totalLength)
        {
            KTVHCLogDataUnit(@"merge files replace unit item");
            NSString * relativePath = [KTVHCPathTools relativePathForCompleteFileWithURL:self.URL];
            KTVHCDataUnitItem * item = [[KTVHCDataUnitItem alloc] initWithPath:relativePath];
            for (KTVHCDataUnitItem * obj in self.unitItemsInternal) {
                [KTVHCPathTools deleteFileAtPath:obj.absolutePath];
            }
            [self.unitItemsInternal removeAllObjects];
            [self.unitItemsInternal addObject:item];
            success = YES;
        }
    }
    [self unlock];
    return success;
}

- (void)lock
{
    if (!self.coreLock) {
        self.coreLock = [[NSRecursiveLock alloc] init];
    }
    [self.coreLock lock];
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal) {
        [obj lock];
    }
}

- (void)unlock
{
    for (KTVHCDataUnitItem * obj in self.unitItemsInternal) {
        [obj unlock];
    }
    [self.coreLock unlock];
}

@end
