//
//  _UIKeyboardCache.h
<<<<<<< Updated upstream
//  Clear Cache @p0s3id0n
//
//  Created by @p0s3id0n on 6/4/2026.
=======
//  @p0s3id0n
//
//  Created by @p0s3id0n on 14/4/2026.
>>>>>>> Stashed changes
//

#ifndef _UIKeyboardCache_h
#define _UIKeyboardCache_h

#import <Foundation/Foundation.h>

@interface UIKeyboardCache : NSObject
+ (instancetype)sharedInstance;
- (void)purge;
@end

@interface _UIKeyboardCache : NSObject
+ (void)purge;
@end

#endif /* _UIKeyboardCache_h */
