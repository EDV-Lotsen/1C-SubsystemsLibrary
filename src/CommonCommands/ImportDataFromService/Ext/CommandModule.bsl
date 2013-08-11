
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Response = DoQueryBox(NStr("en = 'Do you want to import details for all users?'"), QuestionDialogMode.YesNoCancel, ,
		DialogReturnCode.Yes);
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	AddressInStorage = Undefined;
	If Not PutFile(AddressInStorage, "*.zip") Then
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