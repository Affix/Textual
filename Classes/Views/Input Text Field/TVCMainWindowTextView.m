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

/* Much of the following drawing has been created by Dan Messing for the class "SSTextField" */
#define _WindowContentBorderDefaultHeight		38.0
#define _WindowSegmentedControllerDefaultX		10.0

#define _InputTextFieldOriginDefaultX			166.0

#define _KeyObservingArray 	@[	@"TextFieldAutomaticSpellCheck", \
								@"TextFieldAutomaticGrammarCheck", \
								@"TextFieldAutomaticSpellCorrection", \
								@"TextFieldSmartCopyPaste", \
								@"TextFieldSmartQuotes", \
								@"TextFieldSmartDashes", \
								@"TextFieldSmartLinks", \
								@"TextFieldDataDetectors", \
								@"TextFieldTextReplacement"]

@interface TVCMainWindowTextView ()
@property (nonatomic, assign) NSInteger lastDrawLineCount;
@property (nonatomic, strong) NSAttributedString *placeholderString;
@property (nonatomic, assign) TVCMainWindowTextViewFontSize cachedFontSize;
@end

@implementation TVCMainWindowTextView

#pragma mark -
#pragma mark Drawing

- (id)initWithCoder:(NSCoder *)coder 
{
	if (self = [super initWithCoder:coder]) {
		/* Set preferred font */
		[self updateTextBoxCachedPreferredFontSize];

		/* Have parent text field inherit new values. */
		[self defineDefaultTypeSetterAttributes];

		/* Have parent text field inherit new values. */
		[self updateTypeSetterAttributes]; // --------------/

		/* Bind observation keys. */
		for (NSString *key in _KeyObservingArray) {
			[RZUserDefaults() addObserver:self
							   forKeyPath:key
								  options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
								  context:NULL];
		}

		/* Listen for ourselves. */
		[self setDelegate:self];
    }
	
    return self;
}

- (void)dealloc
{
	for (NSString *key in _KeyObservingArray) {
		[RZUserDefaults() removeObserver:self forKeyPath:key];
	}
}

#pragma mark -
#pragma mark Events

- (void)rightMouseDown:(NSEvent *)theEvent
{
	NSWindowNegateActionWithAttachedSheet();

	[super rightMouseDown:theEvent];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSWindowNegateActionWithAttachedSheet();

	[super mouseDown:theEvent];
}

#pragma mark -
#pragma mark Segmented Controller

- (void)redrawOriginPoints
{
	/* Update origin points. */
	NSInteger defaultSegmentX = _WindowSegmentedControllerDefaultX;
	NSInteger defaultInputbxX = _InputTextFieldOriginDefaultX;

	NSInteger resultOriginX = 0;
	NSInteger resultSizeWth = (defaultInputbxX - defaultSegmentX);

	/* Define controls. */
	TVCMainWindow *mainWindow = [_masterController mainWindow];

	TVCMainWindowSegmentedController *controller = [mainWindow segmentedController];

	NSScrollView *internalScrollview = [self enclosingScrollView];

	/* Update controller based on preferences. */
	if ([TPCPreferences hideMainWindowSegmentedController]) {
		[controller setHidden:YES];

		resultOriginX = defaultSegmentX;
	} else {
		[controller setHidden:NO];
		
		resultOriginX  = defaultInputbxX;
		resultSizeWth *= -1;
	}

	/* Get frames of view. */
	NSRect fronFrame = [internalScrollview frame];

	NSRect backFrame =  [_backgroundView frame];

	/* Change frames if necessary. */
	if (NSDissimilarObjects(resultOriginX, fronFrame.origin.x) &&
		NSDissimilarObjects(resultOriginX, backFrame.origin.x))
	{
		fronFrame.size.width += resultSizeWth;
		backFrame.size.width += resultSizeWth;
		
		fronFrame.origin.x = resultOriginX;
		backFrame.origin.x = resultOriginX;
		
		[internalScrollview setFrame:fronFrame];

		[_backgroundView setFrame:backFrame];
	}
}

#pragma mark -
#pragma mark Everything Else.

- (BOOL)textDirectionIsNatural
{
	return ([self baseWritingDirection] == NSWritingDirectionRightToLeft);
}

- (void)updateTextDirection
{
	if ([TPCPreferences rightToLeftFormatting]) {
		[self setBaseWritingDirection:NSWritingDirectionRightToLeft];
	} else {
		[self setBaseWritingDirection:NSWritingDirectionLeftToRight];
	}
}

- (void)internalTextDidChange:(NSNotification *)aNotification
{
	[self resetTextFieldCellSize:NO];
}

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect]) {
		NSString *value = [self stringValue];
		
		if (NSObjectIsEmpty(value)) {
			if ([self textDirectionIsNatural]) {
				if (_cachedFontSize == TVCMainWindowTextViewFontLargeSize) {
					[_placeholderString drawAtPoint:NSMakePoint(6, 2)];
				} else {
					[_placeholderString drawAtPoint:NSMakePoint(6, 1)];
				}
			}
		} else {
			[super drawRect:dirtyRect];
		}
	}
}

- (void)paste:(id)sender
{
	/* Perform paste. */
    [super paste:self];

	/* Resize text field to fit new data. */
    [self resetTextFieldCellSize:NO];
}

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
    if (aSelector == @selector(insertNewline:)) {
		/* Did receive return event which means the main window can be
		 inform text was entered so that it can treat it as an IRC event. */
		[[_masterController mainWindow] textEntered];

		/* -textEntered is supposed to clear the text field, so resize it. */
        [self resetTextFieldCellSize:NO];

		/* Let Apple know we handled this event. */
        return YES;
    }
    
    return NO;
}

#pragma mark -
#pragma mark Multi-line Text Box Drawing

- (NSDictionary *)placeholderStringAttributes
{
	return @{NSFontAttributeName : [self defaultTextFieldFont], NSForegroundColorAttributeName : [NSColor grayColor]};
}

- (void)updateTextBoxCachedPreferredFontSize
{
	/* Update the font. */
	_cachedFontSize = [TPCPreferences mainTextBoxFontSize];

	if (_cachedFontSize == TVCMainWindowTextViewFontNormalSize) {
		[self setDefaultTextFieldFont:[NSFont fontWithName:@"Helvetica" size:12.0]];
	} else if (_cachedFontSize == TVCMainWindowTextViewFontLargeSize) {
		[self setDefaultTextFieldFont:[NSFont fontWithName:@"Helvetica" size:14.0]];
	} else if (_cachedFontSize == TVCMainWindowTextViewFontExtraLargeSize) {
		[self setDefaultTextFieldFont:[NSFont fontWithName:@"Helvetica" size:16.0]];
	}

	/* Update the placeholder string. */
	NSDictionary *attrs = [self placeholderStringAttributes];

	_placeholderString = nil;
	_placeholderString = [NSAttributedString stringWithBase:BLS(1000) attributes:attrs];

	/* Prepare draw. */
	[self setNeedsDisplay:YES];
}

- (void)updateTextBoxBasedOnPreferredFontSize
{
	TVCMainWindowTextViewFontSize cachedFontSize = _cachedFontSize;

	/* Update actual cache. */
	[self updateTextBoxCachedPreferredFontSize];

	/* We only update the font sizes if there was a chagne. */
	if (NSDissimilarObjects(cachedFontSize, _cachedFontSize)) {
		[self updateAllFontSizesToMatchTheDefaultFont];

		[self updateTypeSetterAttributes];
	}

	/* Reset frames. */
	[self resetTextFieldCellSize:YES];
}

/* It is easier for us to define predetermined values for these paramaters instead
 of trying to overcomplicate our math by calculating the point height of our font
 and other variables. We only support three text sizes so why not hard code? */
- (NSInteger)backgroundViewMaximumHeight
{
	NSRect windowFrame = [[self window] frame];

	return (windowFrame.size.height - 50);
}

- (NSInteger)backgroundViewDefaultHeight
{
	if (_cachedFontSize == TVCMainWindowTextViewFontNormalSize) {
		return 23.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontLargeSize) {
		return 28.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontExtraLargeSize) {
		return 30.0;
	}
	
	return 23.0;
}

- (NSInteger)backgroundViewHeightMultiplier
{
	if (_cachedFontSize == TVCMainWindowTextViewFontNormalSize) {
		return 14.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontLargeSize) {
		return 17.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontExtraLargeSize) {
		return 19.0;
	}

	return 14.0;
}

- (NSInteger)foregroundViewDefaultHeight
{
	if (_cachedFontSize == TVCMainWindowTextViewFontNormalSize) {
		return 18.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontLargeSize) {
		return 22.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontExtraLargeSize) {
		return 24.0;
	}

	return 18.0;
}

- (NSInteger)foregroundViewHeightMultiplier
{
	if (_cachedFontSize == TVCMainWindowTextViewFontNormalSize) {
		return 14.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontLargeSize) {
		return 17.0;
	} else if (_cachedFontSize == TVCMainWindowTextViewFontExtraLargeSize) {
		return 19.0;
	}

	return 14.0;
}

/* Do actual size math. */
- (void)resetTextFieldCellSize:(BOOL)force
{
	BOOL drawBezel = YES;

	NSWindow *mainWindow = [self window];

	NSView *superView = _splitterView;
	NSView *background = _backgroundView;

    NSScrollView *scroller = [self enclosingScrollView];

	NSRect superViewFrame = [superView frame];
	NSRect mainWindowFrame = [mainWindow frame];

	NSRect foregroundFrame = [scroller frame];
	NSRect backgroundFrame = [background frame];

	NSInteger contentBorder;

	NSInteger inputBoxForegroundDefaultHeight = [self foregroundViewDefaultHeight];
	NSInteger inputBoxBackgroundDefaultHeight = [self backgroundViewDefaultHeight];

	NSString *stringv = [self stringValue];

	if ([stringv length] < 1) {
		foregroundFrame.size.height = inputBoxForegroundDefaultHeight;
		backgroundFrame.size.height = inputBoxBackgroundDefaultHeight;

		if (NSDissimilarObjects(_lastDrawLineCount, 1)) {
			drawBezel = YES;
		}

		_lastDrawLineCount = 1;
	} else {
		NSInteger totalLinesBase = [self numberOfLines];

		if (_lastDrawLineCount == totalLinesBase && force == NO) {
			drawBezel = NO;
		}

		_lastDrawLineCount = totalLinesBase;

		if (drawBezel) {
			NSInteger totalLinesMath = (totalLinesBase - 1);

			NSInteger inputBoxForegroundHeightMultiplier = [self foregroundViewHeightMultiplier];
			NSInteger inputBoxBackgroundHeightMultiplier = [self backgroundViewHeightMultiplier];

			/* Calculate unfiltered height. */
			foregroundFrame.size.height = inputBoxForegroundDefaultHeight;
			backgroundFrame.size.height	= inputBoxBackgroundDefaultHeight;

			foregroundFrame.size.height += (totalLinesMath * inputBoxForegroundHeightMultiplier);
			backgroundFrame.size.height += (totalLinesMath * inputBoxBackgroundHeightMultiplier);

			NSInteger backgroundViewMaxHeight = [self backgroundViewMaximumHeight];

			/* Fix height if it exceeds are maximum. */
			if (backgroundFrame.size.height > backgroundViewMaxHeight) {
				for (NSInteger i = totalLinesMath; i >= 0; i--) {
					NSInteger newSize = 0;

					newSize  =      inputBoxBackgroundDefaultHeight;
					newSize += (i * inputBoxBackgroundHeightMultiplier);

					if (newSize > backgroundViewMaxHeight) {
						continue;
					} else {
						backgroundFrame.size.height = newSize;

						foregroundFrame.size.height  =      inputBoxForegroundDefaultHeight;
						foregroundFrame.size.height += (i * inputBoxForegroundHeightMultiplier);

						break;
					}
				}
			}
		}
	}

	if (drawBezel) {
		/* 14 is the top and bottom padding inside the content border. */
		contentBorder = (backgroundFrame.size.height + 14);

		superViewFrame.origin.y = contentBorder;

		if ([mainWindow isInFullscreenMode]) {
			superViewFrame.size.height = (mainWindowFrame.size.height - contentBorder);
		} else {
			/* 22 is added to account for menu bar when outside of fullscreen mode. */
			superViewFrame.size.height = (mainWindowFrame.size.height - contentBorder - 22);
		}

		[mainWindow setContentBorderThickness:contentBorder forEdge:NSMinYEdge];

		[scroller setFrame:foregroundFrame];
		[superView setFrame:superViewFrame];
		[background setFrame:backgroundFrame];
	}
}

#pragma mark -
#pragma mark NSTextView Context Menu Preferences

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualIgnoringCase:@"TextFieldAutomaticSpellCheck"]) {
		[self setContinuousSpellCheckingEnabled:[TPCPreferences textFieldAutomaticSpellCheck]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldAutomaticGrammarCheck"]) {
		[self setGrammarCheckingEnabled:[TPCPreferences textFieldAutomaticGrammarCheck]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldAutomaticSpellCorrection"]) {
		[self setAutomaticSpellingCorrectionEnabled:[TPCPreferences textFieldAutomaticSpellCorrection]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldSmartCopyPaste"]) {
		[self setSmartInsertDeleteEnabled:[TPCPreferences textFieldSmartCopyPaste]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldSmartQuotes"]) {
		[self setAutomaticQuoteSubstitutionEnabled:[TPCPreferences textFieldSmartQuotes]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldSmartDashes"]) {
		[self setAutomaticDashSubstitutionEnabled:[TPCPreferences textFieldSmartDashes]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldSmartLinks"]) {
		[self setAutomaticLinkDetectionEnabled:[TPCPreferences textFieldSmartLinks]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldDataDetectors"]) {
		[self setAutomaticDataDetectionEnabled:[TPCPreferences textFieldDataDetectors]];
	} else if ([keyPath isEqualIgnoringCase:@"TextFieldTextReplacement"]) {
		[self setAutomaticTextReplacementEnabled:[TPCPreferences textFieldTextReplacement]];
	} else if ([super respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)setContinuousSpellCheckingEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldAutomaticSpellCheck:flag];
	
	[super setContinuousSpellCheckingEnabled:flag];
}

- (void)setGrammarCheckingEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldAutomaticGrammarCheck:flag];
	
	[super setGrammarCheckingEnabled:flag];
}

- (void)setAutomaticSpellingCorrectionEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldAutomaticSpellCorrection:flag];
	
	[super setAutomaticSpellingCorrectionEnabled:flag];
}

- (void)setSmartInsertDeleteEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldSmartCopyPaste:flag];
	
	[super setSmartInsertDeleteEnabled:flag];
}

- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldSmartQuotes:flag];
	
	[super setAutomaticQuoteSubstitutionEnabled:flag];
}

- (void)setAutomaticDashSubstitutionEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldSmartDashes:flag];
	
	[super setAutomaticDashSubstitutionEnabled:flag];
}

- (void)setAutomaticLinkDetectionEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldSmartLinks:flag];
	
	[super setAutomaticLinkDetectionEnabled:flag];
}

- (void)setAutomaticDataDetectionEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldDataDetectors:flag];
	
	[super setAutomaticDataDetectionEnabled:flag];
}

- (void)setAutomaticTextReplacementEnabled:(BOOL)flag
{
	[TPCPreferences setTextFieldTextReplacement:flag];
	
	[super setAutomaticTextReplacementEnabled:flag];
}

@end

#pragma mark -
#pragma mark Background Drawing

@implementation TVCMainWindowTextViewBackground

- (BOOL)mainWindowIsActive
{
	return [[_masterController mainWindow] isActive];
}

- (NSColor *)inputTextFieldBackgroundColor
{
	return [NSColor whiteColor];
}

- (NSColor *)inputTextFieldInsideShadowColor
{
	return [NSColor colorWithCalibratedWhite:0.88 alpha:1.0];
}

- (NSColor *)inputTextFieldOutsideShadowColor
{
	return [NSColor colorWithCalibratedWhite:1.0 alpha:0.394];
}

- (NSColor *)inputTextFieldOutlineColor
{
	if ([self mainWindowIsActive]) {
		return [NSColor colorWithCalibratedWhite:0.0 alpha:0.4];
	} else {
		return [NSColor colorWithCalibratedWhite:0.0 alpha:0.23];
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	if ([self needsToDrawRect:dirtyRect]) {
		NSRect cellBounds = [self frame];
		NSRect controlFrame;
		
		NSColor *controlColor;
		
		NSBezierPath *controlPath;
		
		/* Control Outside White Shadow. */
		controlColor = [self inputTextFieldOutsideShadowColor];

		controlFrame = NSMakeRect(0.0,
								  0.0,
								  cellBounds.size.width,
								  1.0);

		controlPath = [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:3.6 yRadius:3.6];
		
		[controlColor set];
		[controlPath fill];
		
		/* Black Outline. */
		controlColor = [self inputTextFieldOutlineColor];

		controlFrame = NSMakeRect(0.0,
								  1.0,
								   cellBounds.size.width,
								  (cellBounds.size.height - 1.0));

		controlPath = [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:3.6 yRadius:3.6];
		
		[controlColor set];
		[controlPath fill];
		
		/* White Background. */
		controlColor = [self inputTextFieldBackgroundColor];

		controlFrame = NSMakeRect(1.0,
								  2.0,
								  (cellBounds.size.width - 2.0),
								  (cellBounds.size.height - 4.0));

		controlPath	= [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:2.6 yRadius:2.6];
		
		[controlColor set];
		[controlPath fill];
		
		/* Inside White Shadow. */
		controlColor = [self inputTextFieldInsideShadowColor];

		controlFrame = NSMakeRect(2.0,
								  (cellBounds.size.height - 2.0),
								  (cellBounds.size.width - 4.0),
								  1.0);
		
		controlPath = [NSBezierPath bezierPathWithRoundedRect:controlFrame xRadius:2.9 yRadius:2.9];
		
		[controlColor set];
		[controlPath fill];
	}
}

@end
