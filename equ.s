NotEquateDefinition:
  mov  bx,#InvalidInstrMessage
  call PanicRecover

DefineNewSymbol:
  call FindSymbol
  jc   NotaRedefinition
  mov  ax,PresentFileNameOffset
  mov  DefFileNameOffset[di],ax
  mov  ax,InputLineNumber
  mov  DefLineNumber[di],ax
  test Attributes[di],#IsDefined
  jz   DefiningNow
  mov  bx, #RedefinitionMessage
  call PanicRecover
NotaRedefinition:
  call AddSymbol
DefiningNow:
  push di
  call IgnoreSpaces
  call GetChar
  cmpb  al,#':'
  jnz  NotLabelDefinition
  mov  ax,LocationCounter
  mov  bx,#Calculated
  jmps ValidSymbolDefinition
NotLabelDefinition:
  cmpb  al,#'='
  jnz  NotEquateDefinition
  call GetToken
  call ProcessExpression
ValidSymbolDefinition:
  pop  di
  or   bx,#IsDefined
  mov  Attributes[di],bx
  mov  Value[di],ax
  ret

ProcessExpression:		|maintain flags upto compile
  mov  di,#PostFixBufferStart
  push LastFilledSymbol
  push StringSpace
  call CompileExpression
  mov  si,#PostFixBufferStart
  call EvaluateExpression
  mov  bx,#9				|IsEquate or Calculated
  jc   NotEvaluatable			|reclaim strings and entries

  pop  StringSpace		|Evaluatable
  pop  LastFilledSymbol
  mov  di,LastFilledSymbol
  mov  [di],#0
  ret

NotEvaluatable:
  pop  cx  |The old StringSpace can go to the moon, new fake symbols added
  pop  cx  |and the filledsymbol
  and  bx, #NotCalculated
  call IsSimpleExpression
  jnz  NotSimpleExpression
  or   bx, #IsFake	|not calculated and fake
|  call DisplayRegister
|  call DisplayMessage
|  db   ':Found S ',0
|  push ax
|  mov  ax,LastFilledSymbol
|  call DisplayRegister
|  pop  ax
|  call DisplayMessage
|  db   0dh,0ah,0
  ret
  
NotSimpleExpression:	|Has to be stored on the string space
  mov  ax, StringSpace
  push ax
  call TransferExprToSpace
  pop  ax
  mov  StringSpace,di
  ret

DecimalConvertNumber:
  mov  si,#InputWord
  cmpb [si],#'''
  jz   CharLiteralFound
  cmpb 1[si],#'x'		|Hex Number
  jz   HexNumberFound
  xor  ax,ax
  mov  bx,#10
  xor  dx,dx
DecConvNumber1:
  mov cx,ax
  xorb ah,ah
  lodsb
  call IsNumAL
  jnc  FinishedDecimalConvert
  sub  ax,#48
  xchg cx,ax
  mul  bx
  or   dx,dx
  jnz  ReportLargeDecConst
  add  ax,cx
  jc   ReportLargeDecConst
  jmps DecConvNumber1
FinishedDecimalConvert:
  mov  ax,cx
  ret
HexNumberFound:
  inc si			|get past the 0x
  inc si
  xor ax,ax
HexNumberFound1:
  mov cx,ax
  lodsb
  call IsHexAL
  jnc  FinishedDecimalConvert
  subb al,#'0'
  cmpb al,#10
  jc   ZeroToNine
  subb al,#7
ZeroToNine:
  shl  cx
  jc   ReportLargeDecConst
  shl  cx
  jc   ReportLargeDecConst
  shl  cx
  jc   ReportLargeDecConst
  shl  cx
  jc   ReportLargeDecConst
  xorb ah,ah
  or   ax,cx
  jmps HexNumberFound1

ReportLargeDecConst:
  mov  bx, #LargeConstMessage
  call PanicRecover

CharLiteralFound:
  movb al,1[si]
  movb ah,#0
  ret

TransferExprToSpace:
  mov  di, StringSpace
  mov  si, #PostFixBufferStart
ExprTransferNext:
  lodsw
  stosw
  call CheckStringTableOverflow
  or   ax,ax
  jz   ExprTransferEnd
  movb  cl,ah
  orb   cl,cl
  jz   ExprTransferNext
ExprTransferSame:
  lodsw
  stosw
  decb  cl
  jnz  ExprTransferSame
  jmps ExprTransferNext
ExprTransferEnd:
  ret

IsSimpleExpression:
  push si
  mov  si,#PostFixBufferStart
  lodsw
  cmp  ax,#256				|0100 for single operand
  jnz  SimpleExprEnd
  lodsw
  lodsw
  cmp  ax,#0
  jnz  SimpleExprEnd
  mov  ax,-4[si]
SimpleExprEnd:
  pop  si
  ret

|This routine gets an operand from the input
|

GotRegister:
  movb  al,[si]
  ret

OperandExpected:
  mov  bx,#OperandExpectedMessage
  call PanicRecover
GetBasicOperand:
  push bx
  call GetToken
  pop  bx
  jc   OperandExpected
  mov  si,#InputWord
  lodsb
  call IsAlphaAL
  jnc  NotARegister		|A Register always start with a character
  cmpb 1[si],#0	|A Register name is always 2 chars
  jnz  NotARegister
  mov  si,#SmallRegisters
  push bx
  call MatchKeyword
  pop  bx
  movb  cl,#1
  jnc  GotRegister
  mov  si,#BigRegisters
  push bx
  call MatchKeyword
  pop  bx
  movb  cl,#2
  jnc  GotRegister
  mov  si,#SegmentRegisters
  push bx
  call MatchKeyword
  pop  bx
  movb  cl,#3
  jnc  GotRegister

NotARegister:
  cmpb  al,#'#'
  jnz  NotanImmediate
  call GetExprValInd
  movb  cl,#4
  ret
NotanImmediate:
  cmpb InputWord,#'['
  jnz  NotAnAddressingMode
  call GetAddressingMode
  movb  cl,#5
  ret
NotAnAddressingMode:
|  call DisplayMessage
|  db   'calling',0dh,0ah,0
  call GetExprValInd1
  pushf
|  call DisplayRegister
  cmpb InputWord,#'['
  jz   HasAddressToo
  popf
  movb  cl,#6
  ret
HasAddressToo:
  push ax
  call GetAddressingMode
  pop  ax
  popf 
  movb  cl,#7
  ret

CompilerFakes:
  .word 0

GetExprValInd1:
  push bx
  clc
  jmps GEVI1

GetExprValInd:
  push bx
  call GetToken
GEVI1:
  call ProcessExpression
  test bx,#Calculated
  jnz  ExprValueFound
  test bx,#IsFake
  jnz  GotExprIndex
  
  push ax
  push bx
  call BackupInputWord
  mov  di,#InputWord
  movb  al,#'_'
  stosb
  stosb
  inc  CompilerFakes
  mov  ax,CompilerFakes
  call SprintRegister
  xorb  al,al
  stosb
  call AddSymbol
  call RestoreInputWord
  pop  bx
  pop  ax
  or   bx,#IsDefined
| or   bx,#IsFake
  mov  Value[di],ax
  mov  Attributes[di],bx
  mov  ax,di
  
GotExprIndex:
  pop  bx
  call AddOffEnt
  stc
  ret
  
ExprValueFound:
  pop  bx
  clc
  ret

WrongMode:
  mov  bx,#InvalidAddrMode
  call PanicRecover
  
GetAddressingMode:
  call GetToken
  mov  si,#AddressingModes
  call MatchKeyword
  jc   WrongMode
  call GetToken
  cmpb InputWord,#']'
  jnz  WrongMode
  movb  bl,[si]
  ret

GetOperand:
  push si
  call GetBasicOperand
  pop  si
  pushf
  cmpb  cl,#3
  jnc  NotNormalRegister
  orb   al,#192
NoValues:
  xorb  ah,ah
GetOperandEnd:
  popf
  ret
NotNormalRegister:
  cmpb  cl,#3
  jnz  NotSegmentRegister
  shlb  al
  shlb  al
  shlb  al
  jmp  NoValues
NotSegmentRegister:
  cmpb  cl,#4
  jnz  NotanImmediate1
  mov  bx,ax
  xorb  ch,ch
  popf
  pushf
  adcb  ch,#0
  movb  ah,#2
  jmp  GetOperandEnd
NotanImmediate1:
  cmpb  cl,#5
  jnz  NotJustMode
  movb  al,bl
  jmp  NoValues
NotJustMode:
  xchg  bx,ax
  cmpb  cl,#6
  jnz  NotJustDisp
  xorb  ch,ch
  popf
  pushf
  jnc  KnownMode
  incb  ch
  mov  bx,#1
KnownMode:
  movb  al,#6
  movb  ah,#2
  jmp  GetOperandEnd
NotJustDisp:
  movb   ch,#0
  popf
  pushf
  jc   DispUnknown
  orb   bh,bh
  jnz  DispEnd
  movb  ah,#1
  orb   al,#64
  jmp  GetOperandEnd
DispUnknown:
  movb  ch,#1
  mov  bx,#1
DispEnd:
  movb  ah,#2
  orb  al,#128
  jmp  GetOperandEnd
