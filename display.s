CharsDisplayed:
  .byte 0

PutCarriageReturn:
  call DisplayMessage
  .byte 13
  .byte 10
  .byte 0
  ret

DisplaySignedAX:
  movb CharsDisplayed,#0
  or   ax,ax
  jns  DisplayAXInDecimal
  push ax
  movb  al,#'-'
  call DisplayCharacter
  pop  ax
  neg  ax
  call DisplayAXInDecimal
  neg  ax
  ret

DisplayAXInDecimal:
  movb CharsDisplayed,#0
  push ax
  push dx
  push cx
  push bx
  mov  cx,#10
  mov  bx,#0
MoreDigitsToBeFound:
  xor  dx,dx
  div  cx
  push dx
  inc  bx
  or   ax,ax
  jnz  MoreDigitsToBeFound
MoreDigitsToBeDisplayed:
  pop  ax
  call DisplayDecimalDigit
  dec  bx
  jnz  MoreDigitsToBeDisplayed
  pop  bx
  pop  cx
  pop  dx
  pop  ax
  ret


DisplayMessage:
  movb CharsDisplayed,#0
  push bp
  mov  bp,sp
  push bx
  push dx
  push ax
  mov  bx,2[bp]
MoreCharsToBeDisplayed:
  movb  al,[bx]
  inc  bx
  orb   al,al
  jz   MessageEnded
  call DisplayCharacter
  jmps MoreCharsToBeDisplayed
MessageEnded:
  mov  2[bp],bx
  pop  ax
  pop  dx
  pop  bx
  pop  bp
  ret

DisplayOtherMessage:
  movb CharsDisplayed,#0
  push bx
  push ax
StillMoreOtherChars:
  movb al,[bx]
  inc  bx
  orb  al,al
  jz   OtherMessageEnded
  call DisplayCharacter
  jmps StillMoreOtherChars
OtherMessageEnded:
  pop  ax
  pop  bx
  ret

PadWithSpaces:
  push ax
  cmpb al,CharsDisplayed
  jc   PaddedWithSpaces
  jz   PaddedWithSpaces
  movb ah,al
  movb al,#' '
MorePaddingRequired:
  call DisplayCharacter
  cmpb ah,CharsDisplayed
  jnz  MorePaddingRequired
PaddedWithSpaces:
  pop  ax
  ret

DisplayDecimalDigit:
  push ax
  andb  al,#0x0F
  addb  al,#'0'
  call DisplayCharacter
  pop  ax
  ret

DisplayRegister:
  push cx
  movb  ch,#4
DisplayRegisterMore:
  rol  ax
  rol  ax
  rol  ax
  rol  ax
  call DisplayHexDigit
  decb  ch
  jnz  DisplayRegisterMore
  pop  cx
  ret

HexDigitTable:
  .ascii "0123456789ABCDEF"

DisplayHexDigit:
  push ax
  push bx
  andb  al,#15
  mov  bx,#HexDigitTable
  xlat
  call  DisplayCharacter
  pop  bx
  pop  ax
  ret

DisplayCharacter:
  push ax
  push dx
  movb  dl,al
  movb  ah,#2
  int  #0x21
  incb CharsDisplayed
  pop  dx
  pop  ax
  ret
