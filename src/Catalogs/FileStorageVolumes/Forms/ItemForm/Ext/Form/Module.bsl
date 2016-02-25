&AtClient
Var CurrentWriteParameters;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be recieved if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.FillOrder = FindMaxOrder() + 1;
	Else
		Items.LinuxFullPath.WarningOnEditRepresentation
			= WarningOnEditRepresentation.Show;
		
		Items.WindowsFullPath.WarningOnEditRepresentation
			= WarningOnEditRepresentation.Show;
		
		CurrentSizeInBytes = 0;
		
		FileFunctionsInternal.VolumeFilesSizeOnDefine(
			Object.Ref, CurrentSizeInBytes);
			
		CurrentSize = CurrentSizeInBytes / (1024 * 1024);
		If CurrentSize = 0 And CurrentSizeInBytes <> 0 Then
			CurrentSize = 1;
		EndIf;
	EndIf;
	
	ServerPlatformType = CommonUseCached.ServerPlatformType();
	
	If ServerPlatformType = PlatformType.Windows_x86
	 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Items.WindowsFullPath.AutoMarkIncomplete = True;
	Else
		Items.LinuxFullPath.AutoMarkIncomplete = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not WriteParameters.Property("ExternalResourcesAllowed") Then
		Cancel = True;
		CurrentWriteParameters = WriteParameters;
		AttachIdleHandler("AllowExternalResourceBeginning", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(RefNew) Then
		CurrentObject.SetNewObjectRef(RefNew);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	CurrentObject = FormAttributeToValue("Object");
	
	If FillCheckingAlreadyExecuted Then
		FillCheckingAlreadyExecuted = False;
		CurrentObject.AdditionalProperties.Insert("IgnoreBasicFillingCheck");
	Else
		CurrentObject.AdditionalProperties.Insert("IgnoreDirectoryAccessCheck");
	EndIf;
	
	AttributesToCheck.Clear();
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure WindowsFullPathOnChange(Item)
	
	// Add a slash at the end if there is none
	If Not IsBlankString(Object.WindowsFullPath) Then
		If Right(Object.WindowsFullPath, 1) <> "\" Then
			Object.WindowsFullPath = Object.WindowsFullPath + "\";
		EndIf;
		
		If Right(Object.WindowsFullPath, 2) = "\\" Then
			Object.WindowsFullPath = Left(Object.WindowsFullPath, StrLen(Object.WindowsFullPath) - 1);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure LinuxFullPathOnChange(Item)
	
	// Add a slash at the end if there is none
	If Not IsBlankString(Object.LinuxFullPath) Then
		If Right(Object.LinuxFullPath, 1) <> "\" Then
			Object.LinuxFullPath = Object.LinuxFullPath + "\";
		EndIf;
		
		If Right(Object.LinuxFullPath, 2) = "\\" Then
			Object.LinuxFullPath = Left(Object.LinuxFullPath, StrLen(Object.LinuxFullPath) - 1);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure WriteAndCloseNotification(Result = Undefined, NotDefined = Undefined) Export
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

// Finds maximum order among the volumes
&AtServer
Function FindMaxOrder()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MAX(Volumes.FillOrder) AS MaximumNumber
	|FROM
	|	Catalog.FileStorageVolumes AS Volumes";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If Selection.MaximumNumber = Null Then
			Return 0;
		Else
			Return Number(Selection.MaximumNumber);
		EndIf;
	EndIf;
	
	Return 0;
	
EndFunction

&AtClient
Procedure AllowExternalResourceBeginning()
	
	ExternalResourceQueries = New Array;
	If Not CheckFillingAtServer(ExternalResourceQueries) Then
		Return;
	EndIf;
	
	ClosingNotification = New NotifyDescription(
		"AllowExternalResourceCompletion", ThisObject, CurrentWriteParameters);
	
	SafeModeClient.ApplyExternalResourceRequests(
		ExternalResourceQueries, ThisObject, ClosingNotification);
	
EndProcedure

&AtServer
Function CheckFillingAtServer(ExternalResourceQueries)
	
	If Not CheckFilling() Then
		Return False;
	EndIf;
	
	FillCheckingAlreadyExecuted = True;
	
	If ValueIsFilled(Object.Ref) Then
		ObjectRef = Object.Ref;
	Else
		If Not ValueIsFilled(RefNew) Then
			RefNew = Catalogs.FileStorageVolumes.GetRef();
		EndIf;
		ObjectRef = RefNew;
	EndIf;
	
	ExternalResourceQueries.Add(
		Catalogs.FileStorageVolumes.RequestToUseExternalResourcesForVolume(
			ObjectRef, Object.WindowsFullPath, Object.LinuxFullPath));
	
	Return True;
	
EndFunction

&AtClient
Procedure AllowExternalResourceCompletion(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters.Insert("ExternalResourcesAllowed");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

#EndRegion
