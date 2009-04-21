
|Fields of the entry in the offent
| are offset and changeval

size_offent = 4


MaxNumberOfSymbols = 750
MaxOffsetEntries   = 1000
MaxStringTableSize = 10000
PostFixBufferSize  = 300

SymTabStart = EndOfCode
SymTabEnd = SymTabStart + (MaxNumberOfSymbols * size_syment)

OffsetTableStart = SymTabEnd
OffsetTableEnd = OffsetTableStart + (MaxOffsetEntries * size_offent)

StringTableStart = OffsetTableEnd
StringTableEnd = StringTableStart + MaxStringTableSize

PostFixBufferStart = StringTableEnd
PostFixBufferEnd = PostFixBufferStart + PostFixBufferSize

OutputStart = PostFixBufferEnd
OutputEnd = 62535

PresentFileNameOffset:
  .word 0
OutputFileNameOffset:
  .word 0
ListFileNameOffset:
  .word 0
EmptyOffent:
  .word OffsetTableStart

LastFilledSymbol:
  .word SymTabStart
StringSpace:
  .word StringTableStart

|This procedure finds the symbol in the symbol table. The symbol is
|assumed to be in the present input word
|The offset of the start of the entry found is in di and si

FindSymbol:
  mov  si,#SymTabStart
FindSym1:
  mov  bp, si
  mov  di,#InputWord
  lodsw
  or   ax,ax
  jz   DSymbolNotFound
  mov  si,ax
  lodsb
  movb cl,al
  xorb ch,ch
  rep
  cmpsb
  jnz  NotThisDSymbol
  cmpb [di],#0
  jnz  NotThisDSymbol
  mov  si,bp
  mov  di,si
  clc
  ret

RecordXref:
  push ax
  mov  ax,si
  call WriteListWord
  mov  ax,PresentFileNameOffset
  call WriteListWord
  mov  ax,InputLineNumber
  call WriteListWord
  pop  ax
  ret

NotThisDSymbol:
  mov  si,bp
  add  si,#size_syment
  jmps FindSym1

DSymbolNotFound:
  stc
  ret

|Add a symbol into the symbol table. The identifier to be added will
|be in the InputWord. When it returns, di and si (like in the previous
|function) points to the attributes.
AddSymbol:
  mov  di,LastFilledSymbol
  cmp  di,#SymTabEnd
  jnz  NoSymTabOverflow
  mov  bx,#SymTabOverflowMessage
  call Panic
NoSymTabOverflow:
  mov  bp,di
  mov  ax,StringSpace
  mov  idname[di], ax
  mov  di,StringSpace
  mov  dx,di
  inc  di
  mov  si,#InputWord
  mov  cx,#MaxIdentifierSize - 2
MoreCharsInIdentifier:
  lodsb
  stosb
  orb  al,al
  jz   EndOfInputWord
  jcxz ReportLargeIdentifier
  loop MoreCharsInIdentifier
ReportLargeIdentifier:
  mov  bx,#LargeIdentMessage
  call PanicRecover
EndOfInputWord:
  call CheckStringTableOverflow
  mov  StringSpace,di
  neg  cx
  add  cx,#MaxIdentifierSize - 2
  mov  di,dx
  movb [di],cl
  mov  di,bp
  mov  ax,PresentFileNameOffset
  mov  DefFileNameOffset[di],ax
  mov  ax,InputLineNumber
  mov  DefLineNumber[di],ax
  mov  size_syment[di],#0
  mov  LastFilledSymbol,di
  add  LastFilledSymbol,#size_syment
  mov  si,di
  ret


|Find a Fake Symbol, if not present,add it
|
|ax has the value of the fake symbol
|
FindFakeSymbol:
  mov di,#InputWord
  push ax
  movb al,#'_'
  stosb
  pop  ax
  push ax
  call SprintRegister
  xorb al,al
  stosb
  call FindSymbol
  pop  ax
  jnc  FindFakeEnd
  push ax
  call AddSymbol
  mov  Attributes[di],#IsFake + Calculated + IsDefined + IsEquate
  pop  ax
  mov  Value[di],ax
FindFakeEnd:
  ret


|WriteListFile, writes the list file out the format of the list file is
|
|1.Symbol table start   :word   as in the assembler
|2.Symbol table end     :word   points to one byte past the true end.
|3.Symbol table         :2 - 1  bytes of data, raw symbol table
|4.String table start   :word   as in the assembler
|5.String table end     :word   points to one past the end.
|6.String table         :5 - 4  bytes of data, raw string table

WriteListFile:
  mov  ax,#0                    |Terminate the xref list in the list file
  call WriteListWord
  mov  ax,#SymTabStart
  call WriteListWord
  mov  ax,LastFilledSymbol
  call WriteListWord
  mov  cx,LastFilledSymbol
  mov  dx,#SymTabStart
  sub  cx,dx
  call WriteList
  mov  ax,#StringTableStart
  call WriteListWord
  mov  ax,StringSpace
  call WriteListWord
  mov  cx,StringSpace
  mov  dx,#StringTableStart
  sub  cx,dx
  call WriteList
  ret

ListError:
  mov  bx,#OutputFileMessage
  call Panic

DummyListWord:
  .word 0

WriteListWord:
  mov  DummyListWord,ax
  mov  dx,#DummyListWord
  mov  cx,#2
WriteList:
  movb ah,#64
  mov  bx,ListFileHandle
  int  #DosInterrupt
  jc   ListError
  ret

|Initialise the symbol table

InitSymbolTable:
  mov SymTabStart,#0
  ret


SprintRegister:
  push cx
  movb ch,#4
SprintRegisterMore:
  rol  ax
  rol  ax
  rol  ax
  rol  ax
  call SprintHexDigit
  decb ch
  jnz  SprintRegisterMore
  pop  cx
  ret

SprintHexDigit:
  push ax
  push dx
  push bx
  andb al,#15
  mov  bx,#HexDigitTable
  xlat
  stosb
  pop  bx
  pop  dx
  pop  ax
  ret

FindValue:
  mov  bx,ax
  test Attributes[bx],#Calculated
  jz   FoundNoValue
  mov  ax,Value[bx]
  clc
  ret

FoundNoValue:
  stc
  ret

NoteErrorOnDef:
  mov  ax,DefLineNumber[si]
  mov  InputLineNumber,ax
  mov  ax,DefFileNameOffset[si]
  mov  PresentFileNameOffset,ax
  ret


UndefinedError:
  mov  bx,[si]
  inc  bx
  push bx
  mov  ax,Value[si]
  call NoteErrorOnDef
  call PutErrorAndPosition
  pop  bx
  call DisplayOtherMessage
  call DisplayMessage
  .asciz   ":"
  mov  bx,#SymbolNotDefinedMessage
  call DisplayOtherMessage
  call PutCarriageReturn
  or Attributes[si],#IsDefined + Calculated + NeverDefined
  jmps FixNextSymbol

fixation:
  .byte 0

FixUnknowns:
  mov  si,#SymTabStart
  sub  si,#size_syment
  movb fixation,#0
FixNextSymbol:
  add  si,#size_syment
  cmp  [si],#0
  jz   EndedFix
  test Attributes[si],#IsDefined
  jz   UndefinedError
  test Attributes[si],#Calculated
  jnz  FixNextSymbol
  test Attributes[si],#IsFake
  jnz  JustAnotherSymbol
  push si
  mov  si,Value[si]
  call EvaluateExpression
  pop  si
  jnc  Evaluated
  jmps FixNextSymbol

JustAnotherSymbol:
  mov  bx,Value[si]
  test Attributes[bx],#Calculated
  jz   FixNextSymbol
  mov  ax,Value[bx]
Evaluated:
  movb fixation,#1
  or   Attributes[si],#Calculated
  mov  Value[si],ax
  jmps FixNextSymbol
EndedFix:
  cmpb fixation,#1
  jnz  DoneFixes
  jmp  FixUnknowns
DoneFixes:
  ret

AddOffEnt:
  push di
  mov  di,EmptyOffent                   
  stosw
  mov  ax,LocationCounter
  add  ax,bx
  stosw
  mov  EmptyOffent,di
  pop  di
  ret

JumpOutOfRange:
  mov  bx,#JumpErrorMessage
  call PanicRecover

PatchCode:
  mov  si,#OffsetTableStart
NextOffent:
  cmp  si,EmptyOffent
  jz   EndOfOffs
  lodsw
  mov  bx,ax
  lodsw
  add  ax,#OutputStart
  mov  di,ax
  mov  ax,[di]
  testb al,#2
  jnz  RelativePatch
  testb al,#1
  mov  ax,Value[bx]
  jz   bytemove
  mov  [di],ax
  jmps NextOffent
EndOfOffs:
  ret
RelativePatch:
  testb al,#1
  jz   bytepatch
  mov  ax,di
  add  ax,#2
  sub  ax,#OutputStart
  sub  ax,Value[bx]
  neg  ax
  mov  [di],ax
  jmps NextOffent
bytepatch:
  mov  ax,di
  inc  ax
  sub  ax,#OutputStart
  sub  ax,Value[bx]
  neg  ax
  rolb al
  rorb al
  adcb ah,#0
  jnz  JumpOutOfRange
  movb [di],al
  jmps NextOffent
bytemove:
  movb [di],al
  jmps NextOffent
