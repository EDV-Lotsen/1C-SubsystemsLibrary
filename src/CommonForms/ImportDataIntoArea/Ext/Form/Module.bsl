
////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ContinueDataImport(Command)
	
	If SeparatorExists(SeparatorValue) Then
		Text = NStr("en = 'The specified data area exists. If import will be continued, current data can become damaged.
			|Do you want to continue data import?'");
		Result = DoQueryBox(Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		
		If Result = DialogReturnCode.No Then
			Return;
		EndIf;
	EndIf;
	
	AddressInStorage = Undefined;
	If Not PutFile(AddressInStorage) Then
		Return;
	EndIf;
	
	Status(NStr("en = 'Importing data into the data area'"));
	Try
		ImportDataAtServer(AddressInStorage, SeparatorValue);
		
		Users.AuthenticateCurrentUser();
		
		InfoBaseUpdate.ExecuteInfoBaseUpdate(True);
		
		Cancel = False;
		
		StandardSubsystemsClient.ActionsBeforeStart(Cancel);
		
		If Cancel Then
			DoMessageBox(NStr("en = 'Data import completed with errors'"));
			Return;
		EndIf;
		
		StandardSubsystemsClient.ActionsOnStart();
		
		Status(NStr("en = 'Data import completed successfully'"));
	Except
		DoMessageBox(BriefErrorDescription(ErrorInfo()));
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
		WriteLogEvent(NStr("en = 'Deleting temporary files'"),
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