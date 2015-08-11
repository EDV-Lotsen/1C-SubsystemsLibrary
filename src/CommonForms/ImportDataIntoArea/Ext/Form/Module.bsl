
////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ContinueDataImport(Command)
	
	If SeparatorExists(SeparatorValue) Then
		Text = NStr("en = 'The specified data area exists. If import will be continued, current data can become damaged.
			|Do you want to continue data import?'");
		Result = Undefined;

		ShowQueryBox(New NotifyDescription("ContinueDataImportEnd1", ThisObject), Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
        Return;
	EndIf;
	
	ContinueDataImportPart();
EndProcedure

&AtClient
Procedure ContinueDataImportEnd1(QuestionResult, AdditionalParameters) Export
	
	Result = QuestionResult;
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ContinueDataImportPart();

EndProcedure

&AtClient
Procedure ContinueDataImportPart()
	
	AddressInStorage = Undefined;
	BeginPutFile(New NotifyDescription("ContinueDataImportEnd", ThisObject), AddressInStorage,,,);

EndProcedure

&AtClient
Procedure ContinueDataImportEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Not Result Then
		Return;
	EndIf;
	
	Status(NStr("en = 'Importing data into the data area'"));
	Try
		ImportDataAtServer(AddressInStorage, SeparatorValue);
		
		Users.AuthenticateCurrentUser();
		
		InfoBaseUpdate.ExecuteInfoBaseUpdate(True);
		
		Cancel = False;
		//
		//StandardSubsystemsClient.ActionsBeforeStart(Cancel);
		//
		//If Cancel Then
		//	ShowMessageBox(,NStr("en = 'Data import completed with errors'"));
		//	Return;
		//EndIf;
		//
		//StandardSubsystemsClient.ActionsOnStart();
		//
		Status(NStr("en = 'Data import completed successfully'"));
	Except
		ShowMessageBox(,BriefErrorDescription(ErrorInfo()));
	EndTry;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure ImportDataAtServer(Val AddressInStorage, SeparatorValue)
	
	ArchiveData = GetFromTempStorage(AddressInStorage);
	ArchiveName = GetTempFileName("zip");
	ArchiveData.Write(ArchiveName);
	ArchiveData = Undefined;
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, SeparatorValue);
	
	If Not SeparatorExists(SeparatorValue) Then
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataArea = SeparatorValue;
		RecordManager.Presentation = SeparatorValue;
		RecordManager.State = Enums.DataAreaStates.Used;
		RecordManager.Write();
	EndIf;
	
	DataImportExport.ImportCurrentAreaFromArchive(ArchiveName);
	
	Try
		DeleteFiles(ArchiveName);
	Except
		WriteLogEvent(NStr("en = 'Deleting temporary files'", Metadata.DefaultLanguage.LanguageCode),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtServer
Function SeparatorExists(SeparatorValue)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DataAreas.DataArea
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataArea = &DataArea";
	Query.SetParameter("DataArea", SeparatorValue);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction