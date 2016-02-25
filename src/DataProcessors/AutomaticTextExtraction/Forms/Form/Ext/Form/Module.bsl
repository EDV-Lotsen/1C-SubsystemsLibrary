
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If CommonUseClientServer.IsWebClient() Or CommonUseClientServer.IsLinuxClient() Then
		Return; // Cancel is set in OnOpen().
	EndIf;
	
	TextExtractionEnabled = False;
	
	ExecutionTimeInterval = CommonUse.CommonSettingsStorageLoad("AutomaticTextExtraction", "ExecutionTimeInterval");
	If ExecutionTimeInterval = 0 Then
		ExecutionTimeInterval = 60;
		CommonUse.CommonSettingsStorageSave("AutomaticTextExtraction", "ExecutionTimeInterval",  ExecutionTimeInterval);
	EndIf;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDetermineCountOfVersionsWithUnextractedText");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineCountOfVersionsWithUnextractedText(UnextractedTextFileNumber);
	EndDo;
	
	FileNumberInBlock = CommonUse.CommonSettingsStorageLoad("AutomaticTextExtraction", "FileNumberInBlock");
	If FileNumberInBlock = 0 Then
		FileNumberInBlock = 100;
		CommonUse.CommonSettingsStorageSave("AutomaticTextExtraction", "FileNumberInBlock",  FileNumberInBlock);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClientServer.IsWebClient() Then
		Cancel = True;
		ShowMessageBox(, NStr("en = 'Text extraction is not supported for the Web client.'"));
		Return;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Cancel = True;
		MessageText = NStr("en = 'Text extraction is not available for the Linux client.'");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecutionTimeIntervalOnChange(Item)
	
	CommonUseServerCall.CommonSettingsStorageSave("AutomaticTextExtraction", "ExecutionTimeInterval",  ExecutionTimeInterval);
	
	If TextExtractionEnabled Then
		DetachIdleHandler("TextExtractionClientHandler");
		// Here CurrentDate is not recorded in the database and shown in the client 
		// for informing only, so it need not be replaced with CurrentSessionDate.
		ExpectedExtractionStartTime = CurrentDate() + ExecutionTimeInterval;
		AttachIdleHandler("TextExtractionClientHandler", ExecutionTimeInterval);
		CountdownUpdate();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FileNumberInBlockOnChange(Item)
	CommonUseServerCall.CommonSettingsStorageSave("AutomaticTextExtraction", "FileNumberInBlock", 
FileNumberInBlock);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Start(Command)
	
	TextExtractionEnabled = True; 
	
	// Here CurrentDate is not recorded in the database and shown in the client 
	// for informing only, so it need not be replaced with CurrentSessionDate.
	ExpectedExtractionStartTime = CurrentDate();
	AttachIdleHandler("TextExtractionClientHandler", ExecutionTimeInterval);
	
#If Not WebClient Then
	TextExtractionClientHandler();
#EndIf
	
	AttachIdleHandler("CountdownUpdate", 1);
	CountdownUpdate();
	
EndProcedure

&AtClient
Procedure Stop(Command)
	ExecuteStop();
EndProcedure

&AtClient
Procedure ExtractAll(Command)
	
	#If Not WebClient Then
		UnextractedTextFileNumberBeforeOperation = UnextractedTextFileNumber;
		Status = "";
		PortionSize = 0; // extract all
		TextExtractionClient(PortionSize);
		
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Text extraction
			         |is completed for all applicable files.
			         |
			         |Files processed: %1.'"),
			UnextractedTextFileNumberBeforeOperation));
	#EndIf
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServerNoContext
Procedure EventLogRecordServer(MessageText)
	
	WriteLogEvent(
		NStr("en = 'Files.Text extraction'",
		     CommonUseClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,
		,
		,
		MessageText);
	
EndProcedure

&AtClient
Procedure CountdownUpdate()
	
	// Here CurrentDate is not recorded in the database and shown in the client 
	// for informing only, so it need not be replaced with CurrentSessionDate.
	Left = ExpectedExtractionStartTime - CurrentDate();
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Text extraction starts in %1 sec'"),
		Left);
	
	If Left <= 1 Then
		MessageText = "";
	EndIf;
	
	ExecutionTimeInterval = Items.ExecutionTimeInterval.EditText;
	Status = MessageText;
	
EndProcedure

&AtClient
Procedure TextExtractionClientHandler()
	
#If Not WebClient Then
	TextExtractionClient();
#EndIf

EndProcedure

#If Not WebClient Then
// Extracts text from files on the client hard disk.
&AtClient
Procedure TextExtractionClient(PortionSize = Undefined)
	
	// Here CurrentDate is not recorded in the database and shown in the client 
	// for informing only, so it need not be replaced with CurrentSessionDate.
	ExpectedExtractionStartTime = CurrentDate() + ExecutionTimeInterval;
	
	Status(NStr("en = 'Text extraction is started'"));
	
	Try
		
		PortionSizeCurrent = FileNumberInBlock;
		If PortionSize <> Undefined Then
			PortionSizeCurrent = PortionSize;
		EndIf;
		FileArray = GetFilesForTextExtraction(PortionSizeCurrent);
		
		If FileArray.Count() = 0 Then
			Status(NStr("en = 'No files for text extraction'"));
			Return;
		EndIf;
		
		For Index = 0 To FileArray.Count() - 1 Do
			
			Extension = FileArray[Index].Extension;
			FileDescription = FileArray[Index].Description;
			FileOrFileVersion = FileArray[Index].Ref;
			Encoding = FileArray[Index].Encoding;
			
			Try
				FileURL = GetFileURL(
					FileOrFileVersion, UUID);
				
				NameWithExtension = CommonUseClientServer.GetNameWithExtension(
					FileDescription, Extension);
				
				Progress = Index * 100 / FileArray.Count();
				Status(NStr("en = 'File text extraction is in process'"), Progress, NameWithExtension);
				
				FileFunctionsInternalClient.ExtractVersionText(
					FileOrFileVersion, FileURL, Extension, UUID, Encoding);
			
			Except
				
				ErrorDescriptionInfo = BriefErrorDescription(ErrorInfo());
				
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Text extraction from the %1 file:
					           |unknown error.'"),
					String(FileOrFileVersion));
				
				MessageText = MessageText + String(ErrorDescriptionInfo);
				
				Status(MessageText);
				
				ExtractionResult = "FailedExtraction";
				ExtractionErrorRecord(FileOrFileVersion, ExtractionResult, MessageText);
				
			EndTry;
			
		EndDo;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Text extraction is done.
			           |Files processed: %1'"),
			FileArray.Count());
		
		Status(MessageText);
		
	Except
		
		ErrorDescriptionInfo = BriefErrorDescription(ErrorInfo());
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Text extraction from the %1 file:
			           |unknown error.'"),
			String(FileOrFileVersion));
		
		MessageText = MessageText + String(ErrorDescriptionInfo);
		
		Status(MessageText);
		
		EventLogRecordServer(MessageText);
		
	EndTry;
	
	GetUnextractedTextVersionNumber(UnextractedTextFileNumber);
	
EndProcedure
#EndIf

&AtServerNoContext
Procedure ExtractionErrorRecord(FileOrFileVersion, ExtractionResult, MessageText)
	
	SetPrivilegedMode(True);
	
	FileFunctionsInternal.RecordTextExtractionResult(FileOrFileVersion, ExtractionResult, "");
	
	// recording to the event log
	EventLogRecordServer(MessageText);
	
EndProcedure

&AtServerNoContext
Function GetFilesForTextExtraction(FileNumberInBlock)
	
	Result = New Array;
	
	Query = New Query;
	GetAllFiles = (FileNumberInBlock = 0);
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDefineQueryTextForTextExtraction");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefineQueryTextForTextExtraction(Query.Text, GetAllFiles);
	EndDo;
	
	For Each Row In Query.Execute().Unload() Do
		
		Encoding = FileFunctionsInternal.GetFileVersionEncoding(Row.Ref);
		
		Result.Add(New Structure("Ref, Extension, Description, Encoding",
			Row.Ref, Row.Extension, Row.Description, Encoding));
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetFileURL(Val FileOrFileVersion, Val UUID)
	
	FileURL = Undefined;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDefineFileURL");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefineFileURL(
			FileOrFileVersion, UUID, FileURL);
	EndDo;
	
	Return FileURL;
	
EndFunction

&AtServerNoContext
Procedure GetUnextractedTextVersionNumber(UnextractedTextFileNumber)
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDetermineCountOfVersionsWithUnextractedText");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDetermineCountOfVersionsWithUnextractedText(
			UnextractedTextFileNumber);
	EndDo;
	
EndProcedure

&AtClient
Procedure ExecuteStop()
	DetachIdleHandler("TextExtractionClientHandler");
	DetachIdleHandler("CountdownUpdate");
	Status = "";
	TextExtractionEnabled = False;
EndProcedure

#EndRegion
