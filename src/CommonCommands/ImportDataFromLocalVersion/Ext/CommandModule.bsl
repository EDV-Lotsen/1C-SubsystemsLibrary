
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AddressInStorage = Undefined;
	BeginPutFile(New NotifyDescription("CommandProcessingEnd", ThisObject, New Structure("AddressInStorage", AddressInStorage)), AddressInStorage, "*.zip",,);
	
EndProcedure

&AtClient
Procedure CommandProcessingEnd(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	AddressInStorage = AdditionalParameters.AddressInStorage;
	
	
	If Not Result Then
		Return;
	EndIf;
	
	ImportDataAtServer(AddressInStorage);
	
	RefreshInterface();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure ImportDataAtServer(Val AddressInStorage)
	
	ArchiveData = GetFromTempStorage(AddressInStorage);
	ArchiveName = GetTempFileName("zip");
	ArchiveData.Write(ArchiveName);
	ArchiveData = Undefined;
	
	DataImportExport.ImportCurrentAreaFromArchive(ArchiveName);
	
	Try
		DeleteFiles(ArchiveName);
	Except
		
	EndTry;
	
EndProcedure