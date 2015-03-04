//
//  RWTLevel.h
//  CookieCrunch
//
//  Created by oguzhan.colak on 11-11-14.
//  Copyright (c) 2014 Oguzhan COLAK All rights reserved.
//

#import "RWTCookie.h"
#import "RWTTile.h"
#import "RWTSwap.h"
#import "RWTChain.h"

static const NSInteger NumColumns = 9;
static const NSInteger NumRows = 9;

@interface RWTLevel : NSObject

@property (assign, nonatomic) NSUInteger targetScore;
@property (assign, nonatomic) NSUInteger maximumMoves;

// Create a level by loading it from a file.
- (instancetype)initWithFile:(NSString *)filename;

// Fills up the level with new RWTCookie objects. The level is guaranteed free
// from matches at this point.
// You call this method at the beginning of a new game and whenever the player
// taps the Shuffle button.
// Returns a set containing all the new RWTCookie objects.
- (NSSet *)shuffle;

// Returns the cookie at the specified column and row, or nil when there is none.
- (RWTCookie *)cookieAtColumn:(NSInteger)column row:(NSInteger)row;

// Determines whether there's a tile at the specified column and row.
- (RWTTile *)tileAtColumn:(NSInteger)column row:(NSInteger)row;

// Swaps the positions of the two cookies from the RWTSwap object.
- (void)performSwap:(RWTSwap *)swap;

// Determines whether the suggested swap is a valid one, i.e. it results in at
// least one new chain of 3 or more cookies of the same type.
- (BOOL)isPossibleSwap:(RWTSwap *)swap;

// Recalculates which moves are valid.
- (void)detectPossibleSwaps;

// Detects whether there are any chains of 3 or more cookies, and removes them
// from the level.
// Returns a set containing RWTChain objects, which describe the RWTCookies
// that were removed.
- (NSSet *)removeMatches;

// Detects where there are holes and shifts any cookies down to fill up those
// holes. In effect, this "bubbles" the holes up to the top of the column.
// Returns an array that contains a sub-array for each column that had holes,
// with the RWTCookie objects that have shifted. Those cookies are already
// moved to their new position. The objects are ordered from the bottom up.
- (NSArray *)fillHoles;

// Where necessary, adds new cookies to fill up the holes at the top of the
// columns.
// Returns an array that contains a sub-array for each column that had holes,
// with the new RWTCookie objects. Cookies are ordered from the top down.
- (NSArray *)topUpCookies;

// Should be called at the start of every new turn.
- (void)resetComboMultiplier;

@end
