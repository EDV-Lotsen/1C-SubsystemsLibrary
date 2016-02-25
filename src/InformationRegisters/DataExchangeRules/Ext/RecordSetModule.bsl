#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	For Each Record In ThisObject Do
		
		If Record.DebugMode Then
			
			ExchangePlanID = CommonUse.MetadataObjectID(Metadata.ExchangePlans[Record.ExchangePlanName]);
			SecurityProfileName = SafeModeInternal.ExternalModuleAttachingMode(ExchangePlanID);
			
			If SecurityProfileName <> Undefined Then
				SetSafeMode(SecurityProfileName);
			EndIf;
			
			IsFileInfobase = CommonUse.FileInfobase();
			
			If Record.ExportDebugMode Then
				
				CheckExternalDataProcessorFileExistence(Record.ExportDebuggingDataProcessorFileName, IsFileInfobase, Cancel);
				
			EndIf;
			
			If Record.ImportDebugMode Then
				
				CheckExternalDataProcessorFileExistence(Record.ImportDebuggingDataProcessorFileName, IsFileInfobase, Cancel);
				
			EndIf;
			
			If Record.DataExchangeLoggingMode Then
				
				CheckExchangeLogFileAvailability(Record.ExchangeLogFileName, Cancel);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure CheckExternalDataProcessorFileExistence(CheckFileName, IsFileInfobase, Cancel)
	
	FileNameStructure = CommonUseClientServer.SplitFullFileName(CheckFileName);
	FileName = FileNameStructure.BaseName;
	CheckDirectoryName	 = FileNameStructure.Path;
	CheckDirectory = New File(CheckDirectoryName);
	FileOnHardDisk = New File(CheckFileName);
	DirectoryLocation = ? (IsFileInfobase, NStr("en = 'on the  client'"), NStr("en = 'on the server'"));
	
	If Not CheckDirectory.Exist() Then
		
		MessageString = NStr("en = 'Directory %1 not found %2.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckDirectoryName, DirectoryLocation);
		Cancel = True;
		
	ElsIf Not FileOnHardDisk.Exist() Then 
		
		MessageString = NStr("en = 'File of external data processor %1 not found %2.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckFileName, DirectoryLocation);
		Cancel = True;
		
	Else
		
		Return;
		
	EndIf;
	
	CommonUseClientServer.MessageToUser(MessageString,,,, Cancel);
	
EndProcedure

Procedure CheckExchangeLogFileAvailability(ExchangeLogFileName, Cancel)
	
	FileNameStructure = CommonUseClientServer.SplitFullFileName(ExchangeLogFileName);
	CheckDirectoryName = FileNameStructure.Path;
	CheckDirectory = New File(CheckDirectoryName);
	CheckFileName = "test.tmp";
	
	If Not CheckDirectory.Exist() Then
		
		MessageString = NStr("en = 'Exchange protocol file directory %1 not found.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not CreateCheckFile(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("en = 'Cannot create a file from the exchange protocol directory: ""%1"".'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not DeleteCheckFiles(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("en = 'Cannot delete a file from the exchange protocol directory: ""%1"".'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	Else
		
		Return;
		
	EndIf;
	
	CommonUseClientServer.MessageToUser(MessageString,,,, Cancel);
	
EndProcedure

Function CreateCheckFile(CheckDirectoryName, CheckFileName)
	
	TextDocument = New TextDocument;
	TextDocument.AddLine(NStr("en = 'Temporary file for checking access to directory'"));
	
	Try
		TextDocument.Write(CheckDirectoryName + "/" + CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function DeleteCheckFiles(CheckDirectoryName, CheckFileName)
	
	Try
		DeleteFiles(CheckDirectoryName, CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf