/* ********************************************************************* 
       _____        _               _    ___ ____   ____
      |_   _|___  _| |_ _   _  __ _| |  |_ _|  _ \ / ___|
       | |/ _ \ \/ / __| | | |/ _` | |   | || |_) | |
       | |  __/>  <| |_| |_| | (_| | |   | ||  _ <| |___
       |_|\___/_/\_\\__|\__,_|\__,_|_|  |___|_| \_\\____|

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

@interface TVCServerListCellBadge ()
@property (nonatomic, strong) NSImage *cachedBadgeImage;
@property (nonatomic, strong) NSDictionary *cachedDrawContext;
@end

@implementation TVCServerListCellBadge

- (NSSize)scaledSize
{
	if (_cachedBadgeImage) {
		return [_cachedBadgeImage size];
	}else {
		return NSZeroSize;
	}
}

- (NSImage *)drawBadgeForCellItem:(id)cellItem withDrawingContext:(NSDictionary *)drawContext
{
	/* Do input validation. */
	PointerIsEmptyAssertReturn(cellItem, nil);

	NSObjectIsEmptyAssertReturn(drawContext, nil);

	/* Define local context information. */
	IRCChannel *channel = cellItem;

	IRCChannelConfig *channelConfig = [channel config];

	BOOL isSelected = [drawContext boolForKey:@"isSelected"];
	BOOL isKeyWindow = [drawContext boolForKey:@"isKeyWindow"];

	/* Gather information about the badge to draw. */
	BOOL drawMessageBadge = (isSelected == NO || (isKeyWindow == NO && isSelected));

	NSInteger channelTreeUnreadCount = [channel treeUnreadCount];
	NSInteger nicknameHighlightCount = [channel nicknameHighlightCount];
	
	BOOL isHighlight = (nicknameHighlightCount > 0);

	/* Even if badges are still disabled, we still show them if there is a highlight. */
	if ([channelConfig showTreeBadgeCount] == NO) {
		if (isHighlight) {
			channelTreeUnreadCount = nicknameHighlightCount;
		} else {
			return nil;
		}
	}

	/* Begin draw if we want to. */
	if (channelTreeUnreadCount > 0 && drawMessageBadge) {
		/* Build our local context. */
		NSMutableDictionary *newContext = [drawContext mutableCopy];

		/* Remove information that is constantly changing so we do not
		 keep redrawing when we do not have to. To see the information
		 passed to drawContext see TVCServerListCell.m. */
		[newContext removeObjectForKey:@"rowIndex"];
		[newContext removeObjectForKey:@"isKeyWindow"];

		/* Add new items. */
		[newContext setBool:isHighlight forKey:@"isHighlight"];
		
		[newContext setInteger:channelTreeUnreadCount forKey:@"unreadCount"];

		/* Compare context to cache. */
		if (_cachedBadgeImage) {
			if (_cachedDrawContext) {
				if ([_cachedDrawContext isEqualToDictionary:newContext]) {
					return _cachedBadgeImage;
				}
			}
		}

		/* The draw engine reads this. */
		_cachedDrawContext = newContext;

		/* Get the string being draw. */
		NSAttributedString *mcstring = [self messageCountBadgeText:channelTreeUnreadCount selected:(isSelected && isHighlight == NO)];

		/* Get the rect being drawn. */
		NSRect badgeRect = [self messageCountBadgeRectWithText:mcstring];

		/* Draw the badge. */
		NSImage *finalBadge = [self completeDrawFor:mcstring inFrame:badgeRect];

		if (finalBadge == nil) {
			_cachedDrawContext = nil;
		} else {
			_cachedBadgeImage = finalBadge;

			return finalBadge;
		}
	} else {
		_cachedDrawContext = nil;
		_cachedBadgeImage = nil;
	}

	/* Return nil if we do not have anything. */
	return nil;
}

#pragma mark -
#pragma mark Internal Drawing

- (NSAttributedString *)messageCountBadgeText:(NSInteger)messageCount selected:(BOOL)isSelected
{
	NSString *messageCountString = TXFormattedNumber(messageCount);

    /* Pick which font size best aligns with the badge. */
	NSColor *textColor;

	if (isSelected) {
		textColor = [_serverList messageCountBadgeSelectedTextColor];
	} else {
		textColor = [_serverList messageCountBadgeNormalTextColor];
	}

	NSFont *textFont = [_serverList messageCountBadgeFont];

	/* Create new atttributed string with attributes. */
	NSDictionary *attributes = @{NSFontAttributeName : textFont, NSForegroundColorAttributeName : textColor};

	NSAttributedString *mcstring = [NSAttributedString stringWithBase:messageCountString attributes:attributes];

	/* Return the result. */
	return mcstring;
}

- (NSRect)messageCountBadgeRectWithText:(NSAttributedString *)mcstring
{
	NSInteger messageCountWidth = (mcstring.size.width + ([_serverList messageCountBadgePadding] * 2));

	NSRect badgeFrame = NSMakeRect(0, 1, messageCountWidth, [_serverList messageCountBadgeHeight]);

	if (badgeFrame.size.width < [_serverList messageCountBadgeMinimumWidth]) {
		badgeFrame.size.width = [_serverList messageCountBadgeMinimumWidth];
	 }
	 
	 return badgeFrame;
}

- (NSImage *)completeDrawFor:(NSAttributedString *)mcstring inFrame:(NSRect)badgeFrame
{
	/*************************************************************/
	/* Prepare drawing. */
	/*************************************************************/

	BOOL isGraphite = [_cachedDrawContext boolForKey:@"isGraphite"];
	BOOL isSelected = [_cachedDrawContext boolForKey:@"isSelected"];
	BOOL isHighlight = [_cachedDrawContext boolForKey:@"isHighlight"];
	
	/* Create blank badge image. */
	/* 1 point is added to size to allow room for a shadow. */
	NSSize imageSize = NSMakeSize (badgeFrame.size.width,
								  (badgeFrame.size.height + 1));
	
	NSImage *newDrawImage = [NSImage newImageWithSize:imageSize];

	NSInteger predeterminedBadgeRadius = ([_serverList messageCountBadgeHeight] / 2.0);

	/* Lock focus for drawing. */
	[newDrawImage lockFocus];

	
	/*************************************************************/
	/* Begin drawing. */
	/*************************************************************/

	NSBezierPath *badgePath;

	/* Draw the badge's drop shadow. */
	if (isSelected == NO) {
		NSRect shadowFrame = badgeFrame;

		NSColor *shadowColor = [_serverList messageCountBadgeShadowColor];

		shadowFrame.origin.y -= 1; // Offset of 1 to simulate drop shadow.

		badgePath = [NSBezierPath bezierPathWithRoundedRect:shadowFrame
													xRadius:predeterminedBadgeRadius
													yRadius:predeterminedBadgeRadius];

		[shadowColor set];

		[badgePath fill];
	}

	/*************************************************************/
	/* Background color drawing. */
	/*************************************************************/

	/* Draw the background color. */
	NSColor *backgroundColor;

	if (isHighlight) {
		backgroundColor = [_serverList messageCountBadgeHighlightBackgroundColor];
	} else {
		if (isSelected) {
			backgroundColor = [_serverList messageCountBadgeSelectedBackgroundColor];
		} else {
			if (isGraphite) {
				backgroundColor = [_serverList messageCountBadgeGraphtieBackgroundColor];
			} else {
				backgroundColor = [_serverList messageCountBadgeAquaBackgroundColor];
			}
		}
	}

	badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeFrame
												xRadius:predeterminedBadgeRadius
												yRadius:predeterminedBadgeRadius];

	[backgroundColor set];

	[badgePath fill];

	/*************************************************************/
	/* Badge text drawing. */
	/*************************************************************/

	/* Center the text relative to the badge itself. */
	NSPoint badgeTextPoint;

	badgeTextPoint = NSMakePoint((NSMidX(badgeFrame) - (mcstring.size.width / 2.0)),
								 (NSMidY(badgeFrame) - (mcstring.size.height / 2.0)));

	
	if ([TPCPreferences runningInHighResolutionMode]) {
		badgeTextPoint.y -= 0.5;
	}
	
	/* The actual draw. */
	[mcstring drawAtPoint:badgeTextPoint];

	/*************************************************************/
	/* Finish drawing. */
	/*************************************************************/

	/* Remove focus from the draw image. */
	[newDrawImage unlockFocus];

	/* Return the result. */
	return newDrawImage;
}

@end
