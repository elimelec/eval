/* Generated by the NeXT Project Builder 
   NOTE: Do NOT change this file -- Project Builder maintains it.
*/

#import "Eval.h"

void main(int argc, char *argv[]) {

    [Eval new];
    if ([NXApp loadNibSection:"Eval.nib" owner:NXApp withNames:NO])
	    [NXApp run];
	    
    [NXApp free];
    exit(0);
}
