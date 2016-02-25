
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 		Return;
	EndIf;
	
	DirectoryForStoringPrintData = PrintManagement.GetPrintFileLocalDirectory();

EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure PathToDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	If AttachFileSystemExtension() Then
		FileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
		FileDialog.FullFileName = "";
		FileDialog.Directory = DirectoryForStoringPrintData;
		FileDialog.Multiselect = False;
		FileDialog.Title = NStr("en = 'Select print file directory.'");
		If FileDialog.Choose() Then
			DirectoryForStoringPrintData = FileDialog.Directory + "\";
		EndIf;
	Else
		ShowMessageBox(, NStr("en = 'To be able to select directory, install the file system extension for the web client.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	PrintManagementServerCall.SaveLocalPrintFileDirectory(DirectoryForStoringPrintData);
	NotifyChoice(DirectoryForStoringPrintData);
	
EndProcedure

#EndRegion
