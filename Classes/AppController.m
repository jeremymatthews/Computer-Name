//
//  AppController.m
//  Computer Name
//
//  Created by Jeremy Matthews on 8/5/10.
//  Copyright (c) 2014 SISU Works LLC. All rights reserved.
//

#import "AppController.h"

@interface AppController ()

//computer names
@property (nonatomic, readwrite) NSString *computerName;
@property (nonatomic, readwrite) NSString *localHostName;

//fancy fadeout
@property (nonatomic, readwrite) NSTimer *timer;

//UI elements
@property (weak) IBOutlet NSWindow *mainWindow;
@property (weak) IBOutlet NSButton *renameComputerButton;
@property (weak) IBOutlet NSTextField *nameField;

-(IBAction)renameAction:(id)sender;

@end

@implementation AppController

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(applicationWillTerminate:)
                   name:NSApplicationWillTerminateNotification
                 object:NSApp];
        
        [_mainWindow setDelegate:self];
    }
    
    return self;
}

-(NSCharacterSet *)adApprovedCharacterSet
{
    NSCharacterSet *okCharacterSet =
    [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDFEGHIJKLMNOPQRTSUVWXYZ1234567890-"];
    
    return okCharacterSet;
}

-(NSString *)filteredString:(NSString *)preliminaryName
{
    // Start with string to filter and an empty mutable string to build into
    NSString *newString = [[preliminaryName componentsSeparatedByCharactersInSet:[[self adApprovedCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    // set computername into textfield
    if ([newString length] > 15)
    {
        //NSLog(@"name is too long...ranging to 15 chars max");
        NSRange range = NSMakeRange (0, 15);
        NSString *adjustedLengthCompName = [newString substringWithRange:range];
        NSLog(@"revised name is %@", adjustedLengthCompName);
    }
    
    return newString;
}

-(void)awakeFromNib
{
    // Returns NULL/nil if no computer name set, or error occurred. OSX 10.1+
    _computerName = (NSString *)CFBridgingRelease(SCDynamicStoreCopyComputerName(NULL, NULL));
    //NSLog(@"comp name is %@", _computerName);
    
    // Returns NULL/nil if no local hostname set, or error occurred. OSX 10.2+
    _localHostName = (NSString *)CFBridgingRelease(SCDynamicStoreCopyLocalHostName(NULL));
    //NSLog(@"localhostname is %@", _localHostName);
    
    NSString *namefieldString = [self filteredString:_computerName];
    [_nameField setStringValue:namefieldString];
}

- (BOOL)windowShouldClose:(id)sender
{
    // Set up our timer to periodically call the fade: method.
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES];
    
    // Don't close just yet.
    return NO;
}

- (void)fade:(NSTimer *)theTimer
{
    if ([_mainWindow alphaValue] > 0.0) {
        // If window is still partially opaque, reduce its opacity.
        [_mainWindow setAlphaValue:[_mainWindow alphaValue] - 0.2];
    } else {
        // Otherwise, if window is completely transparent, destroy the timer and close the window.
        [_timer invalidate];
        _timer = nil;
        [_mainWindow close];
        // Make the window fully opaque again for next time.
        [_mainWindow setAlphaValue:1.0];
    }
}

-(IBAction)renameAction:(id)sender
{
    NSString *adjustedCompName = [_nameField stringValue];
    
    //step 1 - rename the machine - we really don't care if its 10.4, 10.5, or 10.6/10.7....this works regardless
    SCPreferencesRef prefs;
    CFStringRef appName = CFSTR("Computer Name");
    
    AuthorizationRef auth = nil;
    OSStatus authErr = noErr;
    
    AuthorizationFlags rootFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    
    authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, rootFlags, &auth);
    prefs = SCPreferencesCreateWithAuthorization(kCFAllocatorDefault, appName, NULL, auth);
    
    // don't bother waiting for a hard lock
    SCPreferencesLock(prefs, NO);
    
    CFStringRef cfString = (__bridge CFStringRef)adjustedCompName;
    //set the session commands
    // localhost name
    SCPreferencesSetLocalHostName(prefs, cfString);
    // computer name
    SCPreferencesSetComputerName(prefs, cfString, kCFStringEncodingUTF8);
    // commmit the session changes
    SCPreferencesCommitChanges(prefs);
    // release the lock
    SCPreferencesUnlock(prefs);
    // apply the actual session vars
    SCPreferencesApplyChanges(prefs);
    // sync the prefs
    SCPreferencesSynchronize(prefs);
    // release the prefs
    CFRelease(prefs);
    // nullify the auth to prevent security issues
    auth = nil;
}

-(void)controlTextDidChange:(NSNotification *)obj
{
    //NSLog(@"text changed");
    // the object that posted the notification
    //NSLog(@"object is %ld", [postingObject tag]);
    
    NSArray *tmp = @[@0];
    NSControl *postingObject = [obj object];
    //NSLog(@"object is %ld", [postingObject tag]);
    
    NSMutableAttributedString *tmpNameMutable = [[_nameField attributedStringValue] mutableCopy];
    if ([tmp containsObject:[NSNumber numberWithInt:[postingObject tag]]])
    {
        //if it is the name field...
        if ([postingObject tag] == 0) {
            [_nameField setAllowsEditingTextAttributes:YES];
            
            int badcount = 0;
            int count = 0;
            
            // Iterate over characters in the string, checking each
            for (int i = 0; i < [[_nameField stringValue] length]; i++)
            {
                if (i < 15)
                {
                    unichar currentChar = [[_nameField stringValue] characterAtIndex:i];
                    if([[self adApprovedCharacterSet] characterIsMember:currentChar])
                    {
                        
                    }
                    else
                    {
                        [tmpNameMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(i,1)];
                        [tmpNameMutable addAttribute:NSToolTipAttributeName value:@"Invalid Character" range:NSMakeRange(i,1)];
                        [_nameField setAttributedStringValue:tmpNameMutable];
                        badcount = badcount +1;
                        //NSLog(@"bad chars");
                    }
                    
                    if ((badcount > 0) || ([[[_nameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] < 1)
                        || ([[_nameField stringValue] isEqualToString:@""]))
                    {
                        [_renameComputerButton setEnabled:NO];
                    } else
                    {
                        [_renameComputerButton setEnabled:YES];
                    }
                }
                else
                {
                    //
                    @try
                    {
                        [tmpNameMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(i,1)];
                        [_nameField setAttributedStringValue:tmpNameMutable];
                        [_renameComputerButton setEnabled:NO];
                    }
                    @catch (NSException *exception)
                    {
                        NSLog(@"exception is %@", exception);
                    }
                    @finally
                    {
                        NSLog(@"longer than 15");
                    }
                }
                
            }
            count = count +1;
        }
    }
}

- (void)windowWillClose:(NSNotification *)notification 
{
    [_mainWindow setDelegate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification 
{
    //NSLog(@"terminated");
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
