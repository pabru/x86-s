|Author Venkataraman I.V.
| Version 1.9   7297 bytes
| 1. Fixed a dangerous bug - forward relative jumps of (128-255) were
|    being allowed and actually coded as 0x80 to 0xFF, which worked
|    out to be backward jumps - symtab.s
|
|
| Version 1.8   7295 bytes
| 1. Stole a few bytes by defining the extensions as words in ax before 
|    storing them
|
|
| Version 1.7   7305 bytes
| 1. Added the binary operator !, which takes two byte constants and
|    makes them into a word
| 2. Fixed bugs with the ! operator (lower byte duplicated)
| 3. Fixed bugs with non-error reporting of backword jumps of more
|    than 128 bytes. (Misplaced label on too large operand)
|
|
| Version 1.6
| 1. Added a variable SavedStackPointer that keeps track of the stack
|    for each assemble file. Filled in Assemble in asm.s. Also in
|    direct.s, it is pushed and popped for include files to keep
|    stack consistency.
| 2. Added some error recovery - only one type - resync at end of line
|    Stack Pointer is restored to where it was. List file may contain
|    junk. Don't know as yet. Still aborts on severe errors. The undefined
|    error messsage in symtab.s had to be treated specially. Output file
|    is still generated.
| 3. Fixed the include error message. Instead of showing the name of 
|    the included file in the error message, It shows the name of the file
|    in which the failed include statement occured. Fixes to direct.s and
|    reorganization to OpenInputFile in asm.s
| 4. Added a never defined flag so that the assembler can continue with
|    assembly even if a symbol is not defined. Set in symtab.s
| 6. Added the not operator to the expression evaluation section - expr.s
|    For a new operator the procedure is
|    a. add the operator in IsOperator  in the right place
|    b. if the operator is unary, add it in the IsUnaryOperator too.
|    c. add the code to evaluate it in Evaluate expression
| 7. Allows byte sized values to have 0 or ff as higher byte - 
|    to accomodate the unary not, else !0x80 was not allowed as a byte
|    operand. Changes to support.s
| Version 1.5
| 1. Modified symtab.s to add a function RecordXref that puts the
|    index of symbol, filename and line no into the list file
| 2. Modified expr.s so that it calls RecordXref in the middle of
|    processing an expression - only for real variables - not
|    constants or fakes.
| 3. Modified lister to report number of references to each variable
|    and to list the references symbolwise
| 4. Removed redundant code in asm primarily Is8bitregister and
|    Is16bitRegister in support.s
| 5. Removed redundant equates and Messages - size mismatch
|
| Version 1.4
| 1. Instead of printing the symbol table onto the screen it puts
|    the symbol table onto the list file.
| 2. The list file has the symbol table proper and the string table
| 3. To make data structures common to the assembler and the lister
|    and to prevent duplication of work, two include files have been
|    created. dos.i with the equates for DOS functions and symtab.i
|    with the structures for the symbol table.
| 4. The message displaying functions have been separated out to
|    another file called display.s.
| 5. The functions in display.s (except for PutCarriageReturn and 
|    DisplayRegister) now keep track of the number of characters that
|    have been displayed.
| 6. The symbol table being dumped on the screen is disabled, only
|    the .lst file is created. ListSymbols from symtab.s was deleted.
|    and the call from asm.s
| 7. A separate program lister was added which prints out the symbol
|    table from the .lst file
| 8. display.s was putting out a LF and a CR in that order, which was
|    confusing editors - e.g. MKS  vi.
| 
|
| Version 1.3
| 1. The filenames are directly put into the string space instead of
|    present filename
|    a. One variable presentfilename is removed - save space
|    b. Changes to asm.s and direct.s (for includes)
| 2. The print stats function was removed
| 3. The output filename is accessible throughout the programs execution
| 4. The output file is deleted if an error in assembly is detected.
| 5. Can handle infinite (Promises!) path length one error message
|    removed - path too long. message.s
| 6. Opens List file too. The list file name is on the string table too.
|    added two variables - ListFileHandle and ListFileNameOffset
| 7. Doesn't print the name of the file that it is assembling any longer.
|    or the names of the output files.
| 8. Doesn't display assembly successful at the end either. - silent on
|    success.
|
| Version 1.2
| 1. Accepts char constants - in single quotes, wherever
|    constants are allowed.
| 2. Accepts hex constants - prefixed by 0x, with overflow checking.
| 3. Accepts negative byte constants  - complained earlier.
| 
|
|
| 3rd December 1991
|

PathSize = 64
BufferSize = 20
WordSize = 32
MaxIdentifierSize = 30

.include dos.i
.include symtab.i

Reg8      = 1
Reg16     = 2
SegReg    = 3
Immediate = 4
AddMode   = 5
Disp      = 6
|AddDisp   = 7                  |Isn't ever used!

CR    = 13
LF    = 10

  call GetFileName                      |Get the name of the file to be
					|assembled into PresentFilename
  call InitSymbolTable
  call AssembleOneFile
  jmp  ExitToDos                        |Get back to DOS

CloseInputFile:
  movb ah,#CloseFileFunction             |Close the input file
  mov  bx,InputFileHandle
  int  #DosInterrupt
  ret

CloseOutputFiles:
  movb ah,#CloseFileFunction
  mov  bx,OutputFileHandle
  int  #DosInterrupt
  movb ah,#CloseFileFunction
  mov  bx,ListFileHandle
  int  #DosInterrupt
  ret

GetFileName:
  mov  si,#CommandLineStart             |Get the start of the command line
  lodsb                                 |first byte is length of command line
  orb  al,al                            |If there is no command line then
  jnz  SkipCommandLineSpaces            |show the
ReportNoName:
  mov  bx,#HelpMessage                  |
  call Panic                            |help screen to the nosey user.
SkipCommandLineSpaces:                  |
  lodsb                                 |Get more chars from the command line
  cmpb al,#' '                          |Skip spaces at start of name
  jz   SkipCommandLineSpaces            |Any number of them
  cmpb al,#'    '                       |Also skip tabs
  jz   SkipCommandLineSpaces            |
  cmpb al,#CR
  jz   ReportNoName
  mov  di,StringSpace                   |Copy the name into the StringSpace
  mov  PresentFileNameOffset,di         |
  stosb                                 |done by string insts.
  mov  bx,si                            |To display of the filename.
  dec  bx                               |Actually si is pointing at one
					|past the start of the filename.
  xorb cl,cl                            |cl is whether the filename
					|given had an extension or not.
					|If there was no extension then we
					|have to put a .s after it.
					| We assume that there is
					|enough space to do such a thing
					|in the command line.
FindCommandLineCR:                      |white spaces after the name of the
  lodsb                                 |should be removed
  stosb                                 |Keep Storing the name
  cmpb al,#' '                          |it means that that was the end of
  jz   FoundFilenameEnd                   |the filename
  cmpb al,#'    '                       |This is true for tabs too
  jz   FoundFilenameEnd|                |If a '.' is found, it means that
  cmpb al,#'.'                          |an extension need not be added to
  jnz  NotTheDotInFilename              |to the filename
  incb cl                               |record the fact in cl that a dot
					|has been seen in the input name
NotTheDotInFilename:
  cmpb al,#'/'                    |reset the dot if a path separator
  jnz  NotSlashinFilename               |is found
  xorb cl,cl
NotSlashinFilename:
  cmpb al,#'\'
  jnz  NotBackSlashInFilename
  xorb cl,cl
NotBackSlashInFilename:               |We have to check whether we
  cmpb al,#CR                         |crash into the tail of the command
  jnz  FindCommandLineCR              |line. Check for carriage return
FoundFilenameEnd:                     |Here we are at the end of the name
  dec  di                             |Adjust, 'cos even the carriage retn
  orb  cl,cl                          |or white space is in. If there was
  jnz  NoNeedToPutExtension           |an extension don't put another
  mov  ax,#'s'!'.'                    |store an extension after the name
  stosw                               |'.s'
NoNeedToPutExtension:                 |Terminate the name with a zero
  movb al,#0                          |character, C and DOS style
  stosb                               |store the zero
  call CheckStringTableOverflow
  mov  StringSpace,di
  ret                                 |return to main routine.

.include symtab.s

AssembleOneFile:
  call OpenInputFile
  jc   InputFileOpenError
  call ConstructOutputFileNames
  mov  dx,OutputFileNameOffset
  call OpenOutputFile
  mov  OutputFileHandle,ax
  mov  dx,ListFileNameOffset
  call OpenOutputFile
  mov  ListFileHandle,ax
  call Assemble
  call FixUnknowns
  call PatchCode
  call WriteOutputFile
  call CloseInputFile
  call WriteListFile
  call CloseOutputFiles
  ret

InputFileOpenError:
  mov  bx,#NoInputFileMessage    |There was an error - so quit.
  call Panic

OpenInputFile:
  mov  ax,#OpenFileFunction!ReadOnly
  mov  dx,PresentFileNameOffset
  int  #DosInterrupt
  jc   CouldNotOpenFile
  mov  InputFileHandle,ax               |Preserving Carry dangerous stuff
  mov  InputLineNumber,#1
  mov  ax,#0
  mov  InputBufferReadPtr,ax            |Both Should be the same
  mov  InputBufferEndPtr,ax  
CouldNotOpenFile:
  ret


ConstructOutputFileNames:
  mov  di,PresentFileNameOffset
  movb al,#0
  mov  cx,#PathSize
  repnz
  scasb
  dec  di
  std
  mov  cx,#PathSize
  movb al,#'.'
  repnz
  scasb
  cld
  inc  di
  mov  si,PresentFileNameOffset
  mov  cx,di
  sub  cx,si
  mov  dx,cx                    |save offset for list file opening
  mov  di,StringSpace
  mov  OutputFileNameOffset,di
  rep
  movsb
  mov  ax,#'c'!'.'
  stosw
  mov  ax,#'m'!'o'
  stosw
  xorb  al,al
  stosb
  mov   si,PresentFileNameOffset
  mov   cx,dx
  mov   ListFileNameOffset,di
  rep
  movsb
  mov   ax,#'l'!'.'
  stosw
  mov   ax,#'t'!'s'
  stosw
  xorb  al,al
  stosb
  call  CheckStringTableOverflow
  mov   StringSpace,di
  ret

OpenOutputFile:
  movb ah,#60
  mov  cx,#0
  int  #DosInterrupt
  jnc  OutputFileWasOpened
  mov  bx,#OutputFileMessage
  call Panic
OutputFileWasOpened:
  ret

RemoveOutputFile:
  movb ah,#DeleteFileFunction
  mov  dx,OutputFileNameOffset
  int  #DosInterrupt
  ret

|Assemble
|The main procedure for processing a file
|On input, the variable,
| InputFileHandle - is a valid handle of an opened file.
|
|
|
Assemble:
  mov  SavedStackPointer,sp
AssembleLabelTail:
  xor  ax,ax
  mov  bp,1
  call GetEndOfLine1
  jc   AssembleEnd
Assemble1:
  call GetWord
  jc   AssembleEnd
  movb al,InputWord
  cmpb al,#'|'
  jnz  NotAComment
  call GetEndOfLine
  jc   AssembleEnd
  jmps Assemble1
NotAComment:
  mov  si,#Directives
  call MatchKeyword
  jc   NotDirective
  call [si]
  call GetEndOfLine
  jc   AssembleEnd
  jmps Assemble1
NotDirective:
  call GetInstruction
  jc   EquateOrLabel
  call GetEndOfLine
  jc   AssembleEnd
  jmps Assemble1
EquateOrLabel:
  call DefineNewSymbol
  or   bx,#IsEquate
  jz   AssembleLabelTail
  call GetEndOfLine
  jc   AssembleEnd
  jmps Assemble1
AssembleEnd:
  ret


NotImplemented:
  ret

CheckStringTableOverflow:
  cmp  di,#StringTableEnd
  jc   NoStringOverflow
  mov  bx,#StrTblOverflowMessage
  call Panic
NoStringOverflow:
  ret


.include input.s
.include symbols.s
.include message.s
.include display.s
.include support.s
.include equ.s
.include expr.s
.include direct.s
.include output.s

EndOfCode:
