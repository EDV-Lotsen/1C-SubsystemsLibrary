
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	
	Title = Parameters.Title;
	
	If Parameters.Property("SettingsComposerAddress", SettingsComposerAddress) Then
		// Storage has higher priority
		Data = GetFromTempStorage(SettingsComposerAddress);
 		CompositionSchemaAddress = PutToTempStorage(Data.CompositionSchema, UUID);
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(CompositionSchemaAddress));
		SettingsComposer.LoadSettings(Data.Settings);
	Else
		CompositionSchemaAddress = "";
		SettingsComposer = Parameters.SettingsComposer;
	EndIf;
	
	Parameters.Property("DataPeriod", DataPeriod);
	
	If Parameters.SelectPeriod Then
		ExportForPeriod = True;
	Else
		ExportForPeriod = False;
		// Disabling period selection
		Items.DataPeriod.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetPeriodFilterEnabled();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure DataPeriodClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKCommand(Command)
	NotifyChoice(ChoiceResult());
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure SetPeriodFilterEnabled()
	Items.DataPeriod.Enabled = ExportForPeriod;
EndProcedure

&AtServer
Function ChoiceResult()
	Result = New Structure;
	Result.Insert("ChoiceAction",     Parameters.ChoiceAction);
	Result.Insert("SettingsComposer", SettingsComposer);
	Result.Insert("DataPeriod",       ?(ExportForPeriod, DataPeriod, New StandardPeriod));
	
	Result.Insert("SettingsComposerAddress");
	If Not IsBlankString(SettingsComposerAddress) Then
		Data = New Structure;
		Data.Insert("Settings", SettingsComposer.Settings);
		
		CompositionSchema = ?(IsBlankString(CompositionSchemaAddress), Undefined, GetFromTempStorage(CompositionSchemaAddress));
		Data.Insert("CompositionSchema", CompositionSchema);
		
		Result.SettingsComposerAddress = PutToTempStorage(Data, Parameters.FromStorageAddress);
	EndIf;
		
	Return Result;
EndFunction

#EndRegion
