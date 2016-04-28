#import "CString.h"
#import <strings.h>
#import <stdlib.h>

// here are the "good" malloc lengths.  Anything larger than
// 4088 is best is a multiple of 8192
int goodLens[] = {16, 32, 64, 128, 176,
     252, 340, 508, 680, 1020, 1360, 2044, 2724, 4088} ;

@implementation CString: Object
{ char *string ;
}


+ new: (char *) aString ;
{ int i,len ;
  self = [[self alloc] init] ;
  // compute best malloc length
  len = strlen(aString) ;
  if(len <= 4088)
  { i = 0 ;
    while(goodLens[i] < len)
	i++ ;
    string = (char *) malloc(goodLens[i]) ;
  }
  else
  { int theLen ;
    i = 1 ;
    while((theLen = (i * 8192)) < len)
      i++ ;
    string = (char *) malloc(theLen) ;
  }
  strcpy(string,aString) ;
  return self ;
}

+ (int) bestLen: (char *) aString ;
{ // return the "best" malloc size for aString
  int len, theLen, i ;
  len = strlen(aString) ;
  if(len <= 4088)
  { i = 0 ;
    while(goodLens[i] < len)
	i++ ;
    return goodLens[i] ;
  }
  else
  { i = 1 ;
    while((theLen = (i * 8192)) < len)
      i++ ;
    return theLen ;
  }
}

- free ;
{ free(string) ;
  return [super free] ;
}

- (const char *) cString ;
{ // returns the "address" of the string
  return (const char *) string ;
}

@end
 