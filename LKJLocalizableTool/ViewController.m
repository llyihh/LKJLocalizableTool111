//
//  ViewController.m
//  LKJLocalizableTool
//
//  Created by LYH on 2021/12/15.
//

#import "ViewController.h"
#import "AFNetworking/AFNetworking.h"

#define SRC_PATH @"/Users/lyh/MyRepositories/LKJLocalizableTool/Localizable.strings"
#define DST_PATH(tl) [NSString stringWithFormat:@"%@/tmp/%@/%@", SRC_PATH.stringByDeletingLastPathComponent, tl, SRC_PATH.lastPathComponent]

#define TO_LANGUAGES @{ \
    /*@"en": @"英语",*/ \
    @"zh-CN": @"中文（简体）", \
    @"zh-TW": @"中文（繁体）", \
    @"ja": @"日语", \
    @"ru": @"俄语", \
    @"de": @"德语", \
    @"fr": @"法语", \
    @"es": @"西班牙语", \
    @"pt": @"葡萄牙语", \
    @"ko": @"韩语", \
    @"vi": @"越南语", \
    @"th": @"泰语", \
    @"ar": @"阿拉伯语", \
}

#define TRANSLATE_TEXT_URL @"http://47.88.31.120:80/translate/text"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    NSString *srcContent = [NSString stringWithContentsOfFile:SRC_PATH encoding:NSUTF8StringEncoding error:nil];
    NSArray *srcComponents = [[srcContent componentsSeparatedByString:@"\n"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH '\"' && SELF CONTAINS ' = ' && SELF ENDSWITH '\";'"]];
    NSMutableArray *srcValues = [NSMutableArray array];
    for (int i = 0; i < srcComponents.count; i++) {
        NSString *value = [srcComponents[i] componentsSeparatedByString:@" = "].lastObject;
        value = [value substringWithRange:NSMakeRange(1, value.length - 3)];
        [srcValues addObject:value];
    }
    
    NSMutableArray *texts = [NSMutableArray array];
    NSInteger len = 128;
    for (int i = 0; i < ceil(1.f * srcValues.count / len); i++) {
        NSArray *obj = [srcValues subarrayWithRange:NSMakeRange(len * i, MIN(srcValues.count, len * (i + 1)) - len * i)];
        NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [texts addObject:text];
    }
    
    dispatch_group_t translateGroup = dispatch_group_create();
    for (NSString *tl in TO_LANGUAGES.allKeys) {
        dispatch_group_enter(translateGroup);
        [self translateTexts:texts tl:tl completion:^(NSDictionary *responseTexts) {
            NSString *dstPath = DST_PATH(([NSString stringWithFormat:@"%@ # %@", tl, TO_LANGUAGES[tl]]));
            if (![NSFileManager.defaultManager fileExistsAtPath:dstPath.stringByDeletingLastPathComponent]) {
                [NSFileManager.defaultManager createDirectoryAtPath:dstPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
            }
            if ([NSFileManager.defaultManager fileExistsAtPath:dstPath]) {
                [NSFileManager.defaultManager removeItemAtPath:dstPath error:nil];
            }
            NSMutableString *dstContent = [srcContent mutableCopy];
            [responseTexts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [dstContent replaceOccurrencesOfString:key withString:obj options:0 range:NSMakeRange(0, dstContent.length)];
            }];
            [dstContent writeToFile:dstPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            NSLog(@"%@ 🎉🎉!! src: %ld, dst: %ld", dstPath.stringByDeletingLastPathComponent.lastPathComponent, srcValues.count, responseTexts.count);
            dispatch_group_leave(translateGroup);
        }];
    }
    dispatch_group_notify(translateGroup, dispatch_get_main_queue(), ^{
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
        [[AFHTTPSessionManager manager] POST:TRANSLATE_TEXT_URL parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            for (NSDictionary *obj in responseObject[@"data"]) {
                NSString *originalText = [NSString stringWithFormat:@"\"%@\";", obj[@"originalText"]];
                NSString *text = [NSString stringWithFormat:@"\"%@\";", obj[@"text"]];
                responseTexts[originalText] = text;
            }
            dispatch_group_leave(responseGroup);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"tl: %@, error: %@", tl, error);
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
