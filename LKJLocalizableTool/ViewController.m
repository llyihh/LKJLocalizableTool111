//
//  ViewController.m
//  LKJLocalizableTool
//
//  Created by LYH on 2021/12/15.
//

#import "ViewController.h"
#import "AFNetworking.h"

#define SRC_PATH        [[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings"]
#define DST_PATH(tl)    [NSString stringWithFormat:@"%@/lprojs/%@.txt", NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES).firstObject, tl]

#define TO_LANGUAGES @{ \
    @"en": @"English # 英语", \
    @"zh-CN": @"Chinese, Simplified # 中文（简体）", \
    @"zh-TW": @"Chinese, Traditional # 中文（繁体）", \
    @"ja": @"Japanese # 日语", \
    @"ru": @"Russian # 俄语", \
    @"de": @"German # 德语", \
    @"fr": @"French # 法语", \
    @"es": @"Spanish # 西班牙语", \
    @"pt": @"Portuguese (Portugal) # 葡萄牙语", \
    @"ko": @"Korean # 韩语", \
    @"vi": @"Vietnamese # 越南语", \
    @"th": @"Thai # 泰语", \
    @"ar": @"Arabic # 阿拉伯语", \
    @"it": @"Italian # 意大利语", \
    @"hi": @"Hindi # 印地语", \
}

#define TRANSLATE_TEXT_URL_STRING @"http://47.88.31.120:80/translate/text"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    NSString *srcContents = [NSString stringWithContentsOfFile:SRC_PATH encoding:NSUnicodeStringEncoding error:nil];
    NSArray *srcComponents = [srcContents componentsSeparatedByString:@"\n"];
    NSPredicate *srcPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH '\"' && SELF CONTAINS ' = ' && SELF ENDSWITH '\";'"];
    srcComponents = [srcComponents filteredArrayUsingPredicate:srcPredicate];
    NSMutableArray *srcValues = [NSMutableArray array];
    for (int i = 0; i < srcComponents.count; i++) {
        NSString *value = [srcComponents[i] componentsSeparatedByString:@" = "].lastObject;
        value = [value substringWithRange:NSMakeRange(1, value.length - 3)];
        [srcValues addObject:value];
    }
    
    NSMutableArray *originalTexts = [NSMutableArray array];
    NSInteger len = 128;
    for (int i = 0; i < ceil(1.f * srcValues.count / len); i++) {
        NSArray *obj = [srcValues subarrayWithRange:NSMakeRange(len * i, MIN(srcValues.count, len * (i + 1)) - len * i)];
        NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:kNilOptions error:nil];
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [originalTexts addObject:text];
    }
    
    dispatch_group_t originalGroup = dispatch_group_create();
    [TO_LANGUAGES.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_enter(originalGroup);
        [self translateTexts:originalTexts tl:obj completion:^(NSDictionary *responseTexts) {
            NSString *dstPath = DST_PATH(TO_LANGUAGES[obj]);
            if (![[NSFileManager defaultManager] fileExistsAtPath:dstPath.stringByDeletingLastPathComponent]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:dstPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:dstPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:dstPath error:nil];
            }
            NSMutableString *dstContents = [srcContents mutableCopy];
            [responseTexts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [dstContents replaceOccurrencesOfString:key withString:obj options:kNilOptions range:NSMakeRange(0, dstContents.length)];
            }];
            [dstContents writeToFile:dstPath atomically:NO encoding:NSUnicodeStringEncoding error:nil];
            NSLog(@"%@ ✅", TO_LANGUAGES[obj]);
            dispatch_group_leave(originalGroup);
        }];
    }];
    dispatch_group_notify(originalGroup, dispatch_get_main_queue(), ^{
        exit(0);
    });
}

- (void)translateTexts:(NSArray *)texts tl:(NSString *)tl completion:(void (^)(NSDictionary *responseTexts))completion {
    NSMutableDictionary *responseTexts = [NSMutableDictionary dictionary];
    dispatch_group_t responseGroup = dispatch_group_create();
    for (int i = 0; i < texts.count; i++) {
        NSDictionary *parameters = @{
            @"textsJson": texts[i],
            @"from": @"auto",
            @"to": tl,
        };
        dispatch_group_enter(responseGroup);
        [[AFHTTPSessionManager manager] POST:TRANSLATE_TEXT_URL_STRING parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [responseObject[@"data"] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *originalText = [NSString stringWithFormat:@"\"%@\";", obj[@"originalText"]];
                NSString *text = [NSString stringWithFormat:@"\"%@\";", obj[@"text"]];
                responseTexts[originalText] = text;
            }];
            dispatch_group_leave(responseGroup);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"%@ ❎\n%@", TO_LANGUAGES[tl], error);
            dispatch_group_leave(responseGroup);
        }];
    }
    dispatch_group_notify(responseGroup, dispatch_get_main_queue(), ^{
        if (completion) completion(responseTexts);
    });
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
