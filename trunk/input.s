|This procedure gets a word from the input, actually it gets a token.
|When a carriage return is found, the linecount is incremented
|
|
|

GetWord:
  call GetToken
  jc   GetWordEnd
  movb  al,InputWord
  call IsAlphaDotAL
  jnc  InvalidStart
  clc
GetWordEnd:
  ret

InvalidStart:
  mov  bx,#BadStartMessage
  call PanicRecover


GetToken:
  push ax
  push bx
  push cx
  push dx
  push si
  push di
  call IgnoreSpaces
  jc   GetTokenEnd
  mov  di,#InputWord
  call GetChar
  jc   GetTokenEnd
  call IsAlphaNumDotAL
  jnc  NonAlphaNumeric
  call IsNumAL
  jnc  MustBeWord
  				|Only Numbers come here.
				|Numbers may be decimal,hexadecimal
  cmpb al,#'0'			|leading digit is not zero - decimal
  jnz  GetNumber
  stosb
  call GetChar
  cmpb al,#'X'			|for hex
  jz   GetHexNumber
  cmpb al,#'x'
  jz   GetHexNumber
  call UnGetChar
  jmps GetNumber1
  
GetNumber:
  stosb
GetNumber1:
  call GetChar
  jc   NumberEnded1
  call IsNumAL
  jc   GetNumber
NumberEnded:
  call UnGetChar
NumberEnded1:
  clc
GetTokenEnd:
|  pushf
|  mov  bx,#InputWord
|  call DisplayOtherMessage
|  call DisplayMessage
|  db   'is the token got',0dh,0ah,0
|  popf
  pushf
  xorb al,al
  stosb
  popf
  pop  di
  pop  si
  pop  dx
  pop  cx
  pop  bx
  pop  ax
  ret

MustBeWord:
  stosb
  cmp  di,#InputWord+WordSize|
  jnz  StartWordSizeStillOK             |If the identifier is too large then
  mov  bx,#IdentLargeMessage      |crib and come out
  call PanicRecover                            |
StartWordSizeStillOK:                   |
  call GetChar
  jc   WordEnded
  call IsAlphaNumDotAL                  |Succeeding can be als,nums,dots
  jc   MustBeWord                       |If yes store them too
  call UnGetChar
WordEnded:
  clc
  jmps GetTokenEnd

GetHexNumber:
  orb  al,#'a' - 'A'			|downcase it, for later
GetHexNumber1:
  stosb
  call GetChar
  jc   NumberEnded1
  call IsHexAL
  jc   GetHexNumber1
  jmps NumberEnded

LostQuote:
  mov  bx,#MissingQuoteMessage
  call PanicRecover

NonAlphaNumeric:
  cmpb al,#'''
  jnz  OnlyThisChar
  stosb
  call GetChar
  jc   LostQuote
  stosb
  call GetChar
  jc   LostQuote
  cmpb al,#'''
  jnz  LostQuote
  stosb
  clc
  jmps GetTokenEnd

OnlyThisChar:
  cmpb  al,#'|'
  jz   CommentStartIgnore
  cmpb  al,#CR
  jz   CommentStartIgnore
  cmpb  al,#LF	
  jz   CommentStartIgnore
  stosb
  clc
  jmps GetTokenEnd

CommentStartIgnore:
  call UnGetChar
  clc
  jmps GetTokenEnd

IgnoreSpaces:
  call GetChar
  jc   IgnoreSpacesEnd
  cmpb  al,#' '
  jz   IgnoreSpaces
  cmpb  al,#'	'
  jz   IgnoreSpaces
  call UnGetChar
  clc
IgnoreSpacesEnd:
  ret


GetComma:
  cmpb InputWord,#','
  jz   GetCommaEnd
  push si
  call IgnoreSpaces
  jc   GetCommaNo
  call GetChar
  cmpb  al,#','
  jz   GetCommaYes
GetCommaNo:
  mov  bx,#CommaMessage
  call PutExpectedMessage
GetCommaYes:
  pop  si
GetCommaEnd:
  ret

| Assemble an instruction

GetInstruction:
  mov  si,#Instructions
  call MatchKeyword
  jc  InstructionNoMatch
  mov  ax,[si]
  inc  si
  inc  si
  call ax
  clc
InstructionNoMatch:
  ret

|IsAlphaAL
|This function returns carry if A is alphabetic else it returns no carry

IsAlphaAL:
  cmpb al,#'A'                           |First check whether it is in
  jc   LessThanBigA                     |the capital letters of the alphabet
  cmpb  al,#'['                    |if >= A & <= Z then it is a valid
  jc   WhatWeWant                       |character
LessThanBigA:                           |Now checking for the lower case
  cmpb  al,#'a'                           |if >= a
  jc   LessThanSmallA                   |and <= z
  cmpb  al,#'{'                  |then too it is a valid
  jc   WhatWeWant                       |character
LessThanSmallA:                         |If neither uppercase or lower
  cmpb  al,#'_'                       |case then check for an underscore
  jnz  NotWhatWeWant                    |The underscore is also treated
  stc                                   |as an alphabetic character

WhatWeWant:
  ret

NotWhatWeWant:                          |
  clc
  ret

IsNumAL:
  cmpb al,#'0'
  jc   NotWhatWeWant
  cmpb al,#':'
  ret

IsHexAlphaAL:
  cmpb al,#'A'
  jc   NotWhatWeWant
  cmpb al,#'G'
  jc   WhatWeWant
  cmpb al,#'a'
  jc   NotWhatWeWant
  cmpb al,#'g'
  jnc  NotWhatWeWant
  subb al,#'a' - 'A'
  stc
  ret

|Surprise - converts to uppercase as well if a hex alphabet to take care.

IsHexAL:
  call IsNumAL
  jc   WhatWeWant
  call IsHexAlphaAL
  ret
  
IsAlphaDotAL:
  call IsAlphaAL
  jc   WhatWeWant
  cmpb al,#'.'
  jnz  NotWhatWeWant
  stc
  ret

IsAlphaNumDotAL:
  call IsAlphaDotAL
  jc   WhatWeWant
  call IsNumAL
  ret

|This function is called, when all the arguments of the current line
|have been processed. i.e. when no more arguments are needed. This is
|called before each statement is processed. It processes the comment
|to the end of the line, if any, consumes the newline, skips to the
|next line, If that line is empty (contains only white spaes) or
|contains just a comment (with or without leasing spaces) then the
|line is also consumed. This continues till a line, with a non-
|comment, non whitespace start is found. The procedure also eats up
|characters till the first non-white space character on that line.


GetEndOfLine:                           |
  xor  bp,bp                            |No line end found
GetEndOfLine1:                          |In case of start of file
  call GetChar                          |Get the next input character
  jnc  NotYetEofForEol                  |If EOF then abort
  inc  bp                               |EOF also valid end of stmt.
  stc
  jmps GetEndOfLineEnd

NotYetEofForEol:
  cmpb  al,#' '                           |If it is a space then consume
  jz   GetEndOfLine1              |the space and continue
  cmpb  al,#'	'                             |Do the same even if you
  jz   GetEndOfLine1              |encounter a TAB character.
  cmpb  al,#CR                           |Reached end of line on the input
  jz   GetEndOfLine1              |Discard any carriage returns that
  cmpb  al,#LF                           |were there in the input. So also
  jnz  NoLine                           |the line feeds
EolHaveLF:	
  inc  bp
  inc  InputLineNumber
  jmps GetEndOfLine1
NoLine:
  cmpb al,#'|'                           |Is it the start of a comment?
  jz   CommentStarted                   |If it isn't then we put back the
  call UnGetChar                        |extra character that we got.
  clc                                   |Signal that a line was found
GetEndOfLineEnd:                        |to the caller
  lahf
  or   bp,bp                            |If a line end wasn't found
  jnz  HadFoundEnd                      |then error
  mov  bx,#ExtraCharsMessage     |that extra characters were there
  call PanicRecover                            |at the end of line
HadFoundEnd:                            |
  sahf
  ret                                   |and get back.

CommentStarted:                         |A UNIX pipe character was found
  call GetChar                          |Get the mext input character
  jc   GetEndOfLineEnd                  |EOF found on the input
  cmpb  al,#CR                           |If we reach a carraige return
  jz   GetEndOfLine1                    |it means that the comment ended
  cmpb  al,#LF                           |So also for a linefeed (MINIX)
  jnz  CommentStarted                   |So we start processing the next line
  jmps EolHaveLF

|This function reads a character from a file, The input is buffered by the
|InputBuffer. The function keeps track of where it is by keeping two pointers.
|The InputBufferReadPtr (points to the character that has to be read) and
|the InputBufferEndPtr (points beyond the last character that was read). If the
|InputBufferReadPtr reaches the InputBufferEndPtr, then the characters in the
|buffer have all been read. The buffer has to be loaded agein from the file.
|
|Destroys a lot of things
|
|Returns : No carry and character in al if successful
|           Carry if unsuccessful
GetChar:
  mov  ax,InputBufferReadPtr            |If the read ptr is the same as the end
  cmp  ax,InputBufferEndPtr             |ptr, it means that all the characters
  jz   InputBufferFinished              |in the buffer have been read
  mov  si,ax                            |If not then load the next character
  lodsb                                 |and save the new read ptr
  mov  InputBufferReadPtr,si            |
  cmpb  al,#26                          |Not for MINIX. 1A means eof
  jz   GetAtEndOfFile                   |for dos
  clc
  ret


InputBufferFinished:
  movb ah,#ReadFunction                  |DOS function read from a file into the
  mov  bx,InputFileHandle               |input buffer.
  mov  cx,#BufferSize
  mov  dx,#InputBuffer
  int  #DosInterrupt
  jnc  BufferReadWasOK                  |If there was an error, then panic
  mov  bx,#ErrorReadingInputMessage
  call Panic
BufferReadWasOK:
  cmp  ax,#0                            |else if no chars were read, then
  jnz  NotEndOfFile                     |it means that the end of file was
GetAtEndOfFile:
  stc                                   |reached. Return a carry to show that
  ret                                   |couldn't return a value.
NotEndOfFile:                           |If some characters were read, then
  mov  si,#InputBuffer            |the pointers to the beginning and
  add  si,ax                            |the end of the buffer are made right
  mov  InputBufferEndPtr,si             |ax has the number of characters that
  sub  si,ax                            |were read. Get the first character
  lodsb                                 |into al,
  mov  InputBufferReadPtr,si            |Adjust the start buffer
  clc                                   |Return success
  ret                                   |

UnGetChar:
  dec InputBufferReadPtr
  ret

BackupInputWord:
  push si
  push di
  push cx
  mov  si,#InputWord
  mov  di,#BackupWord
InputWordMoveEnd:
  mov  cx,#WordSize
  rep
  movsb
  pop  cx
  pop  di
  pop  si
  ret

RestoreInputWord:
  push si
  push di
  push cx
  mov  si,#BackupWord
  mov  di,#InputWord
  jmp  InputWordMoveEnd
