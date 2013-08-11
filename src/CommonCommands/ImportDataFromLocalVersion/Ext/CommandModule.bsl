
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AddressInStorage = Undefined;
	If Not PutFile(AddressInStorage, "*.zip") Then
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