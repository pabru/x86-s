
|Fields of the entry in the symbol table symtab

idname 		= 0	|word pointing to name in the string table
DefFileNameOffset = 2	|word pointing to name of file where defined
DefLineNumber	= 4	|word pointing to line number where defined
Attributes	= 6	|Attributes of the symbol - defined below
Value		= 8	|Value of the variable - only word lengths

size_syment = 10

Calculated	= 0x0008
IsDefined 	= 0x0004
IsFake    	= 0x0002
IsEquate  	= 0x0001
NeverDefined	= 0x0010
NotCalculated	= 0xFFF7
