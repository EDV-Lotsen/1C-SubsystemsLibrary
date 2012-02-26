

&AtClient
Procedure FilesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	RowSelected = Files[RowSelected].Value;
	
	HowToOpen = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().OnDoubleClickAction;
	If HowToOpen = "ToOpenCard" Then
		Parametes = New Structure("Key", RowSelected);
		OpenFormModal("Catalog.Files.ObjectForm", Parametes);
		Return;
	EndIf;
	
	FileOperationsClient.OpenFile(FileOperations.GetFileDataForOpening(RowSelected, Undefined, Uuid)); 
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	MessageQuestion = Parameters.MessageQuestion;
	MessageTitle 	= Parameters.MessageTitle;
	Title 			= Parameters.Title;
	Files 			= Parameters.Files;
EndProcedure

