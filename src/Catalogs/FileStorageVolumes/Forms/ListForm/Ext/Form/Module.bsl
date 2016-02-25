
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormSetDeletionMark.OnlyInAllActions = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetClearDeletionMark(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	StartDeletionMarkChange(Items.List.CurrentData);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure StartDeletionMarkChange(CurrentData)
	
	If CurrentData.DeletionMark Then
		QuestionText = NStr("en = 'Do you want to clear the deletion mark from ""%1""?'");
	Else
		QuestionText = NStr("en = 'Do you want to mark ""%1"" for deletion?'");
	EndIf;
	
	QuestionContent = New Array;
	QuestionContent.Add(PictureLib.Question32);
	QuestionContent.Add(StringFunctionsClientServer.SubstituteParametersInString(
		QuestionText, CurrentData.Description));
	
	ShowQueryBox(
		New NotifyDescription("ContinueDeletionMarkChange", ThisObject, CurrentData),
		New FormattedString(QuestionContent),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ContinueDeletionMarkChange(Answer, CurrentData) Export
	
	If Answer <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Volume = Items.List.CurrentData.Ref;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Volume", Items.List.CurrentData.Ref);
	AdditionalParameters.Insert("DeletionMark", Undefined);
	AdditionalParameters.Insert("Requests", New Array());
	AdditionalParameters.Insert("FormID", UUID);
	
	PrepareSetClearDeletionMark(Volume, AdditionalParameters);
	
	SafeModeClient.ApplyExternalResourceRequests(
		AdditionalParameters.Requests, ThisObject, New NotifyDescription(
			"ContinueSetClearDeletionMark", ThisObject, AdditionalParameters));
	
EndProcedure

&AtServerNoContext
Procedure PrepareSetClearDeletionMark(Volume, AdditionalParameters)
	
	LockDataForEdit(Volume, , AdditionalParameters.FormID);
	
	VolumeProperties = CommonUse.ObjectAttributeValues(
		Volume, "DeletionMark,WindowsFullPath,LinuxFullPath");
	
	AdditionalParameters.DeletionMark = VolumeProperties.DeletionMark;
	
	If AdditionalParameters.DeletionMark Then
		// Deletion mark is set and must be cleared
		
		Request = Catalogs.FileStorageVolumes.RequestToUseExternalResourcesForVolume(
			Volume, VolumeProperties.WindowsFullPath, VolumeProperties.LinuxFullPath);
	Else
		// Deletion mark is not set and must be set
		Request = SafeMode.RequestForClearingPermissionsForExternalResources(Volume)
	EndIf;
	
	AdditionalParameters.Requests.Add(Request);
	
EndProcedure

&AtClient
Procedure ContinueSetClearDeletionMark(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		EndSetClearDeletionMark(AdditionalParameters);
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure EndSetClearDeletionMark(AdditionalParameters)
	
	Object = AdditionalParameters.Volume.GetObject();
	Object.SetDeletionMark(Not AdditionalParameters.DeletionMark);
	Object.Write();
	
	UnlockDataForEdit(
	AdditionalParameters.Volume, AdditionalParameters.FormID);
	
EndProcedure

#EndRegion