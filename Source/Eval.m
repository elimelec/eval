#import "Eval.h"
#import "GraphicsView.h"
#import "CString.h"
#import <appkit/Text.h>
#import <appkit/ScrollView.h>
#import <appkit/Listener.h>
#import <appkit/Pasteboard.h>
#import <appkit/NXSplitView.h>
#import <appkit/NXBrowser.h>
#import <appkit/NXBrowserCell.h>
#import <appkit/Matrix.h>
#import <appkit/OpenPanel.h>
#import <appkit/Font.h>
#import <appkit/Pasteboard.h>
#import <defaults/defaults.h>
#import <objc/List.h>
#import <objc/objc-load.h>
#import <objc/error.h>
#import <streams/streams.h>
#import <sys/stat.h>
#import <sys/stat.h>
#import <libc.h>
#import <ctype.h>
#import <dpsclient/psops.h>
#import <dpsclient/dpsclient.h>
#import <streams/streams.h>

id text, graphics ;

static NXDefaultsVector evalDefaults = 
{ {"NXFont","Ohlfs"},
  {"NXFontSize","11.0"},
  {"Frame","100.0 100.0 300.0 300.0"},
  {"GraphicsSize","400.0 400.0"},
  {"CompilerSwitches",""},
  {"Libraries","/lib/libsys_s.a /usr/lib/libNeXT_s.a"},
  {NULL} 
} ;

// archive (library) extension 
const char *libTypes[] = 
{ "a",
  NULL 
} ;

@implementation Eval: Application
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
{ return [graphics clear] ;
}

+ clearText ;
{ return [text setText: ""] ;
}

+ printf: (char *) format, ... ;
{ // format (as in printf) and print to the transcript
  NXStream *aStream ;
  char *textBuf ;
  int textLen, maxLen ;
  va_list argList ;
  aStream = NXOpenMemory(NULL, 0, NX_READWRITE) ;
  va_start(argList, format) ;
  NXVPrintf(aStream, format, argList) ;
  NXGetMemoryBuffer(aStream, &textBuf, &textLen, &maxLen);
  textLen = [text textLength] ;
  [text setSel: textLen :textLen] ;
  [text replaceSel: textBuf] ;
  NXCloseMemory(aStream,NX_TRUNCATEBUFFER) ;
  [[text window] orderFront: self] ;
  return self ;
}

+ ps: (char *) format, ... ;
{ // format (as in printf).
  // Image's postscript to the graphics view
  char *errorBuffer, *dataBuffer;
  va_list argList ;
  int textLen, maxLen ;
  NXStream  *errorStream, *dataStream ;
  
  [[graphics image] lockFocus] ;
  // save contents of PostScript VM 
  DPSPrintf(DPSGetCurrentContext(), " ");
  PSuserdict();
  DPSPrintf(DPSGetCurrentContext(), "/saveToken ");
  PSsave();
  PSput();

  NX_DURING
       dataStream = NXOpenMemory(NULL, 0, NX_READWRITE) ;
       va_start(argList, format) ;
       NXVPrintf(dataStream, format, argList) ;
       NXGetMemoryBuffer(dataStream, &dataBuffer, 
         &textLen, &maxLen);
       DPSPrintf(DPSGetCurrentContext(), dataBuffer);
       NXPing() ;
       NXCloseMemory(dataStream,NX_TRUNCATEBUFFER) ;
  NX_HANDLER
    switch (NXLocalHandler.code)
    { case dps_err_ps:
	    NXRunAlertPanel("Eval","Postcript errors in message\n"
		"[ps ...] : see transcript",NULL,NULL,NULL) ;
            errorStream = NXOpenMemory(NULL,0,NX_WRITEONLY);
            DPSPrintErrorToStream(errorStream, (DPSBinObjSeq)
                                    (NXLocalHandler.data2));
	    NXPrintf(errorStream,"\n") ;
            NXFlush(errorStream);
            NXGetMemoryBuffer(errorStream, &errorBuffer,
                               &textLen, &maxLen);
            [Eval printf: "%s\n", errorBuffer] ;
            NXCloseMemory (errorStream, NX_FREEBUFFER);
            break;
        default:
            NX_RERAISE();
    }
  NX_ENDHANDLER
  // restore contents of PostScript VM 
  DPSPrintf(DPSGetCurrentContext(), " ");
  PSuserdict();
  DPSPrintf(DPSGetCurrentContext(), "/saveToken ");
  PSget();
  PSrestore();
  [[graphics image] unlockFocus] ;
  [graphics display] ;
  [[graphics window] orderFront: self] ;
  return self ;
}

+ startPS ;
{ // lock focus on graphics image
  [[graphics image] lockFocus] ;
  return self ;
}

+ stopPS ;
{ // unlock focus on graphics image ; display
  // the graphics
  [[graphics image] unlockFocus] ;
  [graphics display] ;
  [[graphics window] orderFront: self] ;
  return self ;
}

- appDidInit: sender ;
{  // set myself as the services delegate
   [[self appListener] setServicesDelegate: self] ;
   return self ;
}

- appendFileToTranscript: (char *) fileName ;
{ // append the text of the indicated file to the transcript
  char *aStr ;
  struct stat statBuf ;
  int fd ;
  if(!(fd = open(fileName,O_RDONLY)))
  { NXRunAlertPanel("Eval","Cannot open: %c",NULL,NULL,NULL,fileName) ;
    return self ;
  }
  fstat(fd,&statBuf) ;
  aStr = malloc(statBuf.st_size + 1) ;
  read(fd,aStr,statBuf.st_size) ;
  aStr[statBuf.st_size] = '\0' ;
  [Eval printf: aStr] ;
  close(fd) ;
  free(aStr) ;
  return self ;
}

- (int)browser:sender fillMatrix:matrix inColumn:(int)column ;
{ // delegate method for browser object 
  return [libList count] ;
}

- browser:sender loadCell:cell atRow:(int)row inColumn:(int)column ;
{   [cell setStringValue: [[libList objectAt: row] cString]] ;
    [cell setLeaf: YES] ;
   return self ;
}

- clearTranscriptGraphics: sender ;
{ return [Eval clearGraphics] ;
}

- clearTranscriptText: sender ;
{ return [Eval clearText] ;
}

- evalObjC:(id) pboard userData: (const char *) uBuf error: (char **) msg ;
{ // compile and run the selection
  char *text, aStr[128] ;
  const char *const *types ;
  char tmpFile[20] = "EvalXXXXXX" ;
  NXStream *aStream ;
  FILE *fp ;
  int i, textLen, maxLen ;
  BOOL found = NO ;
  // fetch the data from pasteboard
  types = [pboard types] ;
  for(i = 0 ; types[i]; i++)
  { if(!strcmp(types[i], NXAsciiPboardType))
    { found = YES ;
      break ;
    }
  }
  if(!found) // no ascii found...
    return self ;
  [pboard readType:NXAsciiPboardType data:&text length:&textLen];
  if(!text || !textLen) // nothing there...
    return self ;
  { // block down to dynamically allocate textBuf 
    char textBuf[textLen+1] ;
    char *header, *body, *cursor ;
    int moduleKnt ;
    // don't know if text is null terminated
    textBuf[textLen] = '\0' ;
    // copy the message so we can sever it in two
    strncpy(textBuf,text,textLen) ;
    // find out if we have any header
    header = body = textBuf ;
    // move header pointer to start of header
    while(isspace(*header++)) ;  // scan past any initial whiteSpace
    if(*header == '#') // then we have a header
    { // move body pointer to start of body
      body = header ;
      while(strncmp(body++,"\n\n", 2)) // "empty" line is end of header  
      { if(*body == '\0') // then header ends without a body
         { NXRunAlertPanel("Eval", "No body to evaluate.\n",
               NULL,NULL,NULL) ;
           return self ;
         }
      }
      *body++ = '\0' ; // make body point 1 char beyond end of header,
                       // then sever textBuf into 2 strings (header and body) ;    
    }
    else
      header = "" ;   // no header at all

    // The string tmpFile is both the name of the class we will create
    // and the name of the file, within /tmp,  it will live in...
    mktemp(tmpFile) ;
    sprintf(aStr,"/tmp/%s.m",tmpFile) ;
    fp = fopen(aStr,"w+") ;
    fprintf(fp,
   	"%s\n"
   	"#import <objc/Object.h>\n"
	"@interface Eval: Object\n"
        "+ clearGraphics ;\n"
        "+ clearText ;\n"
	"+ printf: (char *) format, ... ;\n"
	"+ ps: (char *) format, ... ;\n"
        "+ startPS ;\n"
        "+ stopPS ;\n"
	"@end\n"
   	"@interface %s: Object\n"
   	"+(void) doit ;\n"
   	"@end\n\n"
   	"@implementation %s\n"
   	"+ (void) doit\n"
   	"{\n"
   	"#line 1\n"
  	 "%s\n"
   	"}\n"
   	"@end",
    header, tmpFile, tmpFile, body) ;
    fflush(fp) ;
    fclose(fp) ;
  
    // compile the class defined in this file
    sprintf(aStr, "cc -c -o %s /tmp/%s.o /tmp/%s.m 2> /tmp/%s.cc_errors",
      NXGetDefaultValue([NXApp appName],"CompilerSwitches"),
      tmpFile, tmpFile, tmpFile) ;      
    if(system(aStr)) // non-zero exit status == must report the errors
    { sprintf(aStr,"/tmp/%s.cc_errors",tmpFile) ;
      [self appendFileToTranscript: aStr] ;
      unlink(aStr) ;
      NXRunAlertPanel("Eval","Compilation errors: see Transcript Window\n",
           NULL,NULL,NULL) ;
      sprintf(aStr,"/tmp/%s.m", tmpFile) ; unlink(aStr) ;
      sprintf(aStr,"/tmp/%s.o",tmpFile) ; unlink(aStr) ;
      return self ;
    } 
    // dynamically link the class
    moduleKnt = [libList count] ;
    { // block down to dynamically alloc moduleNames
      char *moduleNames[moduleKnt + 2] ;
      aStream = NXOpenMemory(NULL, 0, NX_READWRITE) ;
      sprintf(aStr,"/tmp/%s.o",tmpFile) ;
      moduleNames[0] = aStr ;
      for(i = 1 ; i <= moduleKnt ; i++)
        moduleNames[i] = (char *)[[libList objectAt: i] cString] ;
      moduleNames[i] = NULL ;
      if(objc_loadModules(moduleNames, aStream, NULL, NULL, NULL))
      { // load failed...
        NXPutc(aStream,'\0') ; 
        NXGetMemoryBuffer(aStream, &cursor, &textLen, &maxLen);
        [Eval printf: cursor];
        NXRunAlertPanel("Eval","Load failed, see transcript\nfor details",
            NULL,NULL,NULL) ;
      }
      else 
      { // load succeeded...execute the method, at last!
         objc_msgSend(objc_getClass(tmpFile), sel_getUid("doit")) ;
        // now remove the module
        objc_unloadModules(aStream, NULL) ;
      }
    }
    NXCloseMemory(aStream,NX_TRUNCATEBUFFER) ;
    sprintf(aStr,"/tmp/%s.m",tmpFile) ; unlink(aStr) ;
    sprintf(aStr,"/tmp/%s.o",tmpFile) ; unlink(aStr) ;
    sprintf(aStr,"/tmp/%s.cc_errors",tmpFile)  ;  unlink(aStr) ;
    return self ;
  }
}

- evalPs: (id) pboard userData: (const char *) uBuf error: (char **) msg ;
{ // evaluate postscript from pasteboard
  // fetch the data from pasteboard
  const char *const *types ;
  char *text ;
  int textLen, i ;
  BOOL found = NO ;
  types = [pboard types] ;
  for(i = 0 ; types[i]; i++)
  { if(!strcmp(types[i], NXAsciiPboardType))
    { found = YES ;
      break ;
    }
  }
  if(!found) // no ascii found...
    return self ;
  [pboard readType:NXAsciiPboardType data:&text length:&textLen];
  if(!text || !textLen)
    return self ;
  [Eval ps: text] ;
  return self ;
}


- libAdd: sender ;
{ // add a library file's name to the list
  // of libraries to be searched
  id openPanel ;
  char **theList, buf[256] ;

  openPanel = [OpenPanel new] ;
  if([openPanel runModalForTypes: libTypes])
  { theList = (char **) [openPanel filenames] ;
    { sprintf(buf,"%s/%s",[openPanel directory],
        *theList++) ;
      [libList addObject: [CString new:buf]] ;
    }
    [libBrowser loadColumnZero] ;
    [self setDefaults: self] ;
  }  
  return self ;   
}

- libList ;
{ return libList ;
}

- libRemove: sender ;
{ // remove a library file's name to the list
  // of libraries to be searched
  int theRow ;
  theRow = [[libBrowser matrixInColumn: 0] selectedRow] ;
  if(theRow >= 0)
  { [[libList removeObjectAt: theRow] free] ;
    [libBrowser loadColumnZero] ;
    [self setDefaults: self] ;
  }
  return self ;
}

- setDefaults: sender ;
{ // write info from defaults panel to defaults
  // database and to objects as needed
  int i, knt ;
  char frameString[256], libString[2048] ;
  NXRect aFrame, bFrame ;

  NXDefaultsVector theDefaults =
  { {"NXFont",NULL},
    {"NXFontSize",NULL},
    {"Frame",NULL},
    {"GraphicsSize",NULL},
    {"Libraries",NULL},
    {"CompilerSwitches",NULL},
    {NULL}
  } ;
  theDefaults[0].value = (char *) [fontName stringValue] ;
  theDefaults[1].value = (char *) [fontSize stringValue] ;
  // set the frame preference
  [transcriptWindow getFrame: &aFrame] ; 
  [[transcriptWindow contentView] getFrame: &bFrame] ;
  // Note: window's getFrame method returns the size of the
  // window, whereas its sizeTo:: method sets the size of
  // its contentView.  Its really the contentView we want to save
  aFrame.size = bFrame.size ;
  sprintf(frameString,"%f %f %f %f\n",
   aFrame.origin.x,aFrame.origin.y,
   aFrame.size.width,aFrame.size.height) ;
  theDefaults[2].value = frameString ;
  // set the graphicsSize preference
  theDefaults[3].value = (char *) [graphicsSize stringValue] ;
  // set the Libraries preference
  knt = [libList count] ;
  libString[0] = '\0' ;
  for(i = 0 ; i < knt ; i++)
  { strcat(libString,[[libList objectAt: i] cString]) ;
    strcat(libString," ") ;
  }
  theDefaults[4].value = libString ;
  // set the compiler options
  theDefaults[5].value = (char *) [compilerSwitches stringValue] ;
  NXWriteDefaults([NXApp appName], theDefaults) ; 
  return self ;
}


- setGraphicsScrollView: sender ;
{ // stash the docView in both our ivasr, transcriptGraphics,
  // and the global var graphics.
  transcriptGraphics = graphics = [sender docView] ;
  graphicsScrollView = sender ;
  return [self setUp] ;
}

- setGraphicsSize: sender ;
{ graphicsSize = sender ;
  return [self setUp] ;
}

- setSplitView: anObject ;
{ // sets the splitview and attach its subpanels
  splitView = anObject ;
  return [self setUp] ;
}


- setTextScrollView: sender ;
{ // stash the docView in both our ivar, transcriptText,
  // and the global var transcript.
  transcriptText = text = [sender docView] ;
  textScrollView = sender ;
  return [self setUp] ;
}



- setUp ;
{ // if all my sockets have been filled, 
  // do some setup work...
  if(splitView && textScrollView && graphicsScrollView && graphicsSize)
  { char aString[512] ;
    const char *theAppName ;
    const char *libraries ;
    NXRect aRect ;
    int i = 0, rval ;

    // put views into splitview
    [splitView addSubview:
    [graphicsScrollView removeFromSuperview]] ;
    [splitView addSubview:
    [textScrollView removeFromSuperview]] ;
    // set up the defaults
    theAppName = [NXApp appName] ;
    // setup the defaults
    NXRegisterDefaults(theAppName, evalDefaults) ;
    // copy info from defaults vector to UI objects
    [fontName setStringValue: NXGetDefaultValue(theAppName,"NXFont")] ;
    [fontSize setStringValue: NXGetDefaultValue(theAppName,"NXFontSize")] ;
    [graphicsSize setStringValue: NXGetDefaultValue(theAppName,"GraphicsSize")] ;
    // init the libList, display in browser 
    libList = [[List alloc] init] ;
    libraries = NXGetDefaultValue(theAppName,"Libraries") ;
    rval = sscanf(libraries,"%s",aString) ;
    while(rval == 1)
    { [libList addObject: [CString new: aString]] ;
      while(libraries[i] &&
       !isspace(libraries[i++])) ; // find next library
      rval = sscanf(&libraries[i],"%s",aString) ;
    }
    [libBrowser loadColumnZero] ;
    // display the compiler options
    [compilerSwitches setStringValue: 
           NXGetDefaultValue(theAppName,"CompilerSwitches")] ;
    // now "apply" the defaults
    [transcriptText setFont:
      [Font newFont:NXGetDefaultValue(theAppName,"NXFont")
        size:atof(NXGetDefaultValue(theAppName,"NXFontSize"))]] ;
    sscanf(NXGetDefaultValue(theAppName,"Frame"),
      "%f %f %f %f", &aRect.origin.x, &aRect.origin.y,
      &aRect.size.width, &aRect.size.height) ;
    [transcriptWindow sizeWindow: aRect.size.width :aRect.size.height] ;
    [transcriptWindow moveTo:aRect.origin.x :aRect.origin.y] ;
    // setup the graphics window
    [graphics setUp] ;
  }
  return self ;
}

- showTranscript: sender ;
{ [transcriptWindow orderFront: self] ;
  return self ;
}

- showTranscript: (id) pboard userData: (const char *) uBuf error: (char **) msg ;
{ [transcriptWindow orderFront: self] ;
  return self ;
}

- terminate: sender ;
{ // make sure defaults are up-to-date
  [self setDefaults: self] ;
  return [super terminate: self] ;
}

- windowDidResize: sender ;
{ return [self setDefaults: self] ;
}

@end