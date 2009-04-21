|Lister - print the symbol table of the assembler from the list file.
| Version 1.6
| 1. Accomodated undefined symbols in the symbol table.
| 2. Recognizes the new flag in symtab.i
| 3. Generates 'undef' for such symbols. (still gives a line no and a 
|    file name though) perhaps that should be prevented!
|
| Version 1.5
| 1. Accomodate xref at the beginning of file
| 2. Made functions modular - adjusting functions
| 3. Generate Symbol wise Cross References
| 4. Added commandline options - default is to just display symbol table
|    options include 
|    -x to generate references and counts
|    -z to list only unreferenced symbols
|
|Usage
|       lister filename
|
|No default extension is assumed, the file, as specified should exist
|
CR              = 13

FileNameSize    = 13            |these include one more space
LineNumberSize  =  6
SymbolSize      = 30

.include dos.i
.include symtab.i

  call OpenInputFile
  call AnalyzeFile

ExitToDos:
  call CloseInputFile
  movb ah,#TerminateFunction
  int  #DosInterrupt

|Get the filename from the command line
|Display Message about file name
|Open the file,
|
OpenInputFile:
  call GetInputFileName
  call DisplayMessage
  .asciz "Analyzing File: '"
  mov  bx,dx
  call DisplayOtherMessage
  call DisplayMessage
  .asciz "'"
  call PutCarriageReturn

|Open the input file for reading
  movb ah,#OpenFileFunction
  movb al,#ReadOnly
  int  #DosInterrupt
  jc   OpenFileError
  mov  InputFileHandle,ax
  ret

OpenFileError:
  mov  bx,#FileOpenErrorMessage
  call Panic

AnalyzeFile:
  call LoadTables
  call AdjustTables
  call DisplayTables
  ret

DisplayTables:
  call DisplaySymbolTable
  ret

DisplaySymbolTable:
  mov  si,ListSymbolTableStart
ListNextSymbol:
  cmp  si,ListSymbolTableEnd
  jz   DisplayedSymbolTable
  test Attributes[si],#IsFake
  jnz  AFakeSymbol
  cmpb Option,#'z'
  jz   DontDisplayEntry
  call DisplaySymbolEntry
DontDisplayEntry:
  cmpb Option,#0
  jz  DontDisplayXref
  call DisplaySymbolXref
DontDisplayXref:
AFakeSymbol:
  add  si,#size_syment
  jmps  ListNextSymbol
DisplayedSymbolTable:
  ret

DisplayPaddedSymbol:
  movb al,#SymbolSize
  jmps OtherPaddedDisplay
DisplayPaddedFileName:
  movb al,#FileNameSize         |Chars for the filename
OtherPaddedDisplay:
  call DisplayOtherMessage
PaddedDisplayEnd:
  call PadWithSpaces
  ret

DisplayPaddedLineNumber:
  call DisplayAXInDecimal
  movb al,#LineNumberSize       |Chars for the line number
  jmps PaddedDisplayEnd

DisplaySymbolEntry:
  mov  bx,si
  mov  bx,[bx]
  inc  bx
  call DisplayPaddedSymbol
  mov  bx,DefFileNameOffset[si]
  call DisplayPaddedFileName
  mov  ax,DefLineNumber[si]
  call DisplayPaddedLineNumber
  test Attributes[si],#NeverDefined
  jz   WasActuallyDefined
  call DisplayMessage
  .asciz "Undef"
  jmps ListTypeDone
WasActuallyDefined:
  test Attributes[si],#IsEquate
  jnz  ListNotLabel
  call DisplayMessage
  .asciz "Label"
  jmps ListTypeDone
ListNotLabel:
  call DisplayMessage
  .asciz "Equate"
  jmps ListTypeDone
ListTypeDone:
  movb al,#7                    |Chars for description
  call PadWithSpaces

  mov  ax,Value[si]
  call DisplayRegister
  call DisplayMessage
  .asciz  " "
  call DisplayPaddedLineNumber
  call PutCarriageReturn
  ret

DisplaySymbolXref:
  push si
  mov  di,si
  mov  References,#0
  mov  si,XrefTableStart
CheckNextXref:
  cmp  si,XrefTableEnd
  jz   DisplayedSymbolXrefs
  cmp  [si],di
  jnz  NotThisSymbol
  cmpb Option,#'x'
  jnz  DontDisplayFoundXref
  call DisplayXrefFound
DontDisplayFoundXref:
  inc  References
NotThisSymbol:
  add  si,#6
  jmps CheckNextXref
DisplayedSymbolXrefs:
  cmpb Option,#'x'
  jnz  DontDisplayReferenceCount
  call DisplayReferenceCount
DontDisplayReferenceCount:
  pop  si
  cmpb Option,#'z'
  jnz  DontDisplayZeroRef
  call DisplayZeroReferenceSymbol       |On for listing unreferreds
DontDisplayZeroRef:
  ret

DisplayZeroReferenceSymbol:
  cmp  References,#0
  jnz  NonZeroReferenceCount
  xchg si,di
  call DisplaySymbolEntry
  xchg si,di
NonZeroReferenceCount:
  ret

DisplayReferenceCount:
  call DisplayMessage
  .asciz "  "
  mov  ax,References
  call DisplayPaddedLineNumber
  call DisplayMessage
  .asciz " references found"
  call PutCarriageReturn
  ret

DisplayXrefFound:
  call DisplayMessage
  .asciz "  "
  mov  bx,2[si]
  call DisplayPaddedFileName
  mov  ax,4[si]
  call DisplayPaddedLineNumber
  call PutCarriageReturn
  ret

LoadTables:
  call LoadXrefTable
  call LoadSymbolTable
  call LoadStringTable
  ret

LoadXrefTable:
  mov  dx,#EndOfCode
  mov  XrefTableStart,dx
MoreXrefEntries:
  call ReadWord
  mov  si,dx
  lodsw
  or   ax,ax
  jz   EndOfXrefTable
  inc  dx
  inc  dx
  call ReadWord
  inc  dx
  inc  dx
  call ReadWord
  inc  dx
  inc  dx
  jmps MoreXrefEntries
EndOfXrefTable:
  mov  XrefTableEnd,dx
  ret

LoadSymbolTable:
  mov  dx,#AsmSymbolTableStart
  call ReadWord
  mov  dx,#AsmSymbolTableEnd
  call ReadWord
  mov  dx,XrefTableEnd
  mov  ListSymbolTableStart,dx
  mov  cx,AsmSymbolTableEnd
  sub  cx,AsmSymbolTableStart
  jc   CorruptListFile
  call Read
  add  cx,ListSymbolTableStart
  jc   CorruptListFile
  mov  ListSymbolTableEnd,cx
  ret

LoadStringTable:
  mov  dx,#AsmStringTableStart
  call ReadWord
  mov  dx,#AsmStringTableEnd
  call ReadWord
  mov  dx,ListSymbolTableEnd
  mov  ListStringTableStart,dx
  mov  cx,AsmStringTableEnd
  sub  cx,AsmStringTableStart
  jc   CorruptListFile
  call Read
  add  cx,ListStringTableStart
  jc   CorruptListFile
  mov  ListStringTableEnd,cx
  ret

CorruptListFile:
  mov  bx,#CorruptListFileMessage
  call Panic

AdjustTables:
  call AdjustSymbolTable
  call AdjustXrefTable
  ret

AdjustSymbolTable:
  mov  si,ListSymbolTableStart
  mov  cx,ListStringTableStart          |find the diff in the positions
  sub  cx,AsmStringTableStart
MoreSymbolEntriesToAdjust:
  cmp  si,ListSymbolTableEnd
  jz   AdjustedSymbolTable
  mov  bx,#idname
  call AdjustName
  mov  bx,#DefFileNameOffset
  call AdjustName
  add  si,#size_syment
  jmps MoreSymbolEntriesToAdjust
AdjustedSymbolTable:
  ret

AdjustXrefTable:
  mov  si,XrefTableStart
  mov  dx,ListSymbolTableStart
  sub  dx,AsmSymbolTableStart
MoreXrefEntriesToAdjust:
  cmp  si,XrefTableEnd
  jz   AdjustedXrefTable
  mov  bx,#0
  call AdjustSymbol
  mov  bx,#2
  call AdjustName
  add  si,#6
  jmps MoreXrefEntriesToAdjust
AdjustedXrefTable:
  ret

|si pointer to symbol table entry
|cx difference between the string tables
  

AdjustName:
  mov  ax,[bx_si]
  add  ax,cx
  cmp  ax,ListStringTableStart
  jc   CorruptListFile
  cmp  ax,ListStringTableEnd
  jnc  CorruptListFile
  mov  [bx_si],ax
  ret

AdjustSymbol:
  mov  ax,[bx_si]
  add  ax,dx
  cmp  ax,ListSymbolTableStart
  jc   CorruptListFile
  cmp  ax,ListStringTableEnd
  jnc  CorruptListFile
  mov  [bx_si],ax
  ret

ReadWord:
  mov  cx,#2
Read:
  mov  bx,InputFileHandle
  movb ah,#ReadFunction
  int  #DosInterrupt
  jc   ReadError
  ret

ReadError:
  mov  bx,#ReadErrorMessage
  call Panic

CloseInputFile:
  mov  bx,InputFileHandle
  movb ah,#CloseFileFunction
  int  #DosInterrupt
  ret

|Find the name of the file from the command line and terminate it
|with a nul character. The offset of the string is returned in dx!
|If there is no file name then display usage message.
|
|Destroys:
| si : to make it point to the command line
| dx : for return
| al : for temp storage.

GetInputFileName:
  mov  si,#CommandLineStart 
SkipCommandLineSpaces:
  lodsb
  cmpb al,#' '
  jz   SkipCommandLineSpaces
  cmpb al,#9
  jz   SkipCommandLineSpaces
  cmpb al,#CR
  jz   Usage
  cmpb al,#'-'
  jz   OptionFound
  mov  dx,si
  dec  dx
MoreCharsInFileName:
  lodsb
  cmpb al,#' '
  jz   EndOfFileNameFound
  cmpb al,#9
  jz   EndOfFileNameFound
  cmpb al,#CR
  jnz  MoreCharsInFileName
EndOfFileNameFound:
  dec  si
  movb [si],#0
  ret

OptionFound:
  lodsb
  cmpb al,#'x'
  jz   ValidOption
  cmpb al,#'z'
  jnz  InvalidOption
ValidOption:
  movb Option,al
  jmp  SkipCommandLineSpaces

InvalidOption:
  mov  bx,#InvalidOptionMessage
  call Panic

|No filename on command line - display usage message and quit

Usage:
  mov  bx,#UsageMessage
  call Panic

Panic:
  call DisplayOtherMessage
  call PutCarriageReturn
  jmp  ExitToDos
  

|Messages for the lister

UsageMessage:
  .asciz  "Usage: lister [-xz] <filename>"
FileOpenErrorMessage:
  .asciz  "Error opening input file for reading"
ReadErrorMessage:
  .asciz  "Error reading input file"
CorruptListFileMessage:
  .asciz  "The List file is corrupt! Can't analyze"
InvalidOptionMessage:
  .asciz  "The valid options are only x or z"
|Data
InputFileHandle:
  .word 0
AsmSymbolTableStart:
  .word 0
AsmSymbolTableEnd:
  .word 0
AsmStringTableStart:
  .word 0
AsmStringTableEnd:
  .word 0
ListSymbolTableStart:
  .word 0
ListSymbolTableEnd:
  .word 0
ListStringTableStart:
  .word 0
ListStringTableEnd:
  .word 0
XrefTableStart:
  .word 0
XrefTableEnd:
  .word 0
References:
  .word 0
Option:
  .byte 0
.include display.s

EndOfCode:
