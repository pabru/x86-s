|This procedure is called, in case the assembler found an error, the
|On input
|  BX points to the message to be printed
|
|The procedure print 'asm :', the message, a carriage return and a line feed
|and exits to dos


PanicRecover:
  call PutErrorAndPosition
  call DisplayOtherMessage
  call PutCarriageReturn
  call CommentStarted
  mov  sp,SavedStackPointer
  jmp  Assemble1

Panic:
  call PutErrorAndPosition
  call DisplayOtherMessage
CRAndExitToDos:
  call PutCarriageReturn
  call CloseInputFile
  call CloseOutputFiles
  call RemoveOutputFile
ExitToDos:
  movb  ah,#TerminateFunction
  int  #DosInterrupt

PutPosition:
  push bx
  mov  bx,PresentFileNameOffset
  or   bx,bx
  jnz  NotCommandLine
  call DisplayMessage
  .asciz "Command line"
  jmps DisplayForAllMessages
NotCommandLine:
  call DisplayOtherMessage
  call DisplayMessage
  .asciz ":"
  mov  ax,InputLineNumber
  call DisplayAXInDecimal
DisplayForAllMessages:
  call DisplayMessage
  .asciz ":"
  pop  bx
  ret

PutErrorAndPosition:
  call DisplayMessage
  .asciz "Error:"
  call PutPosition
  ret

PutExpectedMessage:
  call PutErrorAndPosition
  call DisplayMessage
  .asciz "'"
  call DisplayOtherMessage
  call DisplayMessage
  .asciz "'"
  call DisplayMessage
  .asciz " expected"
  jmp  CRAndExitToDos


HelpMessage:
  .asciz "Usage - as filename"
NoInputFileMessage:
  .asciz "Could not open input file"
ErrorReadingInputMessage:
  .asciz "Error reading the input file"
BadStartMessage:
  .asciz "Bad start of identifier, Syntax error"
IdentLargeMessage:
  .asciz "Identifier too large"
InvalidInstrMessage:
  .asciz "Invalid Instruction"
ExtraCharsMessage:
  .asciz "Extra Characters on line"
SymTabOverflowMessage:
  .asciz "Symbol table overflow"
RedefinitionMessage:
  .asciz "Symbol already defined"
LargeConstMessage:
  .asciz "Constant too large"
LargeIdentMessage:
  .asciz "Identifier too large"
StrTblOverflowMessage:
  .asciz "String table overflow"
SyntaxErrMessage:
  .asciz "Syntax error in expression"
BracketsErrMessage:
  .asciz "Unmatched brackets"
OverFlowMessage:
  .asciz "Overflow in expression evaluation"
SymbolNotDefinedMessage:
  .asciz "Symbol not defined"
OutputFileMessage:
  .asciz "Error writing output file"
OutputBigMessage:
  .asciz "Output file too large"
LargeOperandMessage:
  .asciz "Operand Size too large"
NumOpExpectedMessage:
  .asciz "Numeric Operand Expected"
InvalidAddrMode:
  .asciz "Invalid addressing mode"
OperandExpectedMessage:
  .asciz "Operand Expected Message"
ImmediateOpsMessage:
  .asciz "Immediate Operands not allowed here"
MemoryOperandMessage:
  .asciz "Memory operand Not allowed here"
JumpErrorMessage:
  .asciz "Relative Jump out of range"
IncludeFileErrorMessage:
  .asciz "Can't find include file"
InvalidOperandMessage:
  .asciz "Invalid Operand"
ATVErrorMessage:
  .asciz "Expression can not be evaluated"
NonZeroMessage:
  .asciz "Expression evaluates to non-zero value"
MissingQuoteMessage:
  .asciz "Error in character constant - missing quote"

CommaMessage:
  .asciz ","
ColonMessage:
  .asciz ":"
QuotesMessage:
  .byte 34		|double quotes
  .byte 0
DisplacementMessage:
  .asciz "displacement"
MemOperandMessage:
  .asciz "Memory Operand"
RegOperandMessage:
  .asciz "Register Operand"
RegOrMemMessage:
  .asciz "Register or Memory Operand"

InputFileHandle:
  .word 0
InputLineNumber:
  .word 1
OutputFileHandle:
  .word 0
ListFileHandle:
  .word 0
SavedStackPointer:
  .word 0
InputBufferReadPtr:
  .word 0
InputBufferEndPtr:
  .word 0
InputBuffer:
  .zerow   BufferSize / 2
InputWord:
  .zerow   WordSize / 2
BackupWord:
  .zerow  WordSize / 2
