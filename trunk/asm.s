
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
  cmpb al,#'	'                       |Also skip tabs
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
  cmpb al,#'	'                       |This is true for tabs too
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
