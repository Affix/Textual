/* ********************************************************************* 
       _____        _               _    ___ ____   ____
      |_   _|___  _| |_ _   _  __ _| |  |_ _|  _ \ / ___|
       | |/ _ \ \/ / __| | | |/ _` | |   | || |_) | |
       | |  __/>  <| |_| |_| | (_| | |   | ||  _ <| |___
       |_|\___/_/\_\\__|\__,_|\__,_|_|  |___|_| \_\\____|

 Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 Copyright (c) 2010 — 2014 Codeux Software & respective contributors.
     Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Textual IRC Client & Codeux Software nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

#import "TextualApplication.h"

#define KInternetEventClass		1196773964
#define KAEGetURL				1196773964

#ifndef TEXTUAL_BUILT_WITH_HOCKEYAPP_SDK_DISABLED
	#define _hockeyAppRegisteredIdentifier			@"b0b1c84f339487c2e184f7d1ebfe5997"
	#define _hockeyAppRegisteredCompanyName			@"Codeux Software"
#endif

@interface TXMasterController ()
@property (nonatomic, uweak) IBOutlet TXMenuController *internalMenuControllerPointer;
@end

#pragma mark -
#pragma mark Master Controller

@implementation TXMasterController

- (id)init
{
    if ((self = [super init])) {
		/* Remember self. */
		_masterController = self;

		/* Debug mode enables extra logging. */
		if ([NSEvent modifierFlags] & NSControlKeyMask) {
			_debugModeOn = YES;

			LogToConsole(@"Launching in debug mode.");
		}

		/* Ghost mode disables auto connect on launch. */
#if defined(DEBUG)
		_ghostModeOn = YES;
#else
		if ([NSEvent modifierFlags] & NSShiftKeyMask) {
			_ghostModeOn = YES;

			LogToConsole(@"Launching in ghost mode.");
		}
#endif

		/* Return self. */
		return self;
    }

    return nil;
}

#pragma mark -
#pragma mark Waking Up

- (void)awakeFromNib
{
	/* Inform Textual of global pointer. */
	/* The menu controller is created from within our nib
	 so it must be remembered here. */
	_menuController = _internalMenuControllerPointer;

	/* Load defaults. */
	[self registerDefaultPreferences];

	/* Awake main window. */
	[_mainWindow awakeFromMasterControllerStepOne];

	/* Setup theme controller. */
	 _themeController = [TPCThemeController new];
	[_themeController load];
}

- (void)registerDefaultPreferences
{
	/* Load defaults. */
	[TPCPreferences initPreferences];

	/* World controller is the owner of our cloud sync
	 manager so it must be created first. */
	 _worldController = [IRCWorld new];

	/* Load cloud manager. */
	[_worldController setupSyncServices];
}

- (void)loadOtherServices
{
	/* Setup menu controller. */
	[_menuController setupOtherServices];

	/* Setup basic world. */
	[_worldController setupConfiguration];

	/* Initalize view model. */
	[TVCLogControllerHistoricLogSharedInstance() createBaseModel];

	/* Finish loading main window. */
	[_mainWindow awakeFromMasterControllerStepTwo];

	/* Finish loading world controller. */
	[_worldController setupTree];
	[_worldController setupOtherServices];

	/* Register for notifications. */
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerDidWakeUp:) name:NSWorkspaceDidWakeNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerWillPowerOff:) name:NSWorkspaceWillPowerOffNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerScreenDidWake:) name:NSWorkspaceScreensDidWakeNotification object:nil];
	[RZWorkspaceNotificationCenter() addObserver:self selector:@selector(computerScreenWillSleep:) name:NSWorkspaceScreensDidSleepNotification object:nil];

	[RZNotificationCenter() addObserver:self selector:@selector(systemTintChangedNotification:) name:NSControlTintDidChangeNotification object:nil];

	[RZAppleEventManager() setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:KInternetEventClass andEventID:KAEGetURL];

	/* Load extensions. */
	[THOPluginManagerSharedInstance() loadPlugins];

	/* Copy other resources. */
	[TPCResourceManager copyResourcesToCustomAddonsFolder];

	/* Register for HockeyApp. */
#ifndef TEXTUAL_BUILT_WITH_HOCKEYAPP_SDK_DISABLED
	BITHockeyManager *hockeyManager = [BITHockeyManager sharedHockeyManager];

	[hockeyManager configureWithIdentifier:_hockeyAppRegisteredIdentifier
							   companyName:_hockeyAppRegisteredCompanyName
								  delegate:self];

	[hockeyManager startManager];
#endif
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	/* Register app. */
	[self loadOtherServices];

	/* Inform window. */
	[_mainWindow applicationDidFinishLaunching:note];
}

- (void)systemTintChangedNotification:(NSNotification *)notification
{
	[_mainWindow systemTintChangedNotification:notification];
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	return [_menuController dockMenu];
}

- (BOOL)queryTerminate
{
	if (_isTerminating) {
		return YES;
	}
	
	if ([TPCPreferences confirmQuit]) {
		NSInteger result = [TLOPopupPrompts dialogWindowWithQuestion:ULS(@"BasicLanguage[1000][1]")
															   title:ULS(@"BasicLanguage[1000][2]")
													   defaultButton:ULS(@"BasicLanguage[1000][3]")
													 alternateButton:BLS(1009)
													  suppressionKey:nil
													 suppressionText:nil];
		
		return result;
	}
	
	return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if ([self queryTerminate]) {
		_isTerminating = YES;

		return NSTerminateNow;
	} else {
		return NSTerminateCancel;
	}
}

- (BOOL)isNotSafeToPerformApplicationTermination
{
	BOOL isTerminatingClients = (_terminatingClientCount > 0);

	BOOL isPerformingHistorySave = [TVCLogControllerHistoricLogSharedInstance() isPerformingSave];
	BOOL isPerformingCloudSync = NO;

#ifdef TEXTUAL_BUILT_WITH_ICLOUD_SUPPORT
	TPCPreferencesCloudSync *_cloudSyncManager = [_worldController cloudSyncManager];

	if (_cloudSyncManager) {
		isPerformingCloudSync = ([_cloudSyncManager isSyncingLocalKeysDownstream] ||
								 [_cloudSyncManager isSyncingLocalKeysUpstream]);
	}
#endif

	return (isTerminatingClients ||	isPerformingCloudSync || isPerformingHistorySave);
}

- (void)applicationWillTerminate:(NSNotification *)note
{
	/* Hide Textual to perform work in background. */
	[RZRunningApplication() hide];

	/* No longer handle notifications. */
	[RZWorkspaceNotificationCenter() removeObserver:self];

	[RZNotificationCenter() removeObserver:self];

	[RZAppleEventManager() removeEventHandlerForEventClass:KInternetEventClass andEventID:KAEGetURL];

	/* Unload plugins. */
	[THOPluginManagerSharedInstance() unloadPlugins];

	/* Save some reference information. */
	[TPCPreferences saveTimeIntervalSinceApplicationInstall];

	/* Save or destroy history based on preferences. */
	if ([TPCPreferences reloadScrollbackOnLaunch] == NO) {
		[TVCLogControllerHistoricLogSharedInstance() resetData]; // Delete database.
	} else {
		[TVCLogControllerHistoricLogSharedInstance() saveData:YES]; // Save database.
	}

#ifdef TEXTUAL_BUILT_WITH_ICLOUD_SUPPORT
	/* Close the cloud session when appropriate. */
	TPCPreferencesCloudSync *_cloudSyncManager = [_worldController cloudSyncManager];

	if ([TPCPreferences featureAvailableToOSXMountainLion] == NO) {
		_cloudSyncManager = nil;
	}

	if ( _cloudSyncManager) {
		[_cloudSyncManager setApplicationIsTerminating:YES];
	}
#endif

	/* Inform controllers to clean up. */
	[_menuController prepareForApplicationTermination];

	[_mainWindow prepareForApplicationTermination];

	/* Save the world. */
	[_worldController save];

	/* Start quitting clients. */
	_terminatingClientCount = [_worldController clientCount];

	[_worldController prepareForApplicationTermination];

	/* Run loop until every client has quit. */
	while ([self isNotSafeToPerformApplicationTermination])
	{
		[RZMainRunLoop() runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}

#ifdef TEXTUAL_BUILT_WITH_ICLOUD_SUPPORT
	/* Finish cleaning up of iCloud. */
	if ( _cloudSyncManager) {
		[_cloudSyncManager closeCloudSyncSession];
	}
#endif
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	[_mainWindow makeKeyAndOrderFront:nil];

	return YES;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	[_mainWindow makeKeyAndOrderFront:nil];

	return YES;
}

#pragma mark -
#pragma mark NSWorkspace Notifications

- (void)handleURLEvent:(NSAppleEventDescriptor *)event
		withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSWindowNegateActionWithAttachedSheet();

	NSAppleEventDescriptor *desc = [event descriptorAtIndex:1];

	[IRCExtras parseIRCProtocolURI:[desc stringValue] withDescriptor:event];
}

- (void)computerScreenWillSleep:(NSNotification *)note
{
	[_worldController prepareForScreenSleep];
}

- (void)computerScreenDidWake:(NSNotification *)note
{
	[_worldController awakeFomScreenSleep];
}

- (void)computerWillSleep:(NSNotification *)note
{
	[_worldController prepareForSleep];
}

- (void)computerDidWakeUp:(NSNotification *)note
{
	[_worldController autoConnectAfterWakeup:YES];
}

- (void)computerWillPowerOff:(NSNotification *)note
{
	_isTerminating = YES;
	
	[NSApp terminate:nil];
}

@end
