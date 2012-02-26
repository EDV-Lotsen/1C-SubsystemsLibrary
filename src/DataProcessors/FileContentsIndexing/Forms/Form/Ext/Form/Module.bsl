
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	ExtractionPeriod = CommonUse.CommonSettingsStorageLoad("FileContentsIndexing", "ExtractionPeriod");
	If ExtractionPeriod = 0 Then
		ExtractionPeriod = 60;
		CommonUse.CommonSettingsStorageSave("FileContentsIndexing", "ExtractionPeriod",  ExtractionPeriod);
	EndIf;	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	#If WebClient Then
		Cancellation = True;
		DoMessageBox(NStr("en = 'Text extraction is not kept at web-client.'"));
		Return;
	#EndIf
	
	ExtractionStartTime = CurrentDate() + ExtractionPeriod;
	AttachIdleHandler("ExtractionOfTextsClient", ExtractionPeriod);
	
	AttachIdleHandler("UpdateOfCountdown", 1);
	UpdateOfCountdown();
EndProcedure

&AtClient
Procedure RunTimeIntervalOnChange(Item)
	CommonUse.CommonSettingsStorageSave("FileContentsIndexing", "ExtractionPeriod",  ExtractionPeriod);
	DetachIdleHandler("ExtractionOfTextsClient");
	ExtractionStartTime = CurrentDate() + ExtractionPeriod;
	AttachIdleHandler("ExtractionOfTextsClient", ExtractionPeriod);
	UpdateOfCountdown();
EndProcedure

// updates countdown
&AtClient
Procedure UpdateOfCountdown()
	
	Left1 = ExtractionStartTime - CurrentDate();
	
	TextOfMessage = StringFunctionsClientServer.SubstitureParametersInString(
							 NStr("en = 'Text extraction will start in %1 sec'"), 
							 Left1);
							 
	If Left1 <= 1 Then
		TextOfMessage = "";
	EndIf;
	
	ExtractionPeriod = Items.ExtractionPeriod.EditText;
	Status = TextOfMessage;
	
EndProcedure

// Extracts text from files on disk at client
&AtClient
Procedure ExtractionOfTextsClient()
	#If NOT WebClient Then
	
	ExtractionStartTime = CurrentDate() + ExtractionPeriod;
	
	NameWithFileExtention = "";	
	
	Status(NStr("en = 'Extracting text started'"));
	
	Try	
		VersionsArray = FileOperations.GetVersionsArrayForTextExtraction();
		
		If VersionsArray.Count() = 0 Then
			Status(NStr("en = 'No file to extract the text from!'"));
			Return;
		EndIf;
		
		For IndexOf = 0 To VersionsArray.Count() - 1 Do
			
			VersionRef = VersionsArray[IndexOf];
			
			ReturnStructure = FileOperations.GetFileDataAndVersionURL(, VersionRef, Uuid);
			FileData = ReturnStructure.FileData;
			FileAddress = ReturnStructure.VersionURL;
			
			If FileData.TextExtractionStatus <> "NotExtracted" Then
				
				// for the variant when files are located on disk (at server) - delete file from temporary storage after getting it
				If IsTempStorageURL(FileAddress) Then
					DeleteFromTempStorage(FileAddress);
				EndIf;
				
				Continue; // another client has already processed the file
			EndIf;	
			
			NameWithExtention = FileFunctionsClient.GetNameWithExtention(FileData.FullDescrOfVersion, FileData.Extension);
			NameWithFileExtention = NameWithExtention;
			Progress = IndexOf * 100 / VersionsArray.Count();									 
			Status(NStr("en = 'Extracting text from file'"), Progress, NameWithExtention);
			Extension = FileData.Extension;
			
			FileFunctionsClient.ExtractVersionText(VersionRef, FileAddress, Extension, Uuid);
		EndDo;
		
		TextOfMessage = StringFunctionsClientServer.SubstitureParametersInString(
								 NStr("en = 'Text extaction was completed. Processed files: %1'"), 
								 VersionsArray.Count());
		Status(TextOfMessage);								 
		
	Except
		
		ErrorDescriptionInfo = BriefErrorDescription(ErrorInfo());
		TextOfMessage = StringFunctionsClientServer.SubstitureParametersInString(
								 NStr("en = 'An unknown error occurred while extracting text from  file %1'"), 
								 NameWithFileExtention);
		TextOfMessage = TextOfMessage + String(ErrorDescriptionInfo);
		Status(TextOfMessage);
		
		// record to eventlog
		EventLogRecordServer(TextOfMessage);
		
	EndTry;
	
	#EndIf
EndProcedure


&AtServer
Procedure EventLogRecordServer(TextOfMessage)
	
	WriteLogEvent("File text extraction", 
		EventLogLevel.Error, , ,
		TextOfMessage);
	
EndProcedure


&AtClient
Procedure RunNow(Command)
	ExtractionOfTextsClient();
EndProcedure

