#import <objc/Object.h>
@interface CString: Object
{ char *string ;
}
+ new: (char *) aString ;
+ (int) bestLen: (char *) aString ;
- (const char *) cString ;
- free ;
@end
