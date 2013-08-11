////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Imports data from the exchange message file.
//
// Parameters:
//  Cancel – Boolean – cancel flag. It is set to True if errors occur during the
//           procedure execution.
// 
Procedure ExecuteDataImport(Cancel) Export
	
	If Not IsDistributedInfoBaseNode() Then
		
		// The exchange must follow conversion rules
		AddExchangeFinishEventLogMessage(Cancel,, DataExchangeKindError());
		Return;
	EndIf;
	
	XMLReader = New XMLReader;
	
	Try
		XMLReader.OpenFile(ExchangeMessageFileName());
	Except
		
		// Error opening the exchange message file
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	ReadExchangeMessageFile(Cancel, XMLReader);
	
	XMLReader.Close();
	XMLReader = Undefined;
	
EndProcedure

// Exports data to the exchange message file.
//
// Parameters:
// Cancel – Boolean – cancel flag. It is set to True if errors occur during the
// procedure execution.
// 
Procedure ExecuteDataExport(Cancel) Export
	
	If Not IsDistributedInfoBaseNode() Then
		
		// An exchange must follow conversion rules
		AddExchangeFinishEventLogMessage(Cancel,, DataExchangeKindError());
		Return;
	EndIf;
	
	XMLWriter = New XMLWriter;
	
	Try
		XMLWriter.OpenFile(ExchangeMessageFileName());
	Except
		
		// Error opening the exchange message file
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorOpeningExchangeMessageFile());
		Return;
	EndTry;
	
	WriteChangesToExchangeMessageFile(Cancel, XMLWriter);
	
	XMLWriter.Close();
	XMLWriter = Undefined;
	
EndProcedure

// Passes the string with the full exchange message file name for the data import or
// export to the ExchangeMessageFileNameField local variable.
// Usually, the exchange message file places in the operating system user temporary 
// directory.
//
// Parameters:
//  FileName – String – full exchange message file name for the data import or export.
// 
Procedure SetExchangeMessageFileName(Val FileName) Export
	
	ExchangeMessageFileNameField = FileName;
	
EndProcedure



Procedure ReadExchangeMessageFile(Cancel, XMLReader)
	
	MessageReader = ExchangePlans.CreateMessageReader();
	
	Try
		MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	Except
		
		// The unknown exchange plan is specified;
		// The exchange plan does not contain the specified node;
		// The message number does not match the expected one.
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorStartReadingExchangeMessageFile());
		Return;
	EndTry;
	
	ReadChangesFromExchangeMessageFile(Cancel, MessageReader);
	
	If Cancel Then
		MessageReader.CancelRead();
	Else
		MessageReader.EndRead();
	EndIf;
	
EndProcedure

Procedure ReadChangesFromExchangeMessageFile(Cancel, MessageReader)
	
	Try
		ExchangePlans.ReadChanges(MessageReader, TransactionItemCount);
	Except
		
		// Perhaps exception is raised because metadata change received from the main node
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorReadingExchangeMessageFile());
		
	EndTry;
	
EndProcedure

Procedure WriteChangesToExchangeMessageFile(Cancel, XMLWriter)
	
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	WriteMessage.BeginWrite(XMLWriter, InfoBaseNode);
	
	Try
		ExchangePlans.WriteChanges(WriteMessage, TransactionItemCount);
	Except
		
		// Error writing changes to the exchange messages file
		AddExchangeFinishEventLogMessage(Cancel, ErrorDescription(), ErrorSavingExchangeMessageFile());
	EndTry;
	
	If Cancel Then
		WriteMessage.CancelWrite();
	Else
		WriteMessage.EndWrite();
	EndIf;
	
EndProcedure

Procedure AddExchangeFinishEventLogMessage(Cancel, ErrorDescription = "", ContextErrorDetails = "")
	
	Cancel = True;
	
	Comment = "[ContextErrorDetails]: [ErrorDescription]";
	
	Comment = StrReplace(Comment, "[ContextErrorDetails]", ContextErrorDetails);
	Comment = StrReplace(Comment, "[ErrorDescription]", ErrorDescription);
	
	WriteLogEvent(EventLogMessageKey, EventLogLevel.Error,
		InfoBaseNode.Metadata(), InfoBaseNode, Comment);
	
EndProcedure

Function IsDistributedInfoBaseNode()
	
	Return DataExchangeCached.IsDistributedInfoBaseNode(InfoBaseNode);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal functions.

Function ExchangeMessageFileName()
	
	If Not ValueIsFilled(ExchangeMessageFileNameField) Then
		
		ExchangeMessageFileNameField = "";
		
	EndIf;
	
	Return ExchangeMessageFileNameField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Execution context error details.

Function ErrorOpeningExchangeMessageFile()
	
	Return NStr("en = 'Error opening the exchange message file.'");
	
EndFunction

Function ErrorStartReadingExchangeMessageFile()
	
	Return NStr("en = 'Error when reading the exchange message file started.'");
	
EndFunction

Function ErrorReadingExchangeMessageFile()
	
	Return NStr("en = 'Error reading the exchange message file.'");
	
EndFunction

Function ErrorSavingExchangeMessageFile()
	
	Return NStr("en = 'Error saving the exchange message file.'");
	
EndFunction

Function DataExchangeKindError()
	
	Return NStr("en = 'The exchange must follow conversion rules.'");
	
EndFunction
