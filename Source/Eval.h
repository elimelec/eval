#import <appkit/Application.h>


@interface Eval: Application
{ id transcriptWindow ;
  id  splitView ;
  id  transcriptText ;
  id  transcriptGraphics ;
  id  textScrollView ;
  id  graphicsScrollView ;
  // pref thingies
  id  fontName ;
  id  fontSize ;
  id  graphicsSize ;
  id  compilerSwitches ;
  id  libBrowser ;
  id  libList ;
}

+ clearGraphics ;
+ clearText ;
+ printf: (char *) format, ... ;
+ ps: (char *) format, ... ;
+ startPS ;
+ stopPS ;
- appDidInit: sender ;
- appendFileToTranscript: (char *) fileName ;
- (int)browser:sender fillMatrix:matrix inColumn:(int)column ;
- browser:sender loadCell:cell atRow:(int)row inColumn:(int)column ;
- clearTranscriptGraphics: sender ;
- clearTranscriptText: sender ;
- evalObjC:(id) pboard userData: (const char *) ud error: (char **) msg ;
- evalPs: (id) pboard userData: (const char *) uBuf error: (char **) msg ;
- setDefaults: sender ;
- setGraphicsScrollView: sender ;
- setTextScrollView: sender ;
- setSplitView: anObject ;
- setUp ;
- showTranscript: sender ;
- showTranscript: (id) pboard userData: (const char *) uBuf error: (char **) msg ;
- terminate: sender ;
- windowDidResize: sender ;

@end