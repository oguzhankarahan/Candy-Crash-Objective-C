//
//  RWTSwap.m
//  CookieCrunch
//
//  Created by oguzhan.colak on 11-11-14.
//  Copyright (c) 2014 Oguzhan COLAK All rights reserved.
//

#import "RWTSwap.h"
#import "RWTCookie.h"

@implementation RWTSwap

// By overriding this method you can use [NSSet containsObject:] to look for
// a matching RWTSwap object in that collection.
- (BOOL)isEqual:(id)object {

  // You can only compare this object against other RWTSwap objects.
  if (![object isKindOfClass:[RWTSwap class]]) return NO;

  // Two swaps are equal if they contain the same cookie, but it doesn't
  // matter whether they're called A in one and B in the other.
  RWTSwap *other = (RWTSwap *)object;
  return (other.cookieA == self.cookieA && other.cookieB == self.cookieB) ||
         (other.cookieB == self.cookieA && other.cookieA == self.cookieB);
}

// If you override isEqual: you also need to override hash. The rule is that
// if two objects are equal, then their hashes must also be equal.
- (NSUInteger)hash {
  return [self.cookieA hash] ^ [self.cookieB hash];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ swap %@ with %@", [super description], self.cookieA, self.cookieB];
}

@end
