//
//  CENoteEditorControllerViewController.m
//  TextKitNotepad
//
//  Created by Colin Eberhardt on 19/06/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "NoteEditorViewController.h"
#import "SyntaxHighlightTextStorage.h"
#import "TimeIndicatorView.h"
#import "Note.h"

@interface NoteEditorViewController () <UITextViewDelegate>

@end

@implementation NoteEditorViewController
{
    TimeIndicatorView *_timeView;
    SyntaxHighlightTextStorage* _textStorage;
    UITextView *_textView;
    CGRect _textViewFrame;
}

- (void)createTextView
{
    // 1. Create the text storage that backs the editor
    /**
     *  An instance of your custom text storage is instantiated and initialized with an attributed string holding the content of the note.
     */
    NSDictionary *attrs = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody]};
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:_note.contents attributes:attrs];
    _textStorage = [SyntaxHighlightTextStorage new];
    [_textStorage appendAttributedString:attrString];
    
    CGRect newTextViewRect = self.view.bounds;
    
    // 2. Create the layout manager
    /**
     *  A layout manager is created.
     */
    NSLayoutManager *layouotManager = [[NSLayoutManager alloc] init];
    
    // 3. Create a text container
    /**
     *  A text container is created and associated with the layout manager. The layout manager is then associated with the text storage.
     */
    CGSize containerSize = CGSizeMake(newTextViewRect.size.width, CGFLOAT_MAX);
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:containerSize];
    container.widthTracksTextView = YES;
    [layouotManager addTextContainer:container];
    [_textStorage addLayoutManager:layouotManager];
    
    // 4. Create a UITextView
    /**
     *  Finally the actual text view is created with your custom text container, the delegate set and the text view added as a subview.
     */
    _textView = [[UITextView alloc] initWithFrame:newTextViewRect textContainer:container];
    _textView.delegate = self;
    [self.view addSubview:_textView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self createTextView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferredContentSizeChanged:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    _timeView = [[TimeIndicatorView alloc] init:_note.timestamp];
    [self.view addSubview:_timeView];
    
    _textViewFrame = self.view.bounds;
}

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
    _textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [_textStorage update];
    [self updateTimeIndicatorFrame];
}

- (void)viewDidLayoutSubviews
{
    [self updateTimeIndicatorFrame];
    _textView.frame = _textViewFrame;
}

- (void)updateTimeIndicatorFrame {
    [_timeView updateSize];
    _timeView.frame = CGRectOffset(_timeView.frame, self.view.frame.size.width - _timeView.frame.size.width, 0.0);
    UIBezierPath *exclusionPath = [_timeView curvePathWithOrigin:_timeView.center];
    _textView.textContainer.exclusionPaths = @[exclusionPath];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    // copy the updated note text to the underlying model.
    _note.contents = textView.text;
    
    _textViewFrame = self.view.bounds;
    _textView.frame = _textViewFrame;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    _textViewFrame = self.view.bounds;
    _textViewFrame.size.height -= 216.0f;
    _textView.frame = _textViewFrame;
}



@end
