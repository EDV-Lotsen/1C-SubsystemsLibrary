
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("CommandProcessingEnd1", ThisObject), NStr("en = 'Do you want to import details for all users?'"), QuestionDialogMode.YesNoCancel, ,
		DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure CommandProcessingEnd1(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	AddressInStorage = Undefined;
	BeginPutFile(New NotifyDescription("CommandProcessingEnd", ThisObject, New Structure("AddressInStorage, Response", AddressInStorage, Response)), AddressInStorage, "*.zip",,);

EndProcedure

&AtClient
Procedure CommandProcessingEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	AddressInStorage = AdditionalParameters.AddressInStorage;
	Response = AdditionalParameters.Response;
	
	
	If Not Result Then
		Return;
	EndIf;
	
	ImportDataAtServer(AddressInStorage, Response = DialogReturnCode.Yes);
	
	RefreshInterface();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure ImportDataAtServer(Val AddressInStorage, Val ImportUsers)
	
	ArchiveData = GetFromTempStorage(AddressInStorage);
	ArchiveName = GetTempFileName("zip");
	ArchiveData.Write(ArchiveName);
	ArchiveData = Undefined;
	
	DataImportExport.ImportCurrentAreaFromArchive(ArchiveName, True, ImportUsers);
	
	Try
		DeleteFiles(ArchiveName);
	Except
		
	EndTry;
	
EndProcedure