NothingElse:
  lodsb
  call OutputByte
  lodsb
  orb  al,al
  jz  NEDone
  call OutputByte
NEDone:
  ret

ImmediateOpsDisallowed:
  mov  bx,#ImmediateOpsMessage
  call PanicRecover
  
Mode1:
  .word 0
Mode2:
  .word 0
Mode3:
  .word 0

AddType:
  push si
  mov  bx,#2
  call GetOperandMatch
  cmpb  cl,#Immediate
  jz   ImmediateOpsDisallowed
  mov  Mode1,ax
  mov  Mode2,bx
  mov  Mode3,cx
  push ax
  call GetComma
  pop  ax
  movb  bl,ah
  xorb  bh,bh
  inc  bx
  inc  bx
  call GetOperandMatch
  pop  si
  call Bothmem
  cmpb  cl,#Immediate
  jnz  Add3
  call AdjustImmediate
  call IsFirstAcc
  jnc  Add2
  push ax
  movb  al,[si]
  orb   al,#4
  cmpb [si],#199
  jnz  NormalAdd1
  movb  al,1[si]
  andb  al,#1
  orb   al,#168
NormalAdd1:
  call OutputByte
  pop  ax
  mov  ax,bx
  call OutputImmediate
  orb   ch,ch
  call AdjustOffent
  ret

Add2:
  push ax
  movb  al,[si]
  andb  al,#1
  orb   al,#128
  cmpb [si],#199
  jnz  NormalAdd2
  movb  al,1[si]
  andb  al,#1
  orb   al,#246
NormalAdd2:
  call OutputByte
  movb  al,[si]
  andb  al,#56
  orb   al,Mode1
  call OutputByte
  call OutputFirstDisp
  pop  ax
  mov  ax,bx
  call OutputImmediate
  ret
  
Add3:
  movb  dl,1[si]
Add3End:
  call IsFirstReg
  jc   FirstWasRegister
  push ax                       |Second is a register
  movb  al,dl
  call OutputByte
  pop  ax
  shlb  al
  shlb  al
  shlb  al
  orb   al,Mode1
  call OutputByte
  call OutputFirstDisp
  ret

FirstWasRegister:
  push ax
  movb  al,dl
  cmpb [si],#199
  jz   SpecialAdd3
  orb   al,#2
SpecialAdd3:
  call OutputByte
  pop  ax
  movb  ch,Mode1
  shlb  ch
  shlb  ch
  shlb  ch
  orb   al,ch
  call OutputByte
  call OutputSecondDisp
  ret

AdjustImmediate:
  orb   ch,ch
  jz    ImmediateAdjustEnd
  movb   bl,[si]
  andb   bl,#1
  xorb   bh,bh
ImmediateAdjustEnd:
  ret

OutputFirstDisp:
  movb  ah,Mode1 + 1
  orb   ah,ah
  jz   DoneDisp
  movb  al,Mode2
  call OutputByte
  decb  ah
  jz   DoneDisp
  movb  al,Mode2 + 1
  call OutputByte
DoneDisp:
  ret

OutputSecondDisp:
  orb   ah,ah
  jz   SecondDispDone
  movb  al,bl
  call OutputByte
  decb  ah
  jz   SecondDispDone
  movb  al,bh
  call OutputByte
SecondDispDone:
  ret


OutputImmediate:
  push ax
  movb  al,[si]
  cmpb [si],#199
  jnz  NormalImmediateOutput
  movb  al,1[si]
NormalImmediateOutput:
  testb al,#1
  jnz  Immword
  pop  ax
  call CheckForSize
  call OutputByte
  ret
Immword:
  pop  ax
  call OutputByte
  movb  al,ah
  call OutputByte
  ret
  
Bothmem:
  cmpb  cl,#AddMode
  jc   BothMemOk
  cmpb Mode3,#AddMode
  jc   BothMemOk
  mov  bx,#MemoryOperandMessage
  call PanicRecover
BothMemOk:
  ret

IsFirstAcc:
  cmpb Mode3,#Immediate
  jnc  NotAcc
  cmpb Mode1,#192
  jnz  NotAcc
  stc
  ret

IsSecondAcc:
  cmpb  cl,#Immediate
  jnc  NotAcc
  cmpb  al,#192
  jnz  NotAcc
  stc
  ret
  

IsFirstReg:
  cmpb Mode3,#SegReg
  ret

NotAcc:
  clc
  ret


JmpCallType:
  mov  bx,#2
  call GetOperand
  cmpb  cl,#Disp
  jnz  NotDirectJump
  movb  al,[si]
  call OutputByte
  orb   ch,ch
  jnz  JCTNotEvaluated
  mov  ax,LocationCounter
  add  ax,#2
  sub  ax,bx
  neg  ax
  call OutputWord
  ret
JCTNotEvaluated:
  orb   ch,ch
  call AdjustOffent
  mov  ax,#3
  call OutputWord
  ret
NotDirectJump:
  push ax
  movb  al,#255
  call OutputByte
  pop  ax
  orb   al,1[si]
  call OutputByte
  call OutputSecondDisp
  ret

ColonMissing:
  mov  bx,#ColonMessage
  call PutExpectedMessage

SecondNumberMissing:
  mov  bx,#DisplacementMessage
  call PutExpectedMessage

MemoryOperandExpected:
  mov  bx,#MemOperandMessage
  call PutExpectedMessage

JmpCallFarType:
  mov  bx,#2
  call GetOperand
  cmpb  cl,#Immediate
  jnz  NotDirect
  call AdjustImmediate
  push bx
  movb  al,[si]
  call OutputByte
  cmpb InputWord,#':'
  jnz  ColonMissing
  mov  bx,#2
  call GetOperand
  cmpb  cl,#Disp
  jnz  SecondNumberMissing
  mov  ax,bx
  call OutputWord
  pop  ax
  call OutputWord
  ret
NotDirect:
  cmpb  cl,#Immediate
  jc   MemoryOperandExpected
  push ax
  movb  al,#255
  call OutputByte
  pop  ax
  orb   al,1[si]
  call OutputByte
  call OutputSecondDisp
  ret

RegExpected:
  mov  bx,#RegOperandMessage
  call PutExpectedMessage

RegisterMemory:
  movb  al,[si]
  call OutputByte
  mov  bx,#1
  call GetOperand
  cmpb  cl,#Immediate
  jnc  RegExpected
  andb  al,#7
  shlb  al
  shlb  al
  shlb  al
  push ax
  call GetComma
  call GetOperand
  cmpb  cl,#Disp
  jc   MemoryOperandExpected
  pop  dx
  orb   al,dl
  call OutputByte
  call OutputSecondDisp
  ret

IncDecType:
  mov  bx,#2
  call GetOperandMatch
  cmpb  cl,#Reg16
  jnz  not16Register
  andb  al,#7
  orb   al,[si]
  call OutputByte
  ret
not16Register:
  push ax
  movb  al,#255
  call OutputByte
  pop  ax
  orb   al,1[si]
  call OutputByte
  call OutputSecondDisp
  ret

CheckRegOrMemOp:
  cmpb  cl,#Immediate
  jz   InvalidImmOperand
  ret

InvalidImmOperand:
  mov  bx,#RegOrMemMessage
  call PutExpectedMessage

RegOrMem:
  movb al,[si]
  call OutputByte
  mov  bx,#1
  call GetOperandMatch
  call CheckRegOrMemOp
  orb   al,1[si]
  call OutputByte
  call OutputSecondDisp
  ret

DivMulRegMem:
  movb  al,[si]
  call OutputByte
  mov  bx,#1
  call GetOperandMatch
  call CheckRegOrMemOp
  orb   al,1[si]
  call OutputByte
  call OutputSecondDisp
  ret


InOutPort:
  call CheckEOL
  jz   NoPorts
  mov  bx,#1
  call GetOperandMatch
  call CheckImmediateOperand
  orb   ch,ch
  jz   PortEvaluated
  movb  bl,#0
PortEvaluated:
  movb  al,[si]
  call OutputByte
  movb  al,bl
  call OutputByte
  ret

NoPorts:
  movb  al,[si]
  orb   al,#8
  call OutputByte
  ret


OneByteOnly:
  lodsb
  call OutputByte
  xorb  al,al
  xor  bx,bx
  call GetNumericOperand
  mov  ax,bx
  jnc  OneByteEnd
  xorb  al,al
OneByteEnd:
  call CheckForSize
  call OutputByte
  ret

  
CheckForSize:
  orb  ah,ah
  jnz  VariableNotSmallEnough
SizeOK:
  ret
VariableNotSmallEnough:
  cmpb ah,#0xFF
  jz   SizeOK                   |was checking of Msbit, disabled
VariableTooLarge:
  mov  bx,#LargeOperandMessage
  call PanicRecover

InvMode:
  mov  bx,#InvalidAddrMode
  call PanicRecover

OneRelativeLabel:
  mov  bx,#1
  call GetOperand
  cmpb  cl,#Disp
  jnz  InvMode
  movb  al,[si]
  call OutputByte
  orb   ch,ch
  jnz  RJNotEval
  mov  ax,LocationCounter
  add  ax,#1
  sub  ax,bx
  neg  ax
  rolb al
  rorb al
  adcb ah,#0
  jz   InrelRange
  jmp  VariableTooLarge
InrelRange:
  call OutputByte
  ret

RJNotEval:
  movb  al,#2
  call OutputByte
  ret

MovType:
  mov  bx,#2
  call GetOperandMatch
  mov  Mode1,ax
  mov  Mode2,bx
  mov  Mode3,cx
  push ax
  call GetComma
  pop  ax
  movb  bl,ah
  xorb  bh,bh
  inc  bx
  inc  bx
  call GetOperandMatch
  cmpb  cl,#Immediate
  jnz  NotType2or7
  call AdjustImmediate
  cmpb Mode3,#Immediate
  jnc  NotType2
  orb   ch,ch
  call AdjustOffent
  movb  cl,Mode1
  andb  cl,#7
  movb  al,[si]
  shlb  al
  shlb  al
  shlb  al
  orb   al,cl
  orb  al,#176
  call OutputByte
  mov  ax,bx
  call OutputImmediate
  ret
NotType2:
  push ax
  movb  al,[si]
  orb   al,#198
  call OutputByte
  movb  al,Mode1
  call OutputByte
  pop  ax
  call OutputFirstDisp
  mov  ax,bx
  call OutputImmediate
  ret
NotType2or7:
  cmpb Mode3,#SegReg
  jnz  NotType5
  push ax
  movb  al,#142
  call OutputByte
  pop  ax
  orb   al,Mode1
  call OutputByte
  call OutputSecondDisp
  ret  
NotType5:
  cmpb  cl,#SegReg
  jnz  NotType6
  push ax
  movb  al,#140
  call OutputByte
  pop  ax
  orb   al,Mode1
  call OutputByte
  call OutputFirstDisp
  ret
NotType6:
  call IsFirstAcc
  jnc  NotType3
  cmpb  cl,#Disp
  jnz  NotType3
  movb  al,[si]
  orb   al,#160
  orb   ch,ch
  call AdjustOffent
  call OutputByte
  call OutputSecondDisp
  ret
NotType3:
  call IsSecondAcc
  jnc  NotType4
  cmpb Mode3,#Disp
  jnz  NotType4
  movb  al,[si]
  orb   al,#162
  cmpb Mode3 + 1,#0
  call AdjustOffent
  call OutputByte
  call OutputFirstDisp
  ret
NotType4:
  call Bothmem
  movb  dl,[si]
  orb   dl,#136
  jmp  Add3End
  
AdjustOffent:
  jz   AdjustedOffent
  mov  di,EmptyOffent
  dec  -2[di]
AdjustedOffent:
  ret

PushPopType:
  mov  bx,#2
  call GetOperandMatch
  cmpb  cl,#SegReg
  jnz  DontPushSeg
  orb   al,#06
  movb  cl,1[si]
  andb  cl,#1
  orb   al,cl
  call OutputByte
  ret
DontPushSeg:
  cmpb  cl,#Reg16
  jnz  DontPushReg16
  andb  al,#7
  orb   al,#80
  movb  cl,1[si]
  andb  cl,#8
  orb   al,cl
  call OutputByte
  ret
DontPushReg16:
  push ax
  movb  al,[si]
  call OutputByte
  pop  ax
  movb  cl,1[si]
  andb  cl,#48
  orb   al,cl
  call OutputByte
  call OutputSecondDisp
  ret

GetOperandMatch:
  call GetOperand
  pushf
  cmpb  cl,#SegReg
  jnc  Matched
  cmpb  cl,#Reg8
  jnz  NotSmallReg
  cmpb -3[si],#0
  jnz  InvalidOperand1
Matched:
  popf
  ret
NotSmallReg:
  cmpb -3[si],#0
  jnz  Matched
  
InvalidOperand1:
  popf  
InvalidOperand:
  mov  bx,#InvalidOperandMessage
  call PanicRecover

ShiftRotate:
  mov  bx,#2
  call GetOperandMatch
  mov  Mode1,ax
  mov  Mode2,bx
  mov  Mode3,cx
  call CheckEOL
  movb  al,#0
  jz   NotCL
  call GetComma
  mov  bx,#2
  call GetOperand
  cmpb  cl,#Reg8
  jnz  InvalidOperand
  cmpb  al,#193
  jnz  InvalidOperand
  movb  al,#2
NotCL:
  orb   al,[si]
  call OutputByte
  movb  al,Mode1
  orb   al,1[si]
  call OutputByte
  call OutputFirstDisp
  ret

SegmentRegister:
  call GetOperand
  cmpb  cl,#SegReg
  jnz  InvalidOperand
  orb   al,[si]
  call OutputByte
  ret

ReturnType:
  call CheckEOL
  jnz  DispRet
  movb  al,[si]
  call OutputByte
  ret

DispRet:
  movb  al,1[si]
  call OutputByte 
  xor  bx,bx
  call GetOperand
  call CheckImmediateOperand
  call AdjustImmediate
  mov  ax,bx
  call OutputImmediate
  ret

XchgType:
  mov  bx,#2
  call GetOperandMatch
  mov  Mode1,ax
  mov  Mode2,bx
  mov  Mode3,cx
  push ax
  call GetComma
  pop  ax
  movb  bl,ah
  xorb  bh,bh
  inc  bx
  inc  bx
  call GetOperandMatch
  testb [si],#1
  jz   Xchg2
  call IsFirstAcc
  jnc  NotXchg11
  cmpb  cl,#Reg16
  jnz  Xchg2
Xchg1End:
  andb  al,#7
  orb   al,#144
  call OutputByte
  ret

NotXchg11:
  call IsSecondAcc
  jnc  Xchg2
  cmpb Mode3,#Reg16
  jnz  Xchg2
  movb  al,Mode1
  jmps Xchg1End

Xchg2:
  jmp  Add3

GetNumericOperand:
  call GetOperand
  pushf
  cmpb  cl,#Immediate
  jnz  GetNumOpEnd
  popf
  ret
GetNumOpEnd:
  popf
  mov  bx,#NumOpExpectedMessage
  call PanicRecover
  
CheckImmediateOperand:
  cmpb  cl,#Immediate
  jnz  GetNumOpEnd
  ret

CheckEOL:
  push si
  call IgnoreSpaces
  call GetChar
  jc   isEOL1
  call UnGetChar
  cmpb  al,#CR
  jz   isEOL
  cmpb  al,#LF
  jz   isEOL
  cmpb  al,#'|'
  jz   isEOL
  cmpb  al,#'|'
isEOL:
  pop  si
  ret

isEOL1:
  push ax
  xorb al,al    |set the zero flag
  pop  ax
  ret

