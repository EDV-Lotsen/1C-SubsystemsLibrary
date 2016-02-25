
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Loading the passed parameters
	PassedFormatArray = New Array;
	If Parameters.FormatSettings <> Undefined Then
		PassedFormatArray = Parameters.FormatSettings.SavingFormats;
		PackToArchive = Parameters.FormatSettings.PackToArchive;
	EndIf;
	
	// Filling the list of formats
	For Each SavingFormat In PrintManagement.SpreadsheetDocumentStorageFormatSettings() Do
		Check = False;
		If Parameters.FormatSettings <> Undefined Then 
			PassedFormat = PassedFormatArray.Find(SavingFormat.SpreadsheetDocumentFileType);
			If PassedFormat <> Undefined Then
				Check = True;
			EndIf;
		EndIf;
		SelectedStorageFormats.Add(SavingFormat.SpreadsheetDocumentFileType, String(SavingFormat.Ref), Check, SavingFormat.Picture);
	EndDo;

EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	If Parameters.FormatSettings <> Undefined And Parameters.FormatSettings.SavingFormats.Count() > 0 Then
		Settings.Delete("SelectedStorageFormats");
		Settings.Delete("PackToArchive");
		Return;
	EndIf;
	
	SavingFormatsFromSettings = Settings["SelectedStorageFormats"];
	If SavingFormatsFromSettings <> Undefined Then
		For Each SelectedFormat In SelectedStorageFormats Do 
			FormatFromSettings = SavingFormatsFromSettings.FindByValue(SelectedFormat.Value);
			SelectedFormat.Check = FormatFromSettings <> Undefined And FormatFromSettings.Check;
		EndDo;
		Settings.Delete("SelectedStorageFormats");
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetFormatSelection();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	ChoiceResult = SelectedFormatSettings();
	NotifyChoice(ChoiceResult);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetFormatSelection()
	
	HasSelectedFormat = False;
	For Each SelectedFormat In SelectedStorageFormats Do
		If SelectedFormat.Check Then
			HasSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not HasSelectedFormat Then
		SelectedStorageFormats[0].Check = True; // The default value is the first item in the list
	EndIf;
	
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
	
	Return Result;
	
EndFunction

#EndRegion
