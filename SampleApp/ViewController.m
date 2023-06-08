//
//  ViewController.m
//  MarkdownAttributedString
//
//  Created by Craig Hockenberry on 12/28/19.
//  Copyright © 2019 The Iconfactory. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <NSTextViewDelegate>

@property (nonatomic, weak) IBOutlet NSTextField *richTextTextField;
@property (nonatomic, weak) IBOutlet NSButton *richTextButton;
@property (nonatomic, weak) IBOutlet NSTextView *richTextTextView;

@property (nonatomic, weak) IBOutlet NSTextField *markdownTextField;
@property (nonatomic, weak) IBOutlet NSTextView *markdownTextView;

@property (nonatomic, weak) IBOutlet NSTextView *colorTextView;
@property (nonatomic, weak) IBOutlet NSTextView *linkTextView;

@property (nonatomic, strong) NSMutableSet<NSString *> *convertColors;
@property (nonatomic, strong) NSMutableDictionary *linkDict;

@end

@implementation ViewController

#pragma mark - Actions
- (IBAction)setRichTextExamples:(id)sender
{
    [self addLinkMap];
    [self addConvertColor];
    self.markdownTextView.string = [self markdownColorString:self.richTextTextView.attributedString];
}

// 粗体、颜色、网址
- (NSString *)markdownColorString:(NSAttributedString *)attributeString {
    NSMutableString *result = [NSMutableString string];
    
    // 按行重新组合
    NSArray<NSString *> *lines = [attributeString.string componentsSeparatedByString:@"\n"];
    NSInteger index = 0;
    for (NSString *line in lines) {
        NSAttributedString *subAttributeStr = [attributeString attributedSubstringFromRange:NSMakeRange(index, line.length)];
        index += line.length + 1;
        [result appendString:[self getMarkdownString:subAttributeStr]];
        [result appendString:@"\n"];
    }
    
    return result.copy;
}

#pragma mark - Private Method
- (void)addLinkMap {
    self.linkDict = [NSMutableDictionary dictionary];
    NSArray *array = [self.linkTextView.string componentsSeparatedByString:@"\n"];
    for (NSString *line in array) {
        NSArray *array = [line componentsSeparatedByString:@" "];
        if (array.count > 1) {
            self.linkDict[array[0]] = array[1];
        }
    }
}

- (void)addConvertColor {
    self.convertColors = [NSMutableSet set];
    NSInteger index = 0;
    while (index < self.colorTextView.attributedString.length) {
        NSRange range;
        NSDictionary *attr = [self.colorTextView.attributedString attributesAtIndex:index effectiveRange:&range];
        NSColor *color = attr[NSStrokeColorAttributeName];
        if (color) {
            [self.convertColors addObject:[self hexStringFromColor:color]];
        }
        index += range.length;
    }
}

- (BOOL)isBoldFont:(NSDictionary *)attr {
    if (!attr) {
        return NO;
    }
    NSFont *font = attr[NSFontAttributeName];
    if (!font) {
        return NO;
    }
    return (font.fontDescriptor.symbolicTraits & NSFontDescriptorTraitBold);
}

- (NSColor *)hasColor:(NSDictionary *)attr {
    if (!attr) {
        return nil;
    }
    NSColor *color = attr[NSStrokeColorAttributeName];
    NSString *colorHex = [self hexStringFromColor:color];
    if (![self.convertColors containsObject:colorHex]) {
        return nil;
    }
    return color;
}

- (BOOL)isSameAttribute:(NSDictionary *)attr1 other:(NSDictionary *)attr2 {
    if (!attr1 || !attr2) {
        return NO;
    }
    
    if ([self isLink:attr1] || [self isLink:attr2]) {
        return NO;
    }
    if ([self isBoldFont:attr1] ^ [self isBoldFont:attr2]) {
        return NO;
    }
    
    NSColor *color1 = [self hasColor:attr1], *color2 = [self hasColor:attr2];
    if (!CGColorEqualToColor(color1.CGColor, color2.CGColor)) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isLink:(NSDictionary *)attr {
    id linkAttr = attr[NSLinkAttributeName];
    return !!linkAttr;
}

- (NSString *)getMarkdownString:(NSAttributedString *)oldAttributeStr {
    NSMutableString *result = [NSMutableString string];
    NSInteger index = 0;
    NSDictionary *preAttr = nil;
    NSString *preSubStr = nil;
    
    while (index < oldAttributeStr.length) {
        NSRange range;
        NSDictionary *attr = [oldAttributeStr attributesAtIndex:index effectiveRange:&range];
        NSString *subStr = [oldAttributeStr.string substringWithRange:range];
        index += range.length;
        if (!preAttr) {// 第一次
            if ([self isBoldFont:attr]) {
                [result appendString:@"**"];
            }
            BOOL shouldAppend = YES;
            if ([self isLink:attr]) {
                if (self.linkDict[subStr]) {
                    [result appendFormat:@"[%@](", self.linkDict[subStr]];
                } else {
                    [result appendString:@"<"];
                }
                [result appendString:[attr[NSLinkAttributeName] absoluteString]];
                shouldAppend = NO;
            } else if ([self hasColor:attr]) {
                NSString *hexColor = [self hexStringFromColor:[self hasColor:attr]];
                [result appendString:[NSString stringWithFormat:@"<font color=%@>", hexColor]];
            }
            if (shouldAppend) {
                [result appendString:[self convertStr:subStr]];
            }
        } else {// 不是第一次
            if ([self isSameAttribute:preAttr other:attr]) {
                [result appendString:[self convertStr:subStr]];
            } else {
                // 结束之前的
                if ([self isLink:preAttr]) {
                    if (self.linkDict[preSubStr]) {
                        [result appendString:@")"];
                    } else {
                        [result appendString:@">"];
                    }
                } else if ([self hasColor:preAttr]) {
                    [result appendString:@"</font>"];
                }
                
                if ([self isBoldFont:preAttr]) {
                    [self removeStringRightSpace:result];
                    [result appendString:@"** "];
                }
                
                //开始新的
                if ([self isBoldFont:attr]) {
                    [result appendString:@" **"];
                }
                
                BOOL shouldAppend = YES;
                if ([self isLink:attr]) {
                    if (self.linkDict[subStr]) {
                        [result appendFormat:@"[%@](", self.linkDict[subStr]];
                    } else {
                        [result appendString:@"<"];
                    }
                    shouldAppend = NO;
                    [result appendString:[attr[NSLinkAttributeName] absoluteString]];
                } else if ([self hasColor:attr]) {
                    NSString *hexColor = [self hexStringFromColor:[self hasColor:attr]];
                    [result appendString:[NSString stringWithFormat:@"<font color=%@>", hexColor]];
                }
                if (shouldAppend) {
                    [result appendString:[self convertStr:subStr]];
                }
            }
        }
        preSubStr = subStr;
        preAttr = attr;
    }
    // 结束之前的
    if ([self isLink:preAttr]) {
        if (self.linkDict[preSubStr]) {
            [result appendString:@")"];
        } else {
            [result appendString:@">"];
        }
    } else if ([self hasColor:preAttr]) {
        [result appendString:@"</font>"];
    }
    if ([self isBoldFont:preAttr]) {
        [result appendString:@"**"];
    }
    return result.copy;
}

- (NSString *)convertStr:(NSString *)str {
    str = [self removeStringLeftSpace:str];
    NSMutableString *mStr = str.mutableCopy;
    NSRange range = NSMakeRange(0, str.length);
    [mStr replaceOccurrencesOfString:@"•" withString:@"●" options:NSLiteralSearch range:range];
    [mStr replaceOccurrencesOfString:@"◦" withString:@"○" options:NSLiteralSearch range:range];
    [mStr replaceOccurrencesOfString:@"▪" withString:@"■" options:NSLiteralSearch range:range];
    return mStr.copy;
}

- (void)removeStringRightSpace:(NSMutableString *)str {
    NSCharacterSet *spaceSet = [NSCharacterSet whitespaceCharacterSet];
    unichar lastChar = [str characterAtIndex:str.length - 1];
    if ([spaceSet characterIsMember:lastChar]) {
        [str deleteCharactersInRange:NSMakeRange(str.length - 1, 1)];
    }
}

- (NSString *)removeStringLeftSpace:(NSString *)str {
    NSCharacterSet *spaceSet = [NSCharacterSet whitespaceCharacterSet];
    const char *ptr = str.UTF8String;
    NSInteger len = 0;
    while (*ptr != '\0') {
        if ([spaceSet characterIsMember:(*ptr)]) {
            len++;
            ptr++;
            continue;
        }
        break;
    }
    if (len > 0) {
        return [str substringFromIndex:len];
    }
    return str;
}

- (NSString *)hexStringFromColor:(NSColor *)color {
    if (!color) {
        return @"";
    }
    CGFloat r = 0.0;
    CGFloat g = 0.0;
    CGFloat b = 0.0;
    CGFloat a = 0.0;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(r*0xff), (int)(g*0xff), (int)(b*0xff)];
}

@end
