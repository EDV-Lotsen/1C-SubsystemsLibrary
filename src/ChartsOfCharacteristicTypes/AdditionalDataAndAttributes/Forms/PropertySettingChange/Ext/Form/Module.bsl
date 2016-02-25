&AtClient
Var LongActionParametersClient;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;

	If Parameters.IsAdditionalData Then
		Items.PropertyTypes.CurrentPage = Items.Data;
		Title = NStr("en = 'Change additional data setting'");
	Else
		Items.PropertyTypes.CurrentPage = Items.Attribute;
	EndIf;
	
	If ValueIsFilled(Parameters.PropertySet) Then
		Items.AttributeKinds.CurrentPage = Items.KindCommonAttributeValues;
		Items.DataKinds.CurrentPage  = Items.KindCommonDataValues;
		
		If ValueIsFilled(Parameters.AdditionalValueOwner) Then
			IndependentPropertyWithCommonValueList = 1;
		Else
			IndependentPropertyWithSpecificValueList = 1;
		EndIf;
	Else
		Items.AttributeKinds.CurrentPage = Items.KindCommonAttribute;
		Items.DataKinds.CurrentPage  = Items.KindCommonData;
		
		CommonProperty = 1;
	EndIf;
	
	Property = Parameters.Property;
	CurrentPropertySet = Parameters.CurrentPropertySet;
	IsAdditionalData = Parameters.IsAdditionalData;
	
	Items.CertainAttributeValuesComment.Title =
		StringFunctionsClientServer.SubstituteParametersInString(
			Items.CertainAttributeValuesComment.Title, CurrentPropertySet);
	
	Items.CommonAttributeValuesComment.Title =
		StringFunctionsClientServer.SubstituteParametersInString(
			Items.CommonAttributeValuesComment.Title, CurrentPropertySet);
	
	Items.CertainDataValuesComment.Title =
		StringFunctionsClientServer.SubstituteParametersInString(
			Items.CertainDataValuesComment.Title, CurrentPropertySet);
	
	Items.CommonDataValuesComment.Title =
		StringFunctionsClientServer.SubstituteParametersInString(
			Items.CommonDataValuesComment.Title, CurrentPropertySet);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure KindOnChange(Item)
	
	KindOnChangeAtServer(Item.Name);
	
EndProcedure

&AtServer
Procedure KindOnChangeAtServer(ItemName)
	
	IndependentPropertyWithCommonValueList = 0;
	IndependentPropertyWithSpecificValueList = 0;
	CommonProperty = 0;
	
	ThisObject[Items[ItemName].DataPath] = 1;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseCompletion();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If IndependentPropertyWithSpecificValueList = 1 Then
		WriteBeginning();
	Else
		WriteEnd(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteBeginning()
	
	Status(NStr("en = 'Changing property settings. Please wait.'"));
	
	OpenProperty = WriteAtServer();
	
	If OpenProperty <> NULL Then
		WriteEnd(OpenProperty);
	Else
		LongActionParametersClient = New Structure;
		LongActionParametersClient.Insert("IdleHandlerParameters");
		
		LongActionsClient.InitIdleHandlerParameters(
			LongActionParametersClient.IdleHandlerParameters);
		
		AttachIdleHandler("Attached_CheckPropertySettingChange",
			LongActionParametersClient.IdleHandlerParameters.MinInterval, True);
		
		LongActionParametersClient.Insert("LongActionForm",
			LongActionsClient.OpenLongActionForm(
				ThisObject, LongActionParameters.JobID));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attached_CheckPropertySettingChange()
	
	Result = NULL;
	
	Try
		If LongActionParametersClient.LongActionForm.IsOpen()
		   And LongActionParametersClient.LongActionForm.JobID
		         = LongActionParameters.JobID Then
			
			Result = JobCompleted(LongActionParameters);
			If Result = NULL Then
				
				LongActionsClient.UpdateIdleHandlerParameters(
					LongActionParametersClient.IdleHandlerParameters);
				
				AttachIdleHandler(
					"Attached_CheckPropertySettingChange",
					LongActionParametersClient.IdleHandlerParameters.CurrentInterval,
					True);
			Else
				LongActionsClient.CloseLongActionForm(
					LongActionParametersClient.LongActionForm);
			EndIf;
		EndIf;
	Except
		LongActionsClient.CloseLongActionForm(
			LongActionParametersClient.LongActionForm);
		Raise;
	EndTry;
	
	If Result <> NULL Then
		WriteEnd(Result);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(LongActionParameters)
	
	If LongActions.JobCompleted(LongActionParameters.JobID) Then
		Return GetFromTempStorage(LongActionParameters.StorageAddress);
	EndIf;
	
	Return NULL;
	
EndFunction

&AtClient
Procedure WriteEnd(OpenProperty)
	
	Modified = False;
	
	Notify("Write_AdditionalDataAndAttributes",
		New Structure("Ref", Property), Property);
	
	Notify("Write_AdditionalDataAndAttributeSets",
		New Structure("Ref", CurrentPropertySet), CurrentPropertySet);
	
	NotifyChoice(OpenProperty);
	
EndProcedure

&AtServer
Function WriteAtServer()
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("Property", Property);
	ProcedureParameters.Insert("CurrentPropertySet", CurrentPropertySet);
	
	If CommonUse.FileInfobase() Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		
		ChartsOfCharacteristicTypes.AdditionalDataAndAttributes.ChangePropertySetting(
			ProcedureParameters, StorageAddress);
		
		Return GetFromTempStorage(StorageAddress);
	EndIf;
	
	JobDescription = NStr("en = 'Changing additional property setting.'");
	
	Result = LongActions.ExecuteInBackground(
		UUID,
		"ChartsOfCharacteristicTypes.AdditionalDataAndAttributes.ChangePropertySetting",
		ProcedureParameters,
		JobDescription);
		
	If Result.JobCompleted Then
		Return GetFromTempStorage(Result.StorageAddress);
	EndIf;
	
	LongActionParameters = Result;
	
	Return NULL;
	
EndFunction

#EndRegion
