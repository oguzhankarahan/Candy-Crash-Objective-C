//
//  RWTCookie.h
//  CookieCrunch
//
//  Created by oguzhan.colak on 05-11-14.
//  Copyright (c) 2014 Oguzhan COLAK All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

static const NSUInteger NumCookieTypes = 6;

@interface RWTCookie : NSObject

@property (assign, nonatomic) NSInteger column;
@property (assign, nonatomic) NSInteger row;
@property (assign, nonatomic) NSUInteger cookieType;  // 1 - 6
@property (strong, nonatomic) SKSpriteNode *sprite;

- (NSString *)spriteName;
- (NSString *)highlightedSpriteName;

@end
