OutputFrom = 256

PresentOutputOffset:
  .word OutputStart + OutputFrom
LocationCounter:
  .word OutputFrom

OutputByte:
  push di
  mov  di,PresentOutputOffset
|  call DisplayRegister
|  call DisplayMessage
|  db   ':Outputting ',0dh,0ah,0
  stosb
  mov  PresentOutputOffset,di
  call CheckOutputOverflow
  sub  di,#OutputStart
  mov  LocationCounter,di
  pop  di
  ret

OutputWord:
  call OutputByte
  xchgb ah,al
  call OutputByte
  xchgb ah,al
  ret

CheckOutputOverflow:
  cmp  di,#OutputEnd
  jc   OutputStillOK
  mov  bx,#OutputBigMessage
  call Panic
OutputStillOK:
  ret

WriteOutputFile:
  mov  cx,PresentOutputOffset
  mov  dx,#OutputStart
  add  dx,#OutputFrom
  sub  cx,dx
  mov  bx,OutputFileHandle
  movb ah,#WriteFunction
  int  #DosInterrupt
  jc   OutputError
  ret
OutputError:
  mov  bx,#OutputFileMessage
  call Panic

