
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	For Each SavingFormat In PrintManagement.SpreadsheetDocumentStorageFormatSettings() Do
		SelectedStorageFormats.Add(SavingFormat.SpreadsheetDocumentFileType, String(SavingFormat.Ref), False, SavingFormat.Picture);
	EndDo;
	
	RecipientList = Parameters.Recipients;
	If TypeOf(RecipientList) = Type("String") Then
		FillRecipientTableFromStrings(RecipientList);
	ElsIf TypeOf(RecipientList) = Type("ValueList") Then
		FillRecipientTableFromValueList(RecipientList);
	ElsIf TypeOf(RecipientList) = Type("Array") Then
		FillRecipientTableFromStructureArray(RecipientList);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	SavingFormatsFromSettings = Settings["SelectedStorageFormats"];
	If SavingFormatsFromSettings <> Undefined Then
		For Each SelectedFormat In SelectedStorageFormats Do 
			FormatFromSettings = SavingFormatsFromSettings.FindByValue(SelectedFormat.Value);
			If FormatFromSettings <> Undefined Then
				SelectedFormat.Check = FormatFromSettings.Check;
			EndIf;
		EndDo;
		Settings.Delete("SelectedStorageFormats");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetFormatSelection();
	GeneratePresentationForSelectedFormats();
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectAttachmentFormat") Then
		
		If SelectedValue <> DialogReturnCode.Cancel And SelectedValue <> Undefined Then
			SetFormatSelection(SelectedValue.SavingFormats);
			PackToArchive = SelectedValue.PackToArchive;
			GeneratePresentationForSelectedFormats();
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	ChoiceResult = SelectedFormatSettings();
	NotifyChoice(ChoiceResult);
EndProcedure

&AtClient
Procedure SelectAllRecipients(Command)
	SetSelectionForAllRecipients(True);
EndProcedure

&AtClient
Procedure CancelSelectionForAll(Command)
	SetSelectionForAllRecipients(False);
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure AttachmentFormatClick(Item, StandardProcessing)
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("FormatSettings", SelectedFormatSettings());
	OpenForm("CommonForm.SelectAttachmentFormat", OpenParameters, ThisObject);
EndProcedure

#EndRegion

#Region RecipientFormTableItemEventHandlers

&AtClient
Procedure RecipientsBeforeRowChange(Item, Cancel)
	Cancel = True;
	Selected = Not Items.Recipients.CurrentData.Selected;
	For Each SelectedRow In Items.Recipients.SelectedRows Do
		Recipient = Recipients.FindByID(SelectedRow);
		Recipient.Selected = Selected;
	EndDo;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure FillRecipientTableFromStrings(Val RecipientList)
	
	RecipientList = CommonUseClientServer.EmailsFromString(RecipientList);
	
	For Each Recipient In RecipientList Do
		NewRecipient = Recipients.Add();
		NewRecipient.Address = Recipient.Address;
		NewRecipient.Presentation = Recipient.Alias;
		NewRecipient.AddressPresentation = NewRecipient.Address;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillRecipientTableFromValueList(RecipientList)
	
	For Each Recipient In RecipientList Do
		NewRecipient = Recipients.Add();
		NewRecipient.Address = Recipient.Value;
		NewRecipient.Presentation = Recipient.Presentation;
		NewRecipient.AddressPresentation = NewRecipient.Address;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillRecipientTableFromStructureArray(RecipientList)
	
	For Each Recipient In RecipientList Do
		NewRecipient = Recipients.Add();
		FillPropertyValues(NewRecipient, Recipient);
		NewRecipient.AddressPresentation = NewRecipient.Address;
		If Not IsBlankString(Recipient.MailAddressKind) Then
			NewRecipient.AddressPresentation = NewRecipient.AddressPresentation + " (" + Recipient.MailAddressKind + ")";
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetFormatSelection(Val SavingFormats = Undefined)
	
	HasSelectedFormat = False;
	For Each SelectedFormat In SelectedStorageFormats Do
		If SavingFormats <> Undefined Then
			SelectedFormat.Check = SavingFormats.Find(SelectedFormat.Value) <> Undefined;
		EndIf;
			
		If SelectedFormat.Check Then
			HasSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not HasSelectedFormat Then
		SelectedStorageFormats[0].Check = True; // The default value is the first item in the list
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePresentationForSelectedFormats()
	
	AttachmentFormat = "";
	FormatCount = 0;
	For Each SelectedFormat In SelectedStorageFormats Do
		If SelectedFormat.Check Then
			If Not IsBlankString(AttachmentFormat) Then
				AttachmentFormat = AttachmentFormat + ", ";
			EndIf;
			AttachmentFormat = AttachmentFormat + SelectedFormat.Presentation;
			FormatCount = FormatCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	SavingFormats = New Array;
	
	For Each SelectedFormat In SelectedStorageFormats Do
		If SelectedFormat.Check Then
			SavingFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;	
	
	Result = New Structure;
	Result.Insert("PackToArchive", PackToArchive);
	Result.Insert("SavingFormats", SavingFormats);
	Result.Insert("Recipients", SelectedRecipients());
	
	Return Result;
	
EndFunction

&AtClient
Function SelectedRecipients()
	Result = New Array;
	For Each SelectedRecipient In Recipients Do
		If SelectedRecipient.Selected Then
			RecipientStructure = New Structure("Address,Presentation,ContactInformationSource,MailAddressKind");
			FillPropertyValues(RecipientStructure, SelectedRecipient);
			Result.Add(RecipientStructure);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Function SetSelectionForAllRecipients(Selection)
	For Each Recipient In Recipients Do
		Recipient.Selected = Selection;
	EndDo;
EndFunction

#EndRegion
