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

#define _delayedDrawLimit		1.0

@interface TVCServerListCell ()
@property (nonatomic, assign) BOOL isAwaitingRedraw;
@property (nonatomic, assign) CFAbsoluteTime lastDrawTime;
@property (nonatomic, strong) NSString *cachedStatusBadgeFile;
@property (nonatomic, strong) TVCServerListCellBadge *badgeRenderer;
@end

#pragma mark -
#pragma mark Private Headers

@implementation TVCServerListCell

#pragma mark -
#pragma mark Cell Information

- (NSDictionary *)drawingContext
{
	/* This information is used by every drawing method defined below. */
	NSInteger rowIndex = [self rowIndex];

	return @{
		@"rowIndex"		: @(rowIndex),
		@"isSelected"	: @([_serverList isRowSelected:rowIndex]),
		@"isInverted"	: @([TPCPreferences invertSidebarColors]),
		@"isRetina"		: @([TPCPreferences runningInHighResolutionMode]),
		@"isKeyWindow"	: @([[_masterController mainWindow] isActive]),
		@"isGraphite"	: @([NSColor currentControlTint] == NSGraphiteControlTint)
	};
}

- (NSInteger)rowIndex
{
	return [_serverList rowForItem:_cellItem];
}

- (BOOL)isReadyForDraw
{
	/* We only allow draws to occur every 1.0 second at minimum so that our badge
	 does not have to be stressed during possible flood events. */
	if (_lastDrawTime == 0) {
		return YES;
	}

	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

	if ((now - _lastDrawTime) >= _delayedDrawLimit) {
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Cell Drawing

- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
	return NSZeroRect;
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	return nil;
}

- (void)updateGroupDisclosureTriangle /* DO NOT CALL DIRECTLY FROM THIS CLASS. */
{
	NSButton *theButtonParent;

	NSView *superView = [self superview];

	for (id view in [superView subviews]) {
		if ([view isKindOfClass:[NSButton class]]) {
			theButtonParent = view;
		}
	}

	PointerIsEmptyAssert(theButtonParent);

	[self updateGroupDisclosureTriangle:theButtonParent];
}

- (void)updateGroupDisclosureTriangle:(NSButton *)theButtonParent
{
	NSButtonCell *theButton = [theButtonParent cell];
	
	/* Button, yay! */
	NSInteger rowIndex = [self rowIndex];

	BOOL isSelected = [_serverList isRowSelected:rowIndex];

	/* We keep a reference to the default button. */
	if ([_serverList defaultDisclosureTriangle] == nil) {
		[_serverList setDefaultDisclosureTriangle:[theButton image]];
	}

	if ([_serverList alternateDisclosureTriangle] == nil) {
		[_serverList setAlternateDisclosureTriangle:[theButton alternateImage]];
	}

	/* Now the fun can begin. */
	NSImage *primary = [_serverList disclosureTriangleInContext:YES selected:isSelected];
	NSImage *alterna = [_serverList disclosureTriangleInContext:NO selected:isSelected];

	[theButton setImage:primary];
	[theButton setAlternateImage:alterna];

	if (isSelected) {
		[theButton setBackgroundStyle:NSBackgroundStyleLowered];
	} else {
		[theButton setBackgroundStyle:NSBackgroundStyleRaised];
	}

	/* In our layered back scroll view this forces the disclosure triangle to be redrawn. */
	[theButtonParent setHidden:YES];
	[theButtonParent setHidden:NO];
}

- (void)updateSelectionBackgroundView
{
	/****************************************************************/
	/* Define context variables. */
	/****************************************************************/

	NSDictionary *drawContext = [self drawingContext];

	BOOL invertedColors = [drawContext boolForKey:@"isInverted"];
	BOOL isKeyWindow = [drawContext boolForKey:@"isKeyWindow"];
	BOOL isGraphite = [drawContext boolForKey:@"isGraphite"];
	BOOL isSelected = [drawContext boolForKey:@"isSelected"];

	if (isSelected == NO) {
		[_backgroundImageCell setHidden:YES];

		return; // No reason to continue.
	}

	IRCChannel *channel = [_cellItem channel];

	/****************************************************************/
	/* Find the name of the image to be drawn. */
	/****************************************************************/

	NSString *backgroundImage;

	if (channel) {
		backgroundImage = @"ChannelCellSelection";
	} else {
		backgroundImage = @"ServerCellSelection";
	}

	if (invertedColors == NO) {
		if (isKeyWindow) {
			backgroundImage = [backgroundImage stringByAppendingString:@"_Focused"];
		} else {
			backgroundImage = [backgroundImage stringByAppendingString:@"_Unfocused"];
		}

		if (isGraphite) {
			backgroundImage = [backgroundImage stringByAppendingString:@"_Graphite"];
		} else {
			backgroundImage = [backgroundImage stringByAppendingString:@"_Aqua"];
		}
	}

	if (invertedColors) {
		backgroundImage = [backgroundImage stringByAppendingString:@"_Inverted"];
	}

	NSImage *origBackgroundImage = [NSImage imageNamed:backgroundImage];

	/****************************************************************/
	/* Put the background to screen. */
	/****************************************************************/

	/* When our image view is visible for the selected item, right clicking on
	 it will not do anything unless we define a menu to use with our view. Below,
	 we define the menu that matches the selection. */
	NSMenuItem *menuitem;

	if (channel) {
		menuitem = [_menuController channelMenuItem];
	} else {
		menuitem = [_menuController serverMenuItem];
	}

	/* Setting the menu on our imageView, not only backgroundImageCell, makes it
	 so right clicking on the channel status produces the same menu that is given
	 clicking anywhere else in the server list. */
	[self setImageViewMenu:[menuitem submenu]];

	/* Populate the background image cell. */
	[_backgroundImageCell setImage:origBackgroundImage];

	[_backgroundImageCell setHidden:NO];
}

- (void)setImageViewMenu:(NSMenu *)newMenu
{
	/* Set image view. */
	[[self imageView] setMenu:newMenu];

	/* Set background view. */
	[_backgroundImageCell setMenu:newMenu];
}

- (void)performTimedDrawInFrame:(id)frameString
{
	[self updateDrawing:NSRectFromString(frameString) skipDrawingCheck:YES];

	_isAwaitingRedraw = NO;
}

- (void)updateDrawing:(NSRect)cellFrame
{
	[self updateDrawing:cellFrame skipDrawingCheck:NO];
}

- (void)updateDrawing:(NSRect)cellFrame skipDrawingCheck:(BOOL)doNotLimit
{
	[self updateSelectionBackgroundView]; // Selection always takes precedence.
	
	if (doNotLimit == NO) {
		BOOL drawReady = [self isReadyForDraw];

		if (drawReady == NO) {
			if (_isAwaitingRedraw == NO) {
				_isAwaitingRedraw = YES;

				[self performSelector:@selector(performTimedDrawInFrame:)
						   withObject:NSStringFromRect(cellFrame)
						   afterDelay:_delayedDrawLimit];
			}

			return; // Do not continue.
		}
	}

	PointerIsEmptyAssert(_cellItem);

	BOOL isGroupItem = [_serverList isGroupItem:_cellItem];

	if (isGroupItem) {
		[self updateDrawingForGroupItem:cellFrame];
	} else {
		[self updateDrawingForChildItem:cellFrame];
	}

	_lastDrawTime = CFAbsoluteTimeGetCurrent();
}

#pragma mark -
#pragma mark Group Item Drawing

- (void)updateDrawingForGroupItem:(NSRect)cellFrame
{
	/**************************************************************/
	/* Define our context variables. */
	/**************************************************************/

	NSDictionary *drawContext = [self drawingContext];

	BOOL invertedColors = [drawContext boolForKey:@"isInverted"];
	BOOL isKeyWindow = [drawContext boolForKey:@"isKeyWindow"];
	BOOL isSelected = [drawContext boolForKey:@"isSelected"];

	IRCClient *client = [_cellItem client];

	/**************************************************************/
	/* Create our new string from scratch. */
	/**************************************************************/

	/* The new string inherits the attributes of the text field so that stuff that we do not
	 define like the paragraph style is passed along and not lost when we define a new value. */
	NSString *cellLabel = [_cellItem label];

	NSAttributedString *currentStrValue = [_customTextField attributedStringValue];

	NSRange stringLenghtRange = NSMakeRange(0, [currentStrValue length]);

	NSMutableAttributedString *newStrValue = [currentStrValue mutableCopy];

	/* Has the label changed? */
	if ([cellLabel isEqualToString:[currentStrValue string]] == NO) {
		[newStrValue replaceCharactersInRange:stringLenghtRange withString:[_cellItem label]];

		stringLenghtRange = NSMakeRange(0, [currentStrValue length]);
	}
	
	/* Text font and color. */
	NSColor *controlColor;

	if ([client isConnected] == NO) {
		controlColor = [_serverList serverCellDisabledTextColor];
	} else {
		controlColor = [_serverList serverCellNormalTextColor];
	}

	/* Prepare text shadow. */
	NSShadow *itemShadow = [NSShadow new];

	[itemShadow setShadowOffset:NSMakeSize(0, -1)];

	if (invertedColors) {
		[itemShadow setShadowBlurRadius:1.0];
	}

	if (isSelected) {
		if (isKeyWindow) {
			controlColor = [_serverList serverCellSelectedTextColorForActiveWindow];
		} else {
			controlColor = [_serverList serverCellSelectedTextColorForInactiveWindow];
		}

		if (isKeyWindow) {
			[itemShadow setShadowColor:[_serverList serverCellSelectedTextShadowColorForActiveWindow]];
		} else {
			[itemShadow setShadowColor:[_serverList serverCellSelectedTextShadowColorForInactiveWindow]];
		}
	} else {
		if (isKeyWindow) {
			[itemShadow setShadowColor:[_serverList serverCellNormalTextShadowColorForActiveWindow]];
		} else {
			[itemShadow setShadowColor:[_serverList serverCellNormalTextShadowColorForInactiveWindow]];
		}
	}

	/**************************************************************/
	/* Set attributes on the new string. */
	/**************************************************************/

	[newStrValue addAttribute:NSShadowAttributeName
						 value:itemShadow
						range:stringLenghtRange];

	[newStrValue addAttribute:NSForegroundColorAttributeName
						value:controlColor
						range:stringLenghtRange];

	[newStrValue addAttribute:NSFontAttributeName
						value:[_serverList serverCellFont]
						range:stringLenghtRange];

	/**************************************************************/
	/* Set the text field value to our new string. */
	/**************************************************************/

	if ([currentStrValue isEqual:newStrValue] == NO) {
		[_customTextField setAttributedStringValue:newStrValue];
	}

	/* There is a freak bug when animations will result in our frame for our text
	 field being all funky wrong. This resets the frame to the correct origin. */
	NSRect textFieldFrame = [_customTextField frame];
	NSRect serverListFrame = [_serverList frame];

	textFieldFrame.origin.y = 2;

	textFieldFrame.origin.x = [_serverList serverCellTextFieldLeftMargin];

	textFieldFrame.size.width  = serverListFrame.size.width;
	textFieldFrame.size.width -= [_serverList serverCellTextFieldLeftMargin];
	textFieldFrame.size.width -= [_serverList serverCellTextFieldRightMargin];

	[_customTextField setFrame:textFieldFrame];
}


#pragma mark -
#pragma mark Child Item Drawing

- (void)drawStatusBadge:(NSString *)iconName withAlpha:(CGFloat)alpha
{
	/* Stop constantly redrawing. */
	NSString *cacheToken = [NSString stringWithFormat:@"%@—%f", iconName, alpha];

	if (_cachedStatusBadgeFile) {
		if ([cacheToken hash] == [_cachedStatusBadgeFile hash]) {
			return; // Do not draw the same icon two times.
		}
	}

	_cachedStatusBadgeFile = cacheToken;

	/* Begin draw. */
	NSImage *oldImage = [NSImage imageNamed:iconName];

	/* Draw an image with alpha. */
	/* We already know all these images will be 16x16. */
	if (alpha < 1.0) {
		NSImage *newImage = [NSImage newImageWithSize:NSMakeSize(16, 16)];

		[newImage lockFocus];

		[oldImage drawInRect:NSMakeRect(0, 0, 16, 16)
					fromRect:NSZeroRect
				   operation:NSCompositeSourceOver
					fraction:alpha
			  respectFlipped:YES
					   hints:nil];

		[newImage unlockFocus];

		oldImage = newImage;
	}

	/* Set the new image. */
	[[self imageView] setImage:oldImage];

	/* The private message icon is designed a little different than the
	 channel status icon. Therefore, we have to change its origin to make
	 up for the difference in design. */
	NSRect oldRect = [[self imageView] frame];

	if ([iconName hasPrefix:@"channelRoomStatusIcon"]) {
		oldRect.origin.y = 0;
	} else {
		oldRect.origin.y = 1;
	}
	
	[[self imageView] setFrame:oldRect];
}

- (void)updateDrawingForChildItem:(NSRect)cellFrame
{
	/**************************************************************/
	/* Define our context variables. */
	/**************************************************************/

	NSDictionary *drawContext = [self drawingContext];

	BOOL invertedColors = [drawContext boolForKey:@"isInverted"];
	BOOL isKeyWindow = [drawContext boolForKey:@"isKeyWindow"];
	BOOL isGraphite = [drawContext boolForKey:@"isGraphite"];
	BOOL isSelected = [drawContext boolForKey:@"isSelected"];

	IRCChannel *channel = [_cellItem channel];
	
	/**************************************************************/
	/* Draw status icon for channel. */
	/**************************************************************/

	/* Status icon. */
	if ([channel isChannel]) {
		NSString *iconName = @"channelRoomStatusIcon";

		if (invertedColors) {
			iconName = [iconName stringByAppendingString:@"_Dark"];
		} else {
			iconName = [iconName stringByAppendingString:@"_Aqua"];
		}
		
		if ([channel isActive]) {
			[self drawStatusBadge:iconName withAlpha:1.0];
		} else {
			[self drawStatusBadge:iconName withAlpha:0.4];
		}
	} else {
		if ([channel isActive]) {
			[self drawStatusBadge:[_serverList privateMessageStatusIconFilename:isSelected] withAlpha:0.8];
		} else {
			[self drawStatusBadge:[_serverList privateMessageStatusIconFilename:isSelected] withAlpha:0.5];
		}
	}

	/**************************************************************/
	/* Create our new string from scratch. */
	/**************************************************************/

	/* The new string inherits the attributes of the text field so that stuff that we do not
	 define like the paragraph style is passed along and not lost when we define a new value. */
	NSString *cellLabel = [_cellItem label];

	NSAttributedString *currentStrValue = [_customTextField attributedStringValue];

	NSRange stringLenghtRange = NSMakeRange(0, [currentStrValue length]);

	NSMutableAttributedString *newStrValue = [currentStrValue mutableCopy];

	/* Has the label changed? */
	if ([cellLabel isEqualToString:[currentStrValue string]] == NO) {
		[newStrValue replaceCharactersInRange:stringLenghtRange withString:[_cellItem label]];

		stringLenghtRange = NSMakeRange(0, [currentStrValue length]);
	}

	/* Build badge context. */
	[self updateMessageCountBadge:drawContext];
	
	/* Define the text shadow information. */
	NSShadow *itemShadow = [NSShadow new];

	[itemShadow setShadowBlurRadius:1.0];

	[itemShadow setShadowOffset:NSMakeSize(0, -1)];

	if (isSelected == NO) {
		[itemShadow setShadowColor:[_serverList channelCellNormalTextShadowColor]];
	} else {
		if (invertedColors == NO) {
			[itemShadow setShadowBlurRadius:2.0];
		}

		if (isKeyWindow) {
			if (isGraphite && invertedColors == NO) {
				[itemShadow setShadowColor:[_serverList graphiteTextSelectionShadowColor]];
			} else {
				[itemShadow setShadowColor:[_serverList channelCellSelectedTextShadowColorForActiveWindow]];
			}
		} else {
			[itemShadow setShadowColor:[_serverList channelCellSelectedTextShadowColorForInactiveWindow]];
		}
	}

	/**************************************************************/
	/* Set attributes on the new string. */
	/**************************************************************/

	if (isSelected) {
		[newStrValue addAttribute:NSFontAttributeName
							value:[_serverList selectedChannelCellFont]
							range:stringLenghtRange];

		if (isKeyWindow) {
			[newStrValue addAttribute:NSForegroundColorAttributeName
								value:[_serverList channelCellSelectedTextColorForActiveWindow]
								range:stringLenghtRange];
		} else {
			[newStrValue addAttribute:NSForegroundColorAttributeName
								value:[_serverList channelCellSelectedTextColorForInactiveWindow]
								range:stringLenghtRange];
		}
	} else {
		[newStrValue addAttribute:NSFontAttributeName
							value:[_serverList normalChannelCellFont]
							range:stringLenghtRange];

		if ([channel isActive]) {
			[newStrValue addAttribute:NSForegroundColorAttributeName
								value:[_serverList channelCellNormalTextColor]
								range:stringLenghtRange];
		} else {
			[newStrValue addAttribute:NSForegroundColorAttributeName
								value:[_serverList channelCellDisabledItemTextColor]
								range:stringLenghtRange];
		}
	}

	[newStrValue addAttribute:NSShadowAttributeName
						value:itemShadow
						range:stringLenghtRange];

	/**************************************************************/
	/* Set the text field value to our new string. */
	/**************************************************************/
	
	if ([currentStrValue isEqual:newStrValue] == NO) {
		[_customTextField setAttributedStringValue:newStrValue];
	}
}

- (void)updateMessageCountBadge:(NSDictionary *)drawContext
{
	NSObjectIsEmptyAssert(drawContext);

	/* Render badge. */
	if ( _badgeRenderer == nil) {
		 _badgeRenderer = [TVCServerListCellBadge new];

		[_badgeRenderer setServerList:_serverList];
	}

	NSImage *badgeImage = [_badgeRenderer drawBadgeForCellItem:_cellItem withDrawingContext:drawContext];

	/* Update frames. */
	NSRect badgeViewFrame = [_badgeCountImageCell frame];
	NSRect textFieldFrame = [_customTextField frame];
	NSRect serverListFrame = [_serverList frame];

	textFieldFrame.origin.y = 0;

	if (badgeImage) {
		NSSize scaledSize = [_badgeRenderer scaledSize];

		badgeViewFrame.size = scaledSize;

		badgeViewFrame.origin.y  = 1;
		badgeViewFrame.origin.x  = serverListFrame.size.width;
		badgeViewFrame.origin.x -= scaledSize.width;
		badgeViewFrame.origin.x -= [_serverList messageCountBadgeRightMargin];

		[_badgeCountImageCell setImage:badgeImage];
		[_badgeCountImageCell setHidden:NO];
	} else {
		badgeViewFrame.size = NSZeroSize;

		[_badgeCountImageCell setImage:nil];
		[_badgeCountImageCell setHidden:YES];
	}

	textFieldFrame.origin.x = [_serverList channelCellTextFieldLeftMargin];

	textFieldFrame.size.width  = (serverListFrame.size.width - [_serverList channelCellTextFieldLeftMargin]);
	textFieldFrame.size.width -= badgeViewFrame.size.width;
	textFieldFrame.size.width -= [_serverList messageCountBadgeRightMargin];

	if ([TPCPreferences useLargeFontForSidebars] &&
		[TPCPreferences runningInHighResolutionMode])
	{
		textFieldFrame.origin.y = -0.5;
	}

	[_customTextField setFrame:textFieldFrame];
	[_badgeCountImageCell setFrame:badgeViewFrame];
}

@end

@implementation TVCServerListCellGroupItem
/* For future use. */
@end

@implementation TVCServerListCellChildItem
/* For future use. */
@end

@implementation TVCServerListRowCell

- (void)drawDraggingDestinationFeedbackInRect:(NSRect)dirtyRect
{
	/* Ignore this. */
}

- (void)drawSelectionInRect:(NSRect)dirtyRect
{
	/* Ignore this. */
}

- (void)drawRect:(NSRect)dirtyRect
{
	/* Ignore this. */
}

- (void)didAddSubview:(NSView *)subview
{
	id firstObject = [self subviews][0];

	if ([firstObject isKindOfClass:[TVCServerListCellGroupItem class]]) {
		if ([subview isKindOfClass:[NSButton class]]) {
			TVCServerListCellGroupItem *groupItem = firstObject;

			[groupItem updateGroupDisclosureTriangle:(id)subview];
		}
	}

	[super didAddSubview:subview];
}

@end
