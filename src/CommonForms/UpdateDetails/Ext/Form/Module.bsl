////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseCached.DataSeparationEnabled() Then
		DontShowUpdateDetails = CommonUse.CommonSettingsStorageLoad("UpdateInfoBase", 
			"DontShowUpdateDetails");
		If DontShowUpdateDetails = Undefined Then
			ShowOnNextUpdates = True;
		Else
			ShowOnNextUpdates = Not DontShowUpdateDetails;
		EndIf;
	EndIf;
	
	ExecutedUpdateHandlers = Undefined;
	If IsBlankString(Parameters.ExecutedUpdateHandlers) Then
		If CommonUseCached.DataSeparationEnabled()
			And CommonUseCached.CanUseSeparatedData() Then
			
			ExecutedUpdateHandlers = CommonUse.CommonSettingsStorageLoad("UpdateInfoBase", 
				"ExecutedHandlers");
		EndIf;
	Else
		ExecutedUpdateHandlers = GetFromTempStorage(Parameters.ExecutedUpdateHandlers);
	EndIf;
	
	If ExecutedUpdateHandlers = Undefined Then
		DocumentUpdateDetails = Metadata.CommonTemplates.Find("UpdateDetails");
		If DocumentUpdateDetails <> Undefined Then
			DocumentUpdateDetails = GetCommonTemplate(DocumentUpdateDetails);
		Else	
			DocumentUpdateDetails = New SpreadsheetDocument();
		EndIf;
	Else
		DocumentUpdateDetails = InfoBaseUpdate.DocumentUpdateDetails(ExecutedUpdateHandlers);
	EndIf;

	If DocumentUpdateDetails.TableHeight = 0 Then
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Configuration is successfully updated to version %1'"), Metadata.Version);
		DocumentUpdateDetails.Area("R1C1:R1C1").Text = Text;
	EndIf;
	InfoBaseUpdateOverridable.OnPrepareUpdateDetailsTemplate(DocumentUpdateDetails);
	UpdateDetails.Clear();
	UpdateDetails.Put(DocumentUpdateDetails);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If CommonUseCached.DataSeparationEnabled() Then
		WriteCurrentSettings(ShowOnNextUpdates);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure UpdateDetailsChoice(Item, Area, StandardProcessing)
	
	If Find(Area.Text, "http://") = 1 Then
		RunApp(Area.Text);
	EndIf;
	InfoBaseUpdateClientOverridable.OnUpdateDetailDocumentHyperlinkClick(Area);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServerNoContext
Procedure WriteCurrentSettings(Val ShowOnNextUpdates)
	
	CommonUse.CommonSettingsStorageDelete("UpdateInfoBase", "ExecutedHandlers", UserName());
	CommonUse.CommonSettingsStorageSave("UpdateInfoBase", "DontShowUpdateDetails",
		Not ShowOnNextUpdates, NStr("en = 'Do not show system change details when updating the infobase version'"));
	
EndProcedure
