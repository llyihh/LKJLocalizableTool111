//
//  ViewController.m
//  LKJLocalizableTool
//
//  Created by LYH on 2021/12/15.
//

#import "ViewController.h"
#import "AFNetworking.h"

#define PATH_SRC        [[NSBundle mainBundle] pathForResource:@"Localizable" ofType:@"strings"]
#define PATH_DST(tl)    [NSString stringWithFormat:@"%@/lprojs/%@.txt", NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject, tl]

#define LANGUAGES_TO @{ \
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

/// 测试
#define URL_TRANSLATE_TEXT @"http://47.88.31.120:80/translate/text"
/// 正式
//#define URL_TRANSLATE_TEXT @"http://47.251.3.213:80/translate/text"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    NSString *srcContents = [NSString stringWithContentsOfFile:PATH_SRC encoding:NSUnicodeStringEncoding error:nil];
    NSArray *srcComponents = [[srcContents componentsSeparatedByString:@"\n"] filteredArrayUsingPredicate:({
        [NSPredicate predicateWithFormat:@"SELF BEGINSWITH '\"' && SELF CONTAINS ' = ' && SELF ENDSWITH '\";'"];
    })];
    NSMutableArray *srcValues = [NSMutableArray array];
    for (int i = 0; i < srcComponents.count; i++) {
        NSString *value = [srcComponents[i] componentsSeparatedByString:@" = "].lastObject;
        value = [value substringWithRange:NSMakeRange(1, value.length - 3)];
        value = [value stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
        [srcValues addObject:value];
    }
    
    NSMutableArray *srcTexts = [NSMutableArray array];
    NSInteger srcLen = 128;
    for (int i = 0; i < ceil(1.f * srcValues.count / srcLen); i++) {
        NSArray *values = [srcValues subarrayWithRange:NSMakeRange(srcLen * i, MIN(srcValues.count, srcLen * (i + 1)) - srcLen * i)];
        NSData *data = [NSJSONSerialization dataWithJSONObject:values options:kNilOptions error:nil];
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [srcTexts addObject:text];
    }
    
    dispatch_group_t srcGroup = dispatch_group_create();
    [LANGUAGES_TO.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_enter(srcGroup);
        [self translateTexts:srcTexts tl:obj completion:^(NSDictionary *responseTexts) {
            NSString *dstPath = PATH_DST(LANGUAGES_TO[obj]);
            if (![[NSFileManager defaultManager] fileExistsAtPath:dstPath.stringByDeletingLastPathComponent]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:dstPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:dstPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:dstPath error:nil];
            }
            NSMutableString *dstContents = [srcContents mutableCopy];
            [responseTexts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [dstContents replaceOccurrencesOfString:[NSString stringWithFormat:@"\"%@\";", key]
                                             withString:[NSString stringWithFormat:@"\"%@\";", obj]
                                                options:kNilOptions
                                                  range:NSMakeRange(0, dstContents.length)];
            }];
            [dstContents writeToFile:dstPath atomically:NO encoding:NSUnicodeStringEncoding error:nil];
            dispatch_group_leave(srcGroup);
            NSLog(@"🟢 %@", LANGUAGES_TO[obj]);
        }];
    }];
    dispatch_group_notify(srcGroup, dispatch_get_main_queue(), ^{
        exit(0);
    });
}

- (void)translateTexts:(NSArray *)texts tl:(NSString *)tl completion:(void (^)(NSDictionary *responseTexts))completion {
    NSMutableDictionary *responseTexts = [NSMutableDictionary dictionary];
    dispatch_group_t responseGroup = dispatch_group_create();
    for (int i = 0; i < texts.count; i++) {
        NSDictionary *parameters = @{
            @"appVersion": @"1.0",
            @"textsJson": texts[i],
            @"from": @"auto",
            @"to": tl,
        };
        dispatch_group_enter(responseGroup);
        [[AFHTTPSessionManager manager] POST:URL_TRANSLATE_TEXT parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [responseObject[@"data"] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *originalText = [obj[@"originalText"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                NSString *text = [obj[@"text"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                responseTexts[originalText] = text;
            }];
            dispatch_group_leave(responseGroup);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            dispatch_group_leave(responseGroup);
            NSLog(@"🔴 %@\n%@", LANGUAGES_TO[tl], error);
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
