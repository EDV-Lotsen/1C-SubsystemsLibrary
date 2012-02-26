
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	TitleModified 		  = False;
	FullTextSearchChanged = False;
	
	If CommonUse.FileInformationBase() Then
		Items.InfobaseAdministrationParameters.Visible = False;
	EndIf;
	
	If Not ConstantsSet.ProhibitFileLoadByExtension Then
		Items.ListOfProhibitedExtensions.Enabled = False;
	EndIf;
	
	Items.RegisterStatus.Title = GetStatusOfAddressClassifier();
	
	RefreshFileStorageVolumes();
	
EndProcedure

&AtClientAtServerNoContext
Function GetStatusOfAddressClassifier()
	
	FilledAddressClassifierUnitsCount = AddressClassifier.FilledAddressClassifierUnitsCount();
	If FilledAddressClassifierUnitsCount > 0 Then
		Title = 
				StringFunctionsClientServer.SubstitureParametersInString(
							NStr("en = 'Objects in address classifier: %1.'"),
							String(FilledAddressClassifierUnitsCount));
	Else
		Title = NStr("en = 'Address classifier not filled'");
	EndIf;
	
	Return Title;
	
EndFunction

&AtClient
Procedure AfterWrite(WriteParameters)
	
	RefreshReusableValues();
	RefreshInterface();
	
	If TitleModified Then
		CommonUseClient.SetArbitraryApplicationTitle();
		TitleModified = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SystemTitleOnChange(Item)
	TitleModified = True;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	// If constant "FunctionalOptionUseCharacteristics" is enabled,
	// then we cannot uncheck flag Use additional attributes and information.
	If Constants.UseAdditionalAttributes.Get() <> ConstantsSet.UseAdditionalAttributes 
		And NOT ConstantsSet.UseAdditionalAttributes Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = '""Use properties"" flag uncheck prohibited if account parameter ""Use characteristics"" is set!'");	
		Message.Field = "ConstantsSet.UseAdditionalAttributes";
		Message.Message();
		
		ConstantsSet.UseAdditionalAttributes = True;
		Cancellation = True;
		Return;
	EndIf;
	
	FullTextSearchChanged = (CurrentObject.UseFullTextSearch <> Constants.UseFullTextSearch.Get());
	
EndProcedure

&AtClient
Procedure ProhibitFileLoadByExtensionOnChange(Item)
	
	Items.ListOfProhibitedExtensions.Enabled = ConstantsSet.ProhibitFileLoadByExtension;

EndProcedure

&AtClient
Procedure InfobaseAdministrationParameters(Command)
	
	OpenForm("CommonForm.InfobaseServerAdministrationSettings");
	
EndProcedure

&AtClient
Procedure LoadAddressClassifier(Command)
	
	AddressClassifierClient.LoadAddressClassifier();
	
EndProcedure

&AtClient
Procedure ClearAddressClassifier(Command)
	
	AddressClassifierClient.ClearClassifier();
	
EndProcedure

&AtClient
Procedure CheckUpdate(Command)
	
	AddressClassifierClient.CheckAddressClassifierUpdate();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AddressClassifierUpdate" Then
		Items.RegisterStatus.Title = GetStatusOfAddressClassifier();
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If FullTextSearchChanged Then
		FullTextSearchChanged = False;
		IsAllowed = Constants.UseFullTextSearch.Get();
		
		If IsAllowed Then
			FullTextSearch.SetFullTextSearchMode(FullTextMode.Enable);
		Else
			FullTextSearch.SetFullTextSearchMode(FullTextMode.Deny);
		EndIf;
			
	EndIf;	
EndProcedure

&AtServer
Procedure RefreshFileStorageVolumes()
	
	Items.FileStorageVolumes.Enabled = (ConstantsSet.FileStorageType = Enums.FileStorageTypes.VolumesOnHardDisk);
	
EndProcedure

&AtClient
Procedure TypeOfFileStorageOnChange(Item)
	
	RefreshFileStorageVolumes();
	
EndProcedure


