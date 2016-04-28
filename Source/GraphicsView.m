
#import "GraphicsView.h"
#import <appkit/NXImage.h>
#import <defaults/defaults.h>
#import <appkit/Application.h>

@implementation GraphicsView

- clear ;
{ [image lockFocus] ;
  NXEraseRect(&bounds) ;
  [image unlockFocus] ;
  [self display] ;
  return self ;
}

- drawSelf: (NXRect *) aRect :(int) count ;
{ // draw my cached image to the screen
  [image composite:   NX_SOVER 
          fromRect:  aRect  
          toPoint:  &aRect->origin ] ;
   return self ;
}

- image ;
{ return image ;
}

- setUp ;
{ // set up an NXImage object to cache drawing
  float width, height;
  const char *defaultSize ;
  defaultSize = NXGetDefaultValue(
       [NXApp appName],"GraphicsSize") ;
  sscanf(defaultSize,
    "%f %f", &width, &height) ;
  [self sizeTo: width :height] ;
  image = [[NXImage  alloc] initSize: &frame.size] ;
  [self clear] ;
  return self ;
}


@end
