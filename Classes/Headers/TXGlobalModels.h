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

/* Highest level objects implemented by Textual. */

/* Object state. */
TEXTUAL_EXTERN BOOL NSObjectIsEmpty(id obj);
TEXTUAL_EXTERN BOOL NSObjectIsNotEmpty(id obj);

TEXTUAL_EXTERN BOOL NSObjectsAreEqual(id obj1, id obj2);

/* Localization. */
TEXTUAL_EXTERN NSString *ULS(NSString *key, ...); // Undefined language string. Different prefix than "BaiscLanguage"
TEXTUAL_EXTERN NSString *BLS(NSInteger key, ...); // Basic Language String. Just supply the integer and any data.

TEXTUAL_EXTERN NSString *ULSWB(NSString *key, NSBundle *bundle, ...); // Undefined language string in secondary bundle.

/* Discussion: the text two methods were deprecated in favor of ULS() and BLS().
 There is nothing functionally wrong with these methods. The reason for deprecation
 is to allow a cleaner interface for localization. In this case, using an integer
 to reference basic ones which is much shorter. 
 
 For example: BLS(1000) instead of TXTLS(@"BasicLanguage[1000]")
 
 ULS() and BLS() also provide formatting abilities regardless of the key which 
 means there is no way to mix up which one to use unlike having to define TXTFLS
 for formatting and TXTLS for not. */
TEXTUAL_EXTERN NSString *TXTLS(NSString *key) TEXTUAL_DEPRECATED;
TEXTUAL_EXTERN NSString *TXTFLS(NSString *key, ...) TEXTUAL_DEPRECATED;

TEXTUAL_EXTERN NSString *TXLocalizedString(NSBundle *bundle, NSString *key, va_list args); // What all these call…

/* Time. */
TEXTUAL_EXTERN NSString *TXFormattedTimestamp(NSDate *date, NSString *format); // Acts as a forward for strftime(). TXDefaultTextualTimestampFormat is used when format is empty.

TEXTUAL_EXTERN NSString *TXHumanReadableTimeInterval(NSInteger dateInterval, BOOL shortValue, NSUInteger orderMatrix);

TEXTUAL_EXTERN NSDateFormatter *TXSharedISOStandardDateFormatter(void);

/* Everything else. */
TEXTUAL_EXTERN NSString *TXFormattedNumber(NSInteger number);

TEXTUAL_EXTERN NSInteger TXRandomNumber(NSInteger maxset);

TEXTUAL_EXTERN NSComparator NSDefaultComparator;
