
//////////////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If IsBlankString(Parameters.ExecutedUpdateHandlers) Then
		UpdateDetailsDocument = Metadata.CommonTemplates.Find("UpdateDetails");
		If UpdateDetailsDocument <> Undefined Then
			UpdateDetailsDocument = GetCommonTemplate(UpdateDetailsDocument);
		Else	
			UpdateDetailsDocument = New SpreadsheetDocument();
		EndIf;
	Else	
		ExecutedUpdateHandlers = GetFromTempStorage(Parameters.ExecutedUpdateHandlers);
		UpdateDetailsDocument = InfoBaseUpdate.UpdateDetailsDocument(ExecutedUpdateHandlers);
	EndIf;
	If UpdateDetailsDocument.TableHeight = 0 Then
		Text = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Configuration has been successfully updated to the version %1'"), Metadata.Version);
		UpdateDetailsDocument.Area("R1c1:R1c1").Text = Text;
	EndIf;	
	InfoBaseUpdateOverrided.OnPrepareUpdateDescriptionTemplate(UpdateDetailsDocument);
	UpdatesDetails.Clear();       
	UpdatesDetails.Put(UpdateDetailsDocument);
	
EndProcedure

&AtClient
Procedure UpdatesDetailsSelection(Item, Area, StandardProcessing)
	
	InfoBaseUpdateClientOverrided.OnUpdatesDescriptionDocumentHyperlinkClick(Area);
	
EndProcedure

