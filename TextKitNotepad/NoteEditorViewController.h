//
//  CENoteEditorControllerViewController.h
//  TextKitNotepad
//
//  Created by Colin Eberhardt on 19/06/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Note;

@interface NoteEditorViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIBarButtonItem *editButton;
@property Note* note;
- (IBAction)editAction:(id)sender;

@end
