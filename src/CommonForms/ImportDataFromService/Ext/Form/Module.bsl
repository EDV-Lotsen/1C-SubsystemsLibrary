///////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure OpenActiveUsersForm(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Load(Command)
	
	NotifyDescription = New NotifyDescription("ContinueDataImport", ThisObject);
	BeginPutFile(NotifyDescription, , "data_dump.zip");
	
EndProcedure

&AtClient
Procedure ContinueDataImport(SelectionDone, StorageAddress, SelectedFileName, AdditionalParameters) Export
	
	If SelectionDone Then
		
		Status(
			NStr("en = 'Importing data from the service.
                  |This could take a long time, please wait...'"),);
		
		ExecuteImport(StorageAddress, ImportUserDetails);
		Terminate(True);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServerNoContext
Procedure ExecuteImport(Val FileURL, Val ImportUserDetails)
	
	ArchiveData = GetFromTempStorage(FileURL);
	ArchiveName = GetTempFileName("zip");
	ArchiveData.Write(ArchiveName);
	ArchiveData = Undefined;
	
	DataAreaExportImport.ImportCurrentDataAreaFromArchive(ArchiveName, ImportUserDetails, True);
	
	Try
		DeleteFiles(ArchiveName);
	Except
		// No additional processing is required. Exceptions may occur on temporary file deletion
	EndTry;
	
EndProcedure





