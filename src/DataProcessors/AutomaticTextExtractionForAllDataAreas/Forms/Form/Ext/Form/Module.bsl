#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If CommonUseClientServer.IsWebClient() Or CommonUseClientServer.IsLinuxClient() Then
		Return; // Cancel is set in OnOpen().
	EndIf;
	
	ExecutionTimeInterval = CommonUse.CommonSettingsStorageLoad("AutomaticTextExtraction", "ExecutionTimeInterval");
	If ExecutionTimeInterval = 0 Then
		ExecutionTimeInterval = 60;
		CommonUse.CommonSettingsStorageSave("AutomaticTextExtraction", "ExecutionTimeInterval", ExecutionTimeInterval);
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

	// Here CurrentDate is not recorded in the database and shown in the client 
	// for informing only, so it need not be replaced with CurrentSessionDate.
	ExpectedExtractionStartTime = CurrentDate() + ExecutionTimeInterval;
	AttachIdleHandler("TextExtractionClientHandler", ExecutionTimeInterval);
	
	AttachIdleHandler("CountdownUpdate", 1);
	CountdownUpdate();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ExecutionTimeIntervalOnChange(Item)
	
	CommonUseServerCall.CommonSettingsStorageSave("AutomaticTextExtraction", "ExecutionTimeInterval", ExecutionTimeInterval);
	DetachIdleHandler("TextExtractionClientHandler");
	
	// Here CurrentDate is not recorded in the database and shown in the client 
	// for informing only, so it need not be replaced with CurrentSessionDate.
	ExpectedExtractionStartTime = CurrentDate() + ExecutionTimeInterval;
	
	AttachIdleHandler("TextExtractionClientHandler", ExecutionTimeInterval);
	CountdownUpdate();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunNow(Command)
#If Not WebClient Then
	TextExtractionClientHandler();
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

&AtServerNoContext
Function GetAllDataAreasInUse()
	
	DataAreaArray = New Array;
	
	Query = New Query;
	
	Query.Text = "SELECT
	               |	DataAreas.DataAreaAuxiliaryData AS DataArea
	               |FROM
	               |	InformationRegister.DataAreas AS DataAreas
	               |WHERE
	               |	DataAreas.Status = &Status";
	
	Query.SetParameter("Status", Enums.DataAreaStatuses.Used);
	
	For Each Row In Query.Execute().Unload() Do
		DataAreaArray.Add(Row.DataArea);
	EndDo;
	
	Return DataAreaArray;
	
EndFunction

// Countdown is being updated
//
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

#If Not WebClient Then

// Extracts text from files on the client hard disk.
//
&AtClient
Procedure TextExtractionClientHandler()
	TextExtractionClient();
EndProcedure

// Extracts text from files on the client hard disk.
//
&AtClient
Procedure TextExtractionClient()
	
	DataAreaArray = GetAllDataAreasInUse();
	
	Try
	
		UnextractedTextFileFullNumber = 0;
		UnextractedNumberForArea = New Map;
		
		// Number of all areas files with
		// unextracted text is counted on the first-priority basis.
		For Each Area In DataAreaArray Do
			
			CommonUseServerCall.SetSessionSeparation(True, Area);
			UnextractedTextFileNumber = 0;
			
			GetUnextractedTextVersionNumber(UnextractedTextFileNumber);
			
			UnextractedTextFileFullNumber = UnextractedTextFileFullNumber + UnextractedTextFileNumber;
			UnextractedNumberForArea.Insert(Area, UnextractedTextFileNumber);
			CommonUseServerCall.SetSessionSeparation(False);
		
		EndDo;
		
		NumberInBlock = 100;
		
		// An exception call for each field.
		AreaNumber = DataAreaArray.Count();
		For Each Region In DataAreaArray Do
			
			UnextractedNumber = UnextractedNumberForArea.Get(Area);
			If UnextractedNumber <> Undefined And UnextractedNumber <> 0 Then
				
				PortionSizeForArea = Round((UnextractedNumber / UnextractedTextFileFullNumber)	* NumberInBlock);
				If PortionSizeForArea = 0 Then
					PortionSizeForArea = 1;
				EndIf;
			
				CommonUseServerCall.SetSessionSeparation(True, Region);
				SingleDataAreaTextExtraction(PortionSizeForArea);
				CommonUseServerCall.SetSessionSeparation(False);
			EndIf;
		
		EndDo;
		
		// Return to the shared mode.
		CommonUseServerCall.SetSessionSeparation(False);
	
	Except
	
		// Return to the shared mode.
		CommonUseServerCall.SetSessionSeparation(False);
		Raise;
	
	EndTry;
	
EndProcedure

// Extracts text from files on the client hard disk.
//
// Parameters:
// PortionSize - Number - Number of files in a portion.
//
&AtClient
Procedure SingleDataAreaTextExtraction(PortionSize = Undefined)
	
	// Here CurrentDate is not recorded in the database and shown in the client 
	// for informing only, so it need not be replaced with CurrentSessionDate.
	ExpectedExtractionStartTime = CurrentDate() + ExecutionTimeInterval;
	
	Status(NStr("en = 'Text extraction is started'"));
	
	Try
		
		PortionSizeCurrent = 100;
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
			FileOrFileVersion = FileArray[Index].Ref;
			
			FileURL = GetFileURL(
				FileOrFileVersion, UUID);
			
			Progress = Index * 100 / FileArray.Count();
			Status(NStr("en = 'File text extraction is in process'"), Progress, String(FileOrFileVersion));
			
			FileFunctionsInternalClient.ExtractVersionText(
				FileOrFileVersion, FileURL, Extension, UUID);
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
	
EndProcedure

#EndIf

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
		
		Result.Add(New Structure("Ref, Extension", Row.Ref, Row.Extension));
		
		// exiting, if the necessary number of results is exceeded
		If FileNumberInBlock <> 0 And Result.Count() >= FileNumberInBlock Then
			Break;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetFileURL(Val FileOrFileVersion, Val UUID)
	
	FileURL = Undefined;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.FileFunctions\OnDefineFileURL");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnDefineFileURL(FileOrFileVersion, UUID, FileURL);
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

#EndRegion