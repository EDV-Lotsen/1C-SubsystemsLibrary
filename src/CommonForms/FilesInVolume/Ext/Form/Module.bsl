
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Volume = Parameters.Volume;
	
	// Determining available file storages.
	FillFileStorageNames();
	
	If FileStorageNames.Count() = 0 Then
		Raise NStr("en = 'File storages are not found.'");
		
	ElsIf FileStorageNames.Count() = 1 Then
		Items.FileStoragePresentation.Visible = False;
	EndIf;
	
	FileStorageName = CommonUse.CommonSettingsStorageLoad(
		"CommonForm.FilesInVolume.FilterByStorages", 
		String(Volume.UUID()) );
	
	If FileStorageName = ""
	 Or FileStorageNames.FindByValue(FileStorageName) = Undefined Then
	
		FileVersionItem = FileStorageNames.FindByValue("FileVersions");
		
		If FileVersionItem = Undefined Then
			FileStorageName = FileStorageNames[0].Value;
			FileStoragePresentation = FileStorageNames[0].Presentation;
		Else
			FileStorageName = FileVersionItem.Value;
			FileStoragePresentation = FileVersionItem.Presentation;
		EndIf;
	Else
		FileStoragePresentation = FileStorageNames.FindByValue(FileStorageName).Presentation;
	EndIf;
	
	SetupDynamicList(FileStorageName);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If SaveStorageFilterSettings Then
		SaveSelectionSettings(Volume, FileStorageName);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FileStoragePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("FileStoragePresentationStartChoiceSelectionMade", ThisObject);
	ShowChooseFromList(NotifyDescription, FileStorageNames, Items.FileStoragePresentation,
		FileStorageNames.FindByValue(FileStorageName));
		
EndProcedure

&AtClient
Procedure FileStoragePresentationStartChoiceSelectionMade(CurrentStorage, AdditionalParameters) Export
	
	If TypeOf(CurrentStorage) = Type("ValueListItem") Then
		FileStorageName = CurrentStorage.Value;
		FileStoragePresentation = CurrentStorage.Presentation;
		SetupDynamicList(FileStorageName);
		SaveStorageFilterSettings = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenFileCard();
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	OpenFileCard();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetupDynamicList(Val StorageName)
	
	QueryText =
	"SELECT
	|	FileStorage.Ref AS Ref,
	|	FileStorage.PictureIndex AS PictureIndex,
	|	FileStorage.PathToFile AS PathToFile,
	|	FileStorage.Size AS Size,
	|	FileStorage.Author AS Author,
	|	&AreAttachedFiles AS AreAttachedFiles
	|FROM
	|	&CatalogName AS FileStorage
	|WHERE
	|	FileStorage.Volume = &Volume";
	
	QueryText = StrReplace(QueryText, "&CatalogName", "Catalog." + 
StorageName);
	QueryText = StrReplace(QueryText, "&AreAttachedFiles", ?(
		Upper(StorageName) = Upper("FileVersions"), "FALSE", "TRUE"));
	
	List.QueryText = QueryText;
	List.Parameters.SetParameterValue("Volume", Volume);
	List.MainTable = "Catalog." + StorageName;
	
EndProcedure

&AtServer
Procedure FillFileStorageNames()
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileOperations") Then
		MetadataCatalogs = Metadata.Catalogs;
		//PARTIALLY_DELETED
		//FileStorageNames.Add(MetadataCatalogs.FileVersions.Name, MetadataCatalogs.FileVersions.Presentation());
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AttachedFiles") Then
		For Each Catalog In Metadata.Catalogs Do
			If Right(Catalog.Name, 19) = "AttachedFiles" Then
				FileStorageNames.Add(Catalog.Name, Catalog.Presentation());
			EndIf;
		EndDo;
	EndIf;
	
	FileStorageNames.SortByPresentation();
	
EndProcedure

&AtServerNoContext
Procedure SaveSelectionSettings(Volume, CurrentSettings)
	
	CommonUse.CommonSettingsStorageSave(
		"CommonForm.FilesInVolume.FilterByStorages",
		String(Volume.UUID()),
		CurrentSettings);
	
EndProcedure

&AtClient
Procedure OpenFileCard()
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AreAttachedFiles Then
		If CommonUseClient.SubsystemExists("AttachedFiles") Then
			ModuleAttachedFilesClient = CommonUseClient.CommonModule("AttachedFilesClient");
			ModuleAttachedFilesClient.OpenAttachedFileForm(CurrentData.Ref);
		EndIf;
	Else
		ShowValue(, CurrentData.Ref);
	EndIf;
	
EndProcedure

#EndRegion
