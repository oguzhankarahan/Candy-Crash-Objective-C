//
//  RWTLevel.m
//  CookieCrunch
//
//  Created by oguzhan.colak on 11-11-14.
//  Copyright (c) 2014 Oguzhan COLAK All rights reserved.
//

#import "RWTLevel.h"

@interface RWTLevel ()

// The list of swipes that result in a valid swap. Used to determine whether
// the player can make a certain swap, whether the board needs to be shuffled,
// and to generate hints.
@property (strong, nonatomic) NSSet *possibleSwaps;

// The second chain gets twice its regular score, the third chain three times,
// and so on. This multiplier is reset for every next turn.
@property (assign, nonatomic) NSUInteger comboMultiplier;

@end

@implementation RWTLevel {
  // The 2D array that contains the layout of the level.
  RWTTile *_tiles[NumColumns][NumRows];

  // The 2D array that keeps track of where the RWTCookies are.
  RWTCookie *_cookies[NumColumns][NumRows];
}

#pragma mark - Level Loading

- (instancetype)initWithFile:(NSString *)filename {
  self = [super init];
  if (self != nil) {
    NSDictionary *dictionary = [self loadJSON:filename];

    // The dictionary contains an array named "tiles". This array contains one
    // element for each row of the level. Each of those row elements in turn is
    // also an array describing the columns in that row. If a column is 1, it
    // means there is a tile at that location, 0 means there is not.

    // Loop through the rows...
    [dictionary[@"tiles"] enumerateObjectsUsingBlock:^(NSArray *array, NSUInteger row, BOOL *stop) {

      // Loop through the columns in the current row...
      [array enumerateObjectsUsingBlock:^(NSNumber *value, NSUInteger column, BOOL *stop) {

        // Note: In Sprite Kit (0,0) is at the bottom of the screen,
        // so we need to read this file upside down.
        NSInteger tileRow = NumRows - row - 1;

        // If the value is 1, create a tile object.
        if ([value integerValue] == 1) {
          _tiles[column][tileRow] = [[RWTTile alloc] init];
        }
      }];
    }];
    
    self.targetScore = [dictionary[@"targetScore"] unsignedIntegerValue];
    self.maximumMoves = [dictionary[@"moves"] unsignedIntegerValue];
  }
  return self;
}

- (NSDictionary *)loadJSON:(NSString *)filename {

  NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"json"];
  if (path == nil) {
    NSLog(@"Could not find level file: %@", filename);
    return nil;
  }

  NSError *error;
  NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
  if (data == nil) {
    NSLog(@"Could not load level file: %@, error: %@", filename, error);
    return nil;
  }

  NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (dictionary == nil || ![dictionary isKindOfClass:[NSDictionary class]]) {
    NSLog(@"Level file '%@' is not valid JSON: %@", filename, error);
    return nil;
  }

  return dictionary;
}

#pragma mark - Game Setup

- (NSSet *)shuffle {
  NSSet *set;

  do {
    // Removes the old cookies and fills up the level with all new ones.
    set = [self createInitialCookies];

    // At the start of each turn we need to detect which cookies the player can
    // actually swap. If the player tries to swap two cookies that are not in
    // this set, then the game does not accept this as a valid move.
    // This also tells you whether no more swaps are possible and the game needs
    // to automatically reshuffle.
    [self detectPossibleSwaps];

    //NSLog(@"possible swaps: %@", self.possibleSwaps);

    // If there are no possible moves, then keep trying again until there are.
  }
  while ([self.possibleSwaps count] == 0);

  return set;
}

- (NSSet *)createInitialCookies {

  NSMutableSet *set = [NSMutableSet set];

  // Loop through the rows and columns of the 2D array. Note that column 0,
  // row 0 is in the bottom-left corner of the array.
  for (NSInteger row = 0; row < NumRows; row++) {
    for (NSInteger column = 0; column < NumColumns; column++) {

      // Only make a new cookie if there is a tile at this spot.
      if (_tiles[column][row] != nil) {

        // Pick the cookie type at random, and make sure that this never
        // creates a chain of 3 or more. We want there to be 0 matches in
        // the initial state.
        NSUInteger cookieType;
        do {
          cookieType = arc4random_uniform(NumCookieTypes) + 1;
        }
        while ((column >= 2 &&
                _cookies[column - 1][row].cookieType == cookieType &&
                _cookies[column - 2][row].cookieType == cookieType)
            ||
               (row >= 2 &&
                _cookies[column][row - 1].cookieType == cookieType &&
                _cookies[column][row - 2].cookieType == cookieType));

        // Create a new cookie and add it to the 2D array.
        RWTCookie *cookie = [self createCookieAtColumn:column row:row withType:cookieType];

        // Also add the cookie to the set so we can tell our caller about it.
        [set addObject:cookie];
      }
    }
  }
  return set;
}

- (RWTCookie *)createCookieAtColumn:(NSInteger)column row:(NSInteger)row withType:(NSUInteger)cookieType {
  RWTCookie *cookie = [[RWTCookie alloc] init];
  cookie.cookieType = cookieType;
  cookie.column = column;
  cookie.row = row;
  _cookies[column][row] = cookie;
  return cookie;
}

- (void)resetComboMultiplier {
  self.comboMultiplier = 1;
}

#pragma mark - Detecting Swaps

- (void)detectPossibleSwaps {

  NSMutableSet *set = [NSMutableSet set];

  for (NSInteger row = 0; row < NumRows; row++) {
    for (NSInteger column = 0; column < NumColumns; column++) {

      RWTCookie *cookie = _cookies[column][row];
      if (cookie != nil) {

        // Is it possible to swap this cookie with the one on the right?
        // Note: don't need to check the last column.
        if (column < NumColumns - 1) {

          // Have a cookie in this spot? If there is no tile, there is no cookie.
          RWTCookie *other = _cookies[column + 1][row];
          if (other != nil) {
            // Swap them
            _cookies[column][row] = other;
            _cookies[column + 1][row] = cookie;
            
            // Is either cookie now part of a chain?
            if ([self hasChainAtColumn:column + 1 row:row] ||
                [self hasChainAtColumn:column row:row]) {

              RWTSwap *swap = [[RWTSwap alloc] init];
              swap.cookieA = cookie;
              swap.cookieB = other;
              [set addObject:swap];
            }

            // Swap them back
            _cookies[column][row] = cookie;
            _cookies[column + 1][row] = other;
          }
        }

        // Is it possible to swap this cookie with the one above?
        // Note: don't need to check the last row.
        if (row < NumRows - 1) {

          // Have a cookie in this spot? If there is no tile, there is no cookie.
          RWTCookie *other = _cookies[column][row + 1];
          if (other != nil) {
            // Swap them
            _cookies[column][row] = other;
            _cookies[column][row + 1] = cookie;

            // Is either cookie now part of a chain?
            if ([self hasChainAtColumn:column row:row + 1] ||
                [self hasChainAtColumn:column row:row]) {

              RWTSwap *swap = [[RWTSwap alloc] init];
              swap.cookieA = cookie;
              swap.cookieB = other;
              [set addObject:swap];
            }

            // Swap them back
            _cookies[column][row] = cookie;
            _cookies[column][row + 1] = other;
          }
        }
      }
    }
  }

  self.possibleSwaps = set;
}

- (BOOL)hasChainAtColumn:(NSInteger)column row:(NSInteger)row {
  NSUInteger cookieType = _cookies[column][row].cookieType;

  NSUInteger horzLength = 1;
  for (NSInteger i = column - 1; i >= 0 && _cookies[i][row].cookieType == cookieType; i--, horzLength++) ;
  for (NSInteger i = column + 1; i < NumColumns && _cookies[i][row].cookieType == cookieType; i++, horzLength++) ;
  if (horzLength >= 3) return YES;

  NSUInteger vertLength = 1;
  for (NSInteger i = row - 1; i >= 0 && _cookies[column][i].cookieType == cookieType; i--, vertLength++) ;
  for (NSInteger i = row + 1; i < NumRows && _cookies[column][i].cookieType == cookieType; i++, vertLength++) ;
  return (vertLength >= 3);
}

#pragma mark - Swapping

- (void)performSwap:(RWTSwap *)swap {
  // Need to make temporary copies of these because they get overwritten.
  NSInteger columnA = swap.cookieA.column;
  NSInteger rowA = swap.cookieA.row;
  NSInteger columnB = swap.cookieB.column;
  NSInteger rowB = swap.cookieB.row;

  // Swap the cookies. We need to update the array as well as the column
  // and row properties of the RWTCookie objects, or they go out of sync!
  _cookies[columnA][rowA] = swap.cookieB;
  swap.cookieB.column = columnA;
  swap.cookieB.row = rowA;

  _cookies[columnB][rowB] = swap.cookieA;
  swap.cookieA.column = columnB;
  swap.cookieA.row = rowB;
}

#pragma mark - Detecting Matches

- (NSSet *)removeMatches {
  NSSet *horizontalChains = [self detectHorizontalMatches];
  NSSet *verticalChains = [self detectVerticalMatches];

  // Note: to detect more advanced patterns such as an L shape, you can see
  // whether a cookie is in both the horizontal & vertical chains sets and
  // whether it is the first or last in the array (at a corner). Then you
  // create a new RWTChain object with the new type and remove the other two.

  [self removeCookies:horizontalChains];
  [self removeCookies:verticalChains];

  [self calculateScores:horizontalChains];
  [self calculateScores:verticalChains];

  return [horizontalChains setByAddingObjectsFromSet:verticalChains];
}

- (NSSet *)detectHorizontalMatches {

  // Contains the RWTCookie objects that were part of a horizontal chain.
  // These cookies must be removed.
  NSMutableSet *set = [NSMutableSet set];

  for (NSInteger row = 0; row < NumRows; row++) {

    // Don't need to look at last two columns.
    // Note: for-loop without increment.
    for (NSInteger column = 0; column < NumColumns - 2; ) {

      // If there is a cookie/tile at this position...
      if (_cookies[column][row] != nil) {
        NSUInteger matchType = _cookies[column][row].cookieType;

        // And the next two columns have the same type...
        if (_cookies[column + 1][row].cookieType == matchType
         && _cookies[column + 2][row].cookieType == matchType) {

          // ...then add all the cookies from this chain into the set.
          RWTChain *chain = [[RWTChain alloc] init];
          chain.chainType = ChainTypeHorizontal;
          do {
            [chain addCookie:_cookies[column][row]];
            column += 1;
          }
          while (column < NumColumns && _cookies[column][row].cookieType == matchType);

          [set addObject:chain];
          continue;
        }
      }

      // Cookie did not match or empty tile, so skip over it.
      column += 1;
    }
  }
  return set;
}

// Same as the horizontal version but just steps through the array differently.
- (NSSet *)detectVerticalMatches {
  NSMutableSet *set = [NSMutableSet set];

  for (NSInteger column = 0; column < NumColumns; column++) {
    for (NSInteger row = 0; row < NumRows - 2; ) {
      if (_cookies[column][row] != nil) {
        NSUInteger matchType = _cookies[column][row].cookieType;

        if (_cookies[column][row + 1].cookieType == matchType
         && _cookies[column][row + 2].cookieType == matchType) {

          RWTChain *chain = [[RWTChain alloc] init];
          chain.chainType = ChainTypeVertical;
          do {
            [chain addCookie:_cookies[column][row]];
            row += 1;
          }
          while (row < NumRows && _cookies[column][row].cookieType == matchType);

          [set addObject:chain];
          continue;
        }
      }
      row += 1;
    }
  }
  return set;
}

- (void)removeCookies:(NSSet *)chains {
  for (RWTChain *chain in chains) {
    for (RWTCookie *cookie in chain.cookies) {
      _cookies[cookie.column][cookie.row] = nil;
    }
  }
}

- (void)calculateScores:(NSSet *)chains {
  // 3-chain is 60 pts, 4-chain is 120, 5-chain is 180, and so on
  for (RWTChain *chain in chains) {
    chain.score = 60 * ([chain.cookies count] - 2) * self.comboMultiplier;
    self.comboMultiplier++;
  }
}

#pragma mark - Detecting Holes

- (NSArray *)fillHoles {
  NSMutableArray *columns = [NSMutableArray array];

  // Loop through the rows, from bottom to top. It's handy that our row 0 is
  // at the bottom already. Because we're scanning from bottom to top, this
  // automatically causes an entire stack to fall down to fill up a hole.
  // We scan one column at a time.
  for (NSInteger column = 0; column < NumColumns; column++) {

    NSMutableArray *array;
    for (NSInteger row = 0; row < NumRows; row++) {

      // If there is a tile at this position but no cookie, then there's a hole.
      if (_tiles[column][row] != nil && _cookies[column][row] == nil) {

        // Scan upward to find a cookie.
        for (NSInteger lookup = row + 1; lookup < NumRows; lookup++) {
          RWTCookie *cookie = _cookies[column][lookup];
          if (cookie != nil) {
            // Swap that cookie with the hole.
            _cookies[column][lookup] = nil;
            _cookies[column][row] = cookie;
            cookie.row = row;

            // For each column, we return an array with the cookies that have
            // fallen down. Cookies that are lower on the screen are first in
            // the array. We need an array to keep this order intact, so the
            // animation code can apply the correct kind of delay.
            if (array == nil) {
              array = [NSMutableArray array];
              [columns addObject:array];
            }
            [array addObject:cookie];

            // Don't need to scan up any further.
            break;
          }
        }
      }
    }
  }
  return columns;
}

- (NSArray *)topUpCookies {
  NSMutableArray *columns = [NSMutableArray array];
  NSUInteger cookieType = 0;

  // Detect where we have to add the new cookies. If a column has X holes,
  // then it also needs X new cookies. The holes are all on the top of the
  // column now, but the fact that there may be gaps in the tiles makes this
  // a little trickier.
  for (NSInteger column = 0; column < NumColumns; column++) {

    // This time scan from top to bottom. We can end when we've found the
    // first cookie.
    NSMutableArray *array;
    for (NSInteger row = NumRows - 1; row >= 0 && _cookies[column][row] == nil; row--) {

      // Found a hole?
      if (_tiles[column][row] != nil) {

        // Randomly create a new cookie type. The only restriction is that
        // it cannot be equal to the previous type. This prevents too many
        // "freebie" matches.
        NSUInteger newCookieType;
        do {
          newCookieType = arc4random_uniform(NumCookieTypes) + 1;
        } while (newCookieType == cookieType);
        cookieType = newCookieType;

        // Create a new cookie.
        RWTCookie *cookie = [self createCookieAtColumn:column row:row withType:cookieType];

        // Add the cookie to the array for this column.
        // Note that we only allocate an array if a column actually has holes.
        // This cuts down on unnecessary allocations.
        if (array == nil) {
          array = [NSMutableArray array];
          [columns addObject:array];
        }
        [array addObject:cookie];
      }
    }
  }
  return columns;
}

#pragma mark - Querying the Level

- (RWTTile *)tileAtColumn:(NSInteger)column row:(NSInteger)row {
  NSAssert1(column >= 0 && column < NumColumns, @"Invalid column: %ld", (long)column);
  NSAssert1(row >= 0 && row < NumRows, @"Invalid row: %ld", (long)row);

  return _tiles[column][row];
}

- (RWTCookie *)cookieAtColumn:(NSInteger)column row:(NSInteger)row {
  NSAssert1(column >= 0 && column < NumColumns, @"Invalid column: %ld", (long)column);
  NSAssert1(row >= 0 && row < NumRows, @"Invalid row: %ld", (long)row);

  return _cookies[column][row];
}

- (BOOL)isPossibleSwap:(RWTSwap *)swap {
  return [self.possibleSwaps containsObject:swap];
}

@end
