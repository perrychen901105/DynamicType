//
//  SyntaxHighlightTextStorage.m
//  TextKitNotepad
//
//  Created by Perry on 14-8-6.
//  Copyright (c) 2014年 Colin Eberhardt. All rights reserved.
//

#import "SyntaxHighlightTextStorage.h"

@implementation SyntaxHighlightTextStorage
{
    NSMutableAttributedString *_backingStore;
    NSDictionary *_replacements;
}

/**
 *  You’ve probably noticed that you need to write quite a bit of code in order to subclass text storage. Since NSTextStorage is a public interface of a class cluster (see the note below), you can’t just subclass it and override a few methods to extend its functionality. Instead, there are certain requirements that you must implement yourself, such as the backing store for the attributed string data.
 *
 */

- (id)init
{
    if (self = [super init]) {
        _backingStore = [NSMutableAttributedString new];
        [self createHighlightPatterns];
    }
    return self;
}

- (void)update
{
    // update the highlight patterns
    [self createHighlightPatterns];
    
    // change the 'global' font
    NSDictionary *bodyFont = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody]};
    [self addAttributes:bodyFont range:NSMakeRange(0, self.length)];
    
    // re-apply the regex matches
    [self applyStylesToRange:NSMakeRange(0, self.length)];
}

- (NSString *)string
{
    return [_backingStore string];
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    return [_backingStore attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
    NSLog(@"replaceCharactersInRange:%@ withString:%@", NSStringFromRange(range), str);
    
    [self beginEditing];
    [_backingStore replaceCharactersInRange:range withString:str];
    
    [self edited:NSTextStorageEditedCharacters | NSTextStorageEditedAttributes
           range:range
  changeInLength:str.length - range.length];
    [self endEditing];
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    NSLog(@"setAttributes:%@ range:%@",attrs, NSStringFromRange(range));
    [self beginEditing];
    [_backingStore setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes
           range:range changeInLength:0];
    [self endEditing];
}

- (void)processEditing
{
    [self performReplacementsForRange:[self editedRange]];
    [super processEditing];
}

- (void)performReplacementsForRange:(NSRange)changedRange
{
    NSLog(@"backing store string is %@",[_backingStore string]);
    NSRange extendedRange = NSUnionRange(changedRange, [[_backingStore string] lineRangeForRange:NSMakeRange(changedRange.location, 0)]);
    extendedRange = NSUnionRange(changedRange, [[_backingStore string] lineRangeForRange:NSMakeRange(NSMaxRange(changedRange), 0)]);
    
    [self applyStylesToRange:extendedRange];
}

- (void)applyStylesToRange:(NSRange)searchRange
{
    // 1. create some fonts
    /**
     *  Creates a bold and a normal font for formatting the text using font descriptors help you avoid the use of hardcoded font strings to set font types and styles.
     */
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
    UIFontDescriptor* boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    UIFont *boldFont = [UIFont fontWithDescriptor:boldFontDescriptor size:0.0];
    
    UIFont *normalFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    
    // 2. match items surrounded by asterisks
    /**
     *  Creates a regular expression that locates any text surrounded by asterisks
     */
    NSString *regexStr = @"(\\*\\w+(\\s\\w+)*\\*)\\s";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:nil];
    NSDictionary* boldAttributes = @{NSFontAttributeName: boldFont};
    NSDictionary* normalAttributes = @{NSFontAttributeName: normalFont};
    
    // 3. iterate over each match, making the text bold
    /**
     *  Enumerates the matches returned by the regular expression and applies the bold attribute to each one.
     */
    [regex enumerateMatchesInString:[_backingStore string] options:0
                              range:searchRange
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                             NSRange matchRange = [result rangeAtIndex:1];
                             [self addAttributes:boldAttributes range:matchRange];
                             
                             // 4. reset the style to the original
                             /**
                              * Resets the text style of the character that follows the final asterisk in the matched string to "nomal". This ensures that any tex added after the closing asterisk is not rendered in bold type.
                              */
                             if (NSMaxRange(matchRange)+1 < self.length) {
                                 [self addAttributes:normalAttributes range:NSMakeRange(NSMaxRange(matchRange)+1, 1)];
                             }
                         }];
    
    
    NSDictionary *normalAttrs = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody]};
    
    // iterate over each replacement
    for (NSString *key in _replacements) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:key options:0 error:nil];
        NSDictionary *attributes = _replacements[key];
        [regex enumerateMatchesInString:[_backingStore string]
                                options:0
                                  range:searchRange
                             usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                 // apply the style
                                 NSRange matchRange = [result rangeAtIndex:1];
                                 [self addAttributes:attributes range:matchRange];
                                 
                                 // reset the style to the original
                                 if (NSMaxRange(matchRange)+1 < self.length) {
                                     [self addAttributes:normalAttrs range:NSMakeRange(NSMaxRange(matchRange)+1, 1)];
                                 }
                             }];
    }
    [self highlightHyperlinksInRange:searchRange];
}

- (void)createHighlightPatterns
{
    UIFontDescriptor *scriptFontDescriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:@{UIFontDescriptorFamilyAttribute: @"Zapfino"}];
    
    // 1. base our script font on the preferred body font size
    /**
     *  It first creates a "script" style using Zapfino as the font. Font descriptors help determine the current preferred body font size, which ensures the script font also honors the users' preferred text size setting.
     */
    UIFontDescriptor* bodyFontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
    NSNumber *bodyFontSize = bodyFontDescriptor.fontAttributes[UIFontDescriptorSizeAttribute];
    UIFont *scriptFont = [UIFont fontWithDescriptor:scriptFontDescriptor size:[bodyFontSize floatValue]];
    
    // 2. create the attributes
    /**
     *  Next, it constructs the attributes to apply to each matched style pattern. You'll cover createAttributesForFontStyle:withTrait: in a moment; just park it for now.
     */
    NSDictionary *boldAttributes = [self createAttributesForFontStyle:UIFontTextStyleBody withTrait:UIFontDescriptorTraitBold];
    NSDictionary *italicAttributes = [self createAttributesForFontStyle:UIFontTextStyleBody withTrait:UIFontDescriptorTraitItalic];
    NSDictionary *strikeThroughAttributes = @{NSStrikethroughStyleAttributeName: @1};
    NSDictionary *scriptAttributes = @{NSFontAttributeName: scriptFont};
    NSDictionary *redTextAttributes = @{NSForegroundColorAttributeName: [UIColor redColor]};

    // construct a dictionary of replacements based on regexes
    /**
     *  Finally, it creates a dictionary that maps regular expressions to the attributes declared above.
     */
    _replacements = @{
                      @"(\\*\\w+(\\s\\w+)*\\*)\\s": boldAttributes,
                      @"(_\\w+(\\s\\w+)*_)\\s": italicAttributes,
                      @"([0-9]+\\.)\\s": boldAttributes,
                      @"(-\\w+(\\s\\w+)*-)\\s": strikeThroughAttributes,
                      @"(~\\w+(\\s\\w+)*~)\\s": scriptAttributes,
                      @"\\s([A-Z]{2,})\\s": redTextAttributes};
    
}

- (NSDictionary *)createAttributesForFontStyle:(NSString *)style withTrait:(uint32_t)trait {
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:style];
    UIFontDescriptor *descriptorWithTrait = [fontDescriptor fontDescriptorWithSymbolicTraits:trait];
    UIFont *font = [UIFont fontWithDescriptor:descriptorWithTrait size:0.0];
    return @{NSFontAttributeName: font};
}

- (void)highlightHyperlinksInRange:(NSRange)searchRange {
    
    // I found this on the web ;-)
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"((http|ftp|https):\\/\\/[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&amp;:/~\\+#]*[\\w\\-\\@?^=%&amp;/~\\+#])?)"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    
    [regex enumerateMatchesInString:[_backingStore string]
                            options:0
                              range:searchRange
                         usingBlock:^(NSTextCheckingResult *match,
                                      NSMatchingFlags flags,
                                      BOOL *stop){
                             // create a url using the matched string
                             NSRange matchRange = [match rangeAtIndex:1];
                             NSURL* url = [NSURL URLWithString:[[_backingStore string] substringWithRange:matchRange]];
                             
                             // apply a blue underline style - and add an NSLinkAttributeName attribute
                             NSDictionary* attributes = @{ NSForegroundColorAttributeName : [UIColor blueColor],
                                                           NSUnderlineStyleAttributeName : @1,
                                                           NSLinkAttributeName: url};
                             [self addAttributes:attributes range:matchRange];
                         }];
}


























@end
