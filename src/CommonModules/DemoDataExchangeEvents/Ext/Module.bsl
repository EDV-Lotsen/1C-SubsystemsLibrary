﻿
Procedure DemoExchangeInDIBRecordDocumentChangeBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeWriteDocument("DemoExchangeInDIB", Source, Cancel, WriteMode, PostingMode);
	
EndProcedure

Procedure DemoExchangeInDIBRecordChangeBeforeWrite(Source, Cancel) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeWrite("DemoExchangeInDIB", Source, Cancel);
	
EndProcedure

Procedure DemoExchangeInDIBRecordRecordSetChangesBeforeWrite(Source, Cancel, Replacing) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeWriteRegister("DemoExchangeInDIB", Source, Cancel, Replacing);
	
EndProcedure

Procedure DemoExchangeInDIBRecordConstantChangeBeforeWrite(Source, Cancel) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeWriteConstant("DemoExchangeInDIB", Source, Cancel);
	
EndProcedure

Procedure DemoExchangeInDIBRecordDeletionBeforeDelete(Source, Cancel) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeDelete("DemoExchangeInDIB", Source, Cancel);
	
EndProcedure

Procedure DemoExchangeWithSLRecordChangeBeforeWrite(Source, Cancel) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeWrite("DemoExchangeWithSL", Source, Cancel);
	
EndProcedure

Procedure DemoExchangeWithSLRecordDocumentChangeBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeWriteDocument("DemoExchangeWithSL", Source, Cancel, WriteMode, PostingMode);
	
EndProcedure

Procedure DemoExchangeWithSLDeletionBeforeDelete(Source, Cancel) Export
	
	DataExchangeEvents.ObjectChangeRecordMechanismBeforeDelete("DemoExchangeWithSL", Source, Cancel);
	
EndProcedure
