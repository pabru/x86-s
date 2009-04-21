|CompileExpression


OpenBrackPrec  = 1
AddOpPrec      = 2
MulOpPrec      = 3
BangOpPrec     = 4		    |of the binary ! operator
UnaryOpPrec    = 50



|CompileExpression
|

CompileExpression:
  mov  bx , #1                      |last was operator(bh) = 0 start (bl) = 1
  movb  dl, #0                      |operand count.
  movb  dh, #0                      |operands needed
  pushf
  xor  ax,ax
  stosw
  popf
  push ax
  jmps FirstTokenThere
CompileNext:
  call GetToken
FirstTokenThere:
  jnc  TokenGot
  jmp  EndofExpression
TokenGot:
  movb  al,InputWord
  call IsAlphaNumDotAL
  jc   ConstantGot
  cmpb al,#'''
  jnz  NotNumber
ConstantGot:
  orb   bh,bh
  jnz  CanGetConstNow
  orb   bl,bl
  jnz  CanGetConstNow
SyntaxErrorMessage:
  mov  bx,#SyntaxErrMessage
  call PanicRecover
CanGetConstNow:
  call GetIdForToken
  stosw
  xor  bx,bx                       |Last was operator = 0 | start = 0
  incb  dl                          |operand count
  incb  dh
  jmps CompileNext

NotNumber:
  call IsOperator
  jnz  NotAnOperator
  or   bx,bx                       |last was operator or start
  jz   LastWasNotOperator
  call IsUnaryOperator
  jz   WasUnaryOperator
  jmp  SyntaxErrorMessage
WasUnaryOperator:
  incb  dh                          |unary ops need 0 operands
  addb  al,#0x80
  movb  ah,#UnaryOpPrec
LastWasNotOperator:
  mov  cx,ax
  decb  dh
ContinuePopping:
  mov  bp,sp
  cmpb  1[bp],ah                   |if the operator on stack has a higher
  jc   FinishedPopping             |or same precedence
  cmp  0[bp],#0         |if the stack isn't finished
  jz   FinishedPopping
  testb cl,#0x80
  jnz  FinishedPopping
  pop  ax
  call PatchLastOperator
  stosw
  jmps ContinuePopping
FinishedPopping:
  push cx
  movb  bh,#1                        |last was operator = 1
  testb cl,#0x80
  jnz  dontchangestart
  xorb bl,bl                       | Start = 0
dontchangestart:
  jmp  CompileNext

NotAnOperator:
  cmpb  al,#'('
  jnz  NotOpenBraces
  movb  ah,#OpenBrackPrec
  push ax
  mov  bx,#1                        |Last was operator = 0, Start = 1
  jmp  CompileNext

NotOpenBraces:
  cmpb  al,#')'
  jnz  NotCloseBraces
HaveNotFoundOpen:
  pop  ax
  cmp  ax,#0
  jnz  NoUnmatchedBraces
  mov  bx,#BracketsErrMessage
  call PanicRecover
NoUnmatchedBraces:
  cmpb  al,#'('
  jnz  StoreThisOne
  jmp  CompileNext
StoreThisOne:
  call PatchLastOperator
  stosw
  jmps HaveNotFoundOpen


NotCloseBraces:
EndofExpression:
  orb   bl,bl          |start
  jz   FoundSomething
  jmp  SyntaxErrorMessage

FoundSomething:
  decb  dh
  jz   OperatorCountOK
  jmp  SyntaxErrorMessage

OperatorCountOK:
  pop  ax
  call PatchLastOperator
  stosw
  cmpb  al,#'('
  jnz  Notextraleft
  mov  bx,#BracketsErrMessage
  call PanicRecover

Notextraleft:
  or   ax,ax
  jnz  OperatorCountOK

|  mov  si, #PostFixBufferStart
|  call DisplayMessage
|  db   'Compiled Expr is :',0
|NextOperator:
|  lodsw
|  call DisplayRegister
|  call DisplayMessage
|  db   ' ',0
|  mov  cl,ah
|  or   ax,ax
|  jz   ExpressionEnd
|  or   cl,cl
|  jz   NextOperator
|moretodisplay:
|  lodsw
|  call DisplayRegister
|  call DisplayMessage
|  db   ' ',0
|  dec  cl
|  jnz  moretodisplay
|  jmp  short NextOperator
|ExpressionEnd:
|  mov  ax, StringSpace
|  call DisplayRegister
|  call DisplayMessage
|  db   0dh,0ah,0
  ret


PatchLastOperator:
  push di
  push dx
  xorb  dh,dh
  inc  dx
  sal  dx
  sub  di,dx
  sarb  dl
  decb  dl
  movb  1[di],dl
  pop  dx
  pop  di
  xorb  dl,dl
  ret

Overflow:
  mov  bx,#OverFlowMessage
  call PanicRecover

EvalErrorEnd:
  mov  sp,bp
  stc
  ret

EvaluateExpression:
  mov  bp,sp
  lodsw
  orb   ah,ah
  jz   EvalErrorEnd
  movb  cl,ah
NextCycle:
  orb   cl,cl
  jz   OperatorFound
MoreConsts:
  lodsw
  call FindValue
  jc   EvalErrorEnd
  push ax
  decb  cl
  jnz  MoreConsts
OperatorFound:
  lodsw
  or   ax,ax
  jz   EvalEnd
  movb  cl,ah
  cmpb  al,#'+'
  jnz  notplus
  pop  bx
  pop  ax
  add  ax,bx
  jc   Overflow
  push ax
  jmp  NextCycle
notplus:
  cmpb  al,#'-'
  jnz  notminus
  pop  bx
  pop  ax
  sub  ax,bx
  jc   Overflow
  push ax
  jmp  NextCycle
notminus:
  cmpb  al,#'*'
  jnz  notstar
  pop  bx
  pop  ax
  xor  dx,dx
  mul bx
  jc   Overflow
  push ax
  jmp  NextCycle
notstar:
  cmpb al,#'!'
  jnz  notbang
  pop  ax
  orb  ah,ah
  jnz  Overflow
  movb bl,al
  pop  ax
  orb  ah,ah
  jnz  Overflow
  movb ah,al
  movb al,bl
  push ax
  jmp  NextCycle
notbang:
  cmpb  al,#'/'
  jnz  notslash
  pop  bx
  pop  ax
  xor  dx,dx
  div bx
  push ax
  jmp  NextCycle
notslash:
  cmpb  al,#'-'+0x80
  jnz  notuminus
  pop  ax
  neg  ax
  push ax
  jmp  NextCycle
notuminus:
  cmpb  al,#'%'
  jnz  notmod
  pop  bx
  pop  ax
  xor  dx,dx
  div bx
  push dx
  jmp  NextCycle
notmod:
  cmpb  al,#'!'+0x80
  jnz   notnot
  pop  ax
  not  ax
  push ax
  jmp  NextCycle
notnot:
  jmp  NextCycle
EvalEnd:
  pop  ax
  ret

|Identifies unary as well as binary operators. For binary operators,
|it returns with ah as the precedence of the operator. For unary operators,
|ah might not make sense, 'cos some operators are binary as well as unary
|operators - specifically + and -. In such cases, it returns the precedence
|of the binary operator even if the usage was as a unary operator. This
|distinction is done later on.


IsOperator:
  movb  ah,#AddOpPrec
  cmpb  al,#'+'
  jz   IsOperatorEnd
  cmpb  al,#'-'
  jz   IsOperatorEnd
  movb  ah,#MulOpPrec
  cmpb  al,#'*'
  jz   IsOperatorEnd
  cmpb  al,#'/'
  jz   IsOperatorEnd
  cmpb  al,#'%'
  jz   IsOperatorEnd
  movb  ah,#BangOpPrec
  cmpb  al,#'!'
IsOperatorEnd:
  ret

IsUnaryOperator:
  cmpb  al,#'-'
  jz   IsUnaryOperatorEnd
  cmpb  al,#'+'
  jz   IsUnaryOperatorEnd
  cmpb  al,#'!'
IsUnaryOperatorEnd:
  ret



GetIdForToken:
  push bx
  push cx
  push dx
  push si
  push di
  movb  al,InputWord
  call IsAlphaAL
  jc  IsName
  call DecimalConvertNumber
  call FindFakeSymbol
GotIndex:
  mov  ax,si
  pop  di
  pop  si
  pop  dx
  pop  cx
  pop  bx
  ret

IsName:
  call FindSymbol
  jnc  HaveIndexAlready
  call AddSymbol
  mov  Attributes[di],#0
  mov  Value[di],#0
HaveIndexAlready:
  call RecordXref
  jmps GotIndex
