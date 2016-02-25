
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If StandardSubsystemsServerCall.ClientParameters().FileInfobase Then
		Items.PathToArchiveWindows.Title = NStr("en = 'For 1C:Enterprise server under Microsoft Windows'"); 
	Else
		Items.PathToArchiveWindows.ChoiceButton = False; 
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure PathToArchiveWindowsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not AttachFileSystemExtension() Then
		FileFunctionsInternalClient.ShowFileSystemExtensionRequiredMessageBox(Undefined);
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	
	Dialog.Title                    = NStr("en = 'Select file'");
	Dialog.FullFileName             = ?(ThisObject.PathToArchiveWindows = "", "files.zip", ThisObject.PathToArchiveWindows);
	Dialog.Multiselect              = False;
	Dialog.Preview                  = False;
	Dialog.CheckFileExist           = True;
	Dialog.Filter                   = NStr("en = 'ZIP archives(*.zip)|*.zip'");
	
	If Dialog.Choose() Then
		
		ThisObject.PathToArchiveWindows = Dialog.FullFileName;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Place(Command)
	
	ClearMessages();
	
	If IsBlankString(PathToArchiveWindows) And IsBlankString(PathToArchiveLinux) Then
		Text = NStr("en = 'Specify the full name
		                  |of the initial image files archive (file *.zip)'");
		CommonUseClientServer.MessageToUser(Text, , "PathToArchiveWindows");
		Return;
	EndIf;
	
	If Not StandardSubsystemsClientCached.ClientParameters().FileInfobase Then
	
		If Not IsBlankString(PathToArchiveWindows) And (Left(PathToArchiveWindows, 2) <> "\\" Or Find(PathToArchiveWindows, ":") <> 0) Then
			ErrorText = NStr("en = 'Path to initial image files archive
			                       |should have UNC-format (\\servername\resource).'");
			CommonUseClientServer.MessageToUser(ErrorText, , 
"PathToArchiveWindows");
			Return;
		EndIf;
	
	EndIf;
	
	Status(
		NStr("en = 'Data exchange'"),
		,
		NStr("en = 'Initial image files
		           |unpacking and placing are in progress...'"),
		PictureLib.CreateInitialImage);
	
	AddFilesToVolumes();
	
	NotificationText = NStr("en = 'Initial image files
	|unpacking and placing are completed successfully.'");
	ShowUserNotification(NotificationText);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure AddFilesToVolumes()
	
	FileFunctionsInternal.AddFilesToVolumes(PathToArchiveWindows, PathToArchiveLinux);
	
EndProcedure

#EndRegion
