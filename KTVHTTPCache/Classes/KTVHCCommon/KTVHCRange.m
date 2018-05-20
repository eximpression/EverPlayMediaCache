//
//  KTVHCRange.m
//  KTVHTTPCache
//
//  Created by Single on 2018/5/20.
//  Copyright © 2018年 Single. All rights reserved.
//

#import "KTVHCRange.h"

BOOL KTVHCRangeIsVaild(KTVHCRange range)
{
    return !KTVHCRangeIsInvaild(range);
}

BOOL KTVHCRangeIsInvaild(KTVHCRange range)
{
    return range.start == KTVHCNotFound;
}

BOOL KTVHCEqualRanges(KTVHCRange range1, KTVHCRange range2)
{
    return range1.start == range2.start && range1.end == range2.end;
}

long long KTVHCRangeGetLength(KTVHCRange range)
{
    if (range.start == KTVHCNotFound || range.end == KTVHCNotFound) {
        return KTVHCNotFound;
    }
    return range.end - range.start + 1;
}

NSString * KTVHCStringFromRange(KTVHCRange range)
{
    return [NSString stringWithFormat:@"Range : {%lld, %lld}", range.start, range.end];
}

NSString * KTVHCRangeGetHeaderString(KTVHCRange range)
{
    NSMutableString * string = [NSMutableString stringWithFormat:@"bytes="];
    if (range.start != KTVHCNotFound) {
        [string appendFormat:@"%lld", range.start];
    }
    [string appendFormat:@"-"];
    if (range.end != KTVHCNotFound) {
        [string appendFormat:@"%lld", range.end];
    }
    return [string copy];
}

NSDictionary * KTVHCRangeFillToRequestHeaders(KTVHCRange range, NSDictionary * headers)
{
    NSMutableDictionary * ret = [NSMutableDictionary dictionaryWithDictionary:headers];
    [ret setObject:KTVHCRangeGetHeaderString(range) forKey:@"Range"];
    return ret;
}

NSDictionary * KTVHCRangeFillToResponseHeaders(KTVHCRange range, NSDictionary * headers, long long totalLength)
{
    NSMutableDictionary * ret = [NSMutableDictionary dictionaryWithDictionary:headers];
    long long currentLength = KTVHCRangeGetLength(range);
    [ret setObject:[NSString stringWithFormat:@"%lld", currentLength] forKey:@"Content-Length"];
    [ret setObject:[NSString stringWithFormat:@"bytes %lld-%lld/%lld", range.start, range.end, totalLength] forKey:@"Content-Range"];
    return ret;
}

KTVHCRange KTVHCMakeRange(long long start, long long end)
{
    KTVHCRange range = {start, end};
    return range;
}

KTVHCRange KTVHCRangeZero(void)
{
    return KTVHCMakeRange(0, 0);
}

KTVHCRange KTVHCRangeInvaild()
{
    return KTVHCMakeRange(KTVHCNotFound, KTVHCNotFound);
}

KTVHCRange KTVHCRangeWithHeaderValue(NSString * value)
{
    KTVHCRange range = KTVHCRangeInvaild();
    NSString * rangeHeader = value;
    if (rangeHeader) {
        if ([rangeHeader hasPrefix:@"bytes="]) {
            NSArray * components = [[rangeHeader substringFromIndex:6] componentsSeparatedByString:@","];
            if (components.count == 1) {
                components = [[components firstObject] componentsSeparatedByString:@"-"];
                if (components.count == 2) {
                    NSString * startString = [components objectAtIndex:0];
                    NSInteger startValue = [startString integerValue];
                    NSString * endString = [components objectAtIndex:1];
                    NSInteger endValue = [endString integerValue];
                    if (startString.length && (startValue >= 0)
                        && endString.length && (endValue >= startValue)) {
                        // The second 500 bytes: "500-999"
                        range.start = startValue;
                        range.end = endValue;
                    } else if (startString.length && (startValue >= 0)) {
                        // The bytes after 9500 bytes: "9500-"
                        range.start = startValue;
                        range.end = KTVHCNotFound;
                    } else if (endString.length && (endValue > 0)) {
                        // The final 500 bytes: "-500"
                        range.start = KTVHCNotFound;
                        range.end = endValue;
                    }
                }
            }
        }
    }
    return range;
}

KTVHCRange KTVHCRangeWithEnsureLength(KTVHCRange range, NSUInteger ensureLength)
{
    if (range.end == KTVHCNotFound && ensureLength > 0) {
        return KTVHCMakeRange(range.start, ensureLength - 1);
    }
    return range;
}
