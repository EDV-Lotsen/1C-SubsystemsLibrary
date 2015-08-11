//////////////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If IsBlankString(Parameters.ExecutedUpdateHandlers) Then
		DocumentUpdatesLongDescription = Metadata.CommonTemplates.Find("UpdateDetails");
		If DocumentUpdatesLongDescription <> Undefined Then
			DocumentUpdatesLongDescription = GetCommonTemplate(DocumentUpdatesLongDescription);
		Else	
			DocumentUpdatesLongDescription = New SpreadsheetDocument();
		EndIf;
	Else	
		ExecutedUpdateHandlers = GetFromTempStorage(Parameters.ExecutedUpdateHandlers);
		DocumentUpdatesLongDescription = InfoBaseUpdate.DocumentUpdateDetails(ExecutedUpdateHandlers);
	EndIf;
	If DocumentUpdatesLongDescription.TableHeight = 0 Then
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='The application has been successfully updated to the version %1'"), Metadata.Version);
		DocumentUpdatesLongDescription.Area("R1c1:R1c1").Text = Text;
	EndIf;	
	InfoBaseUpdateOverridable.OnPrepareUpdateDetailsTemplate(DocumentUpdatesLongDescription);
	UpdatesLongDescription.Clear();       
	UpdatesLongDescription.Put(DocumentUpdatesLongDescription);
	
EndProcedure

&AtClient
Procedure UpdatesLongDescriptionSelection(Item, Area, StandardProcessing)
	
	If Find(Area.Text, "http://") = 1 Or Find(Area.Text, "https://") = 1 Then
		BeginRunningApplication(New NotifyDescription("UpdatesLongDescriptionSelectionEnd", ThisObject, New Structure("Area", Area)), Area.Text);
        Return;
	EndIf;
	
	UpdatesLongDescriptionSelectionPart(Area);
EndProcedure

&AtClient
Procedure UpdatesLongDescriptionSelectionEnd(ReturnCode, AdditionalParameters) Export
	
	Area = AdditionalParameters.Area;
	
	
	UpdatesLongDescriptionSelectionPart(Area);

EndProcedure

&AtClient
Procedure UpdatesLongDescriptionSelectionPart(Val Area)
	
	InfoBaseUpdateClientOverridable.OnUpdateDetailDocumentHyperlinkClick(Area);
	
EndProcedure


