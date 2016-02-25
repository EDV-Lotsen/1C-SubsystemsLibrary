&AtClient
Var AnswerBeforeClose;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;
	
	// Form initialization
	For MonthNumber = 1 To 12 Do
		Items.YearlyBackupCreationMonth.ChoiceList.Add(MonthNumber, 
			Format(Date(2, MonthNumber, 1), "DF=MMMM"));
	EndDo;
	
	SetLabelWidth();
	
	ApplySettingRestrictions();
	
	FillFormBySettings(Parameters.SettingsData);
	
EndProcedure

&AtClient
Procedure DailyBackupCountOnChange(Item)
	
	DailyBackupCountLabel = BackupCountLabel(DailyBackupCount);
	
EndProcedure

&AtClient
Procedure MonthlyBackupCountOnChange(Item)
	
	MonthlyBackupCountLabel = BackupCountLabel(MonthlyBackupCount);
	
EndProcedure

&AtClient
Procedure YearlyBackupCountOnChange(Item)
	
	YearlyBackupCountLabel = BackupCountLabel(YearlyBackupCount);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not Modified Then
		Return;
	EndIf;
	
	If AnswerBeforeClose <> True Then
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'Data has been changed. Do you want to save the changes?'"), 
			QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
	EndIf;
		
EndProcedure
		
&AtClient
Procedure BeforeCloseCompletion(Answer, AdditionalParameters) Export	
	
	If Answer = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Answer = DialogReturnCode.Yes Then
		SaveNewSettings();
	EndIf;
	AnswerBeforeClose = True;
    Close();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Reread(Command)
	
	RereadAtServer();
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	SaveNewSettings();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	SaveNewSettings();
	Close();
	
EndProcedure

&AtClient
Procedure SetDefaultSettings(Command)
	
	SetDefaultSettingsAtServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure RereadAtServer()
	
	FillFormBySettings(
		DataAreaBackupFormDataInterface.GetAreaSettings(Parameters.DataArea));
		
	Modified = False;
	
EndProcedure

&AtServer
Procedure FillFormBySettings(Val SettingsData, Val UpdateInitialSettings = True)
	
	FillPropertyValues(ThisObject, SettingsData);
	
	If UpdateInitialSettings Then
		InitialSettings = SettingsData;
	EndIf;
	
	SetAllNumberLabels();
	
EndProcedure

&AtServer
Procedure SetLabelWidth()
	
	MaximumWidth = 0;
	
	NumberForCheck = New Array;
	NumberForCheck.Add(1);
	NumberForCheck.Add(2);
	NumberForCheck.Add(5);
	
	For Each Number In NumberForCheck Do
		LabelWidth = StrLen(BackupCountLabel(Number));
		If LabelWidth > MaximumWidth Then
			MaximumWidth = LabelWidth;
		EndIf;
	EndDo;
	
	LabelItems = New Array;
	LabelItems.Add(Items.DailyBackupCountLabel);
	LabelItems.Add(Items.MonthlyBackupCountLabel);
	LabelItems.Add(Items.YearlyBackupCountLabel);
	
	For Each LabelItem In LabelItems Do
		LabelItem.Width = MaximumWidth;
	EndDo;
	
EndProcedure

&AtServer
Procedure ApplySettingRestrictions()
	
	SettingRestrictions = Parameters.SettingRestrictions;
	
	TooltipPattern = NStr("en = 'Maximum backups: %1'");
	
	RestrictionItems = New Structure;
	RestrictionItems.Insert("DailyBackupCount", "DailyBackupMaximum");
	RestrictionItems.Insert("MonthlyBackupCount", "MonthlyBackupMaximum");
	RestrictionItems.Insert("YearlyBackupCount", "YearlyBackupMaximum");
	
	For Each KeyAndvalue In RestrictionItems Do
		Item = Items[KeyAndvalue.Key];
		Item.MaxValue = SettingRestrictions[KeyAndvalue.Value];
		Item.ToolTip = 
			StringFunctionsClientServer.SubstituteParametersInString(
				TooltipPattern, 
				SettingRestrictions[KeyAndvalue.Value]);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetAllNumberLabels()
	
	DailyBackupCountLabel = BackupCountLabel(DailyBackupCount);
	MonthlyBackupCountLabel = BackupCountLabel(MonthlyBackupCount);
	YearlyBackupCountLabel = BackupCountLabel(YearlyBackupCount);
	
EndProcedure

&AtClientAtServerNoContext
Function BackupCountLabel(Val Quantity)

	PresentationArray = New Array;
	PresentationArray.Add(NStr("en = 'latest backup'"));
	PresentationArray.Add(NStr("en = 'latest backups'"));
	PresentationArray.Add(NStr("en = 'latest backups'"));
	
	If Quantity >= 100 Then
		Quantity = Quantity - Int(Quantity / 100)*100;
	EndIf;
	
	If Quantity > 20 Then
		Quantity = Quantity - Int(Quantity/10)*10;
	EndIf;
	
	If Quantity = 1 Then
		Result = PresentationArray[0];
	ElsIf Quantity > 1 and Quantity < 5 Then
		Result = PresentationArray[1];
	Else
		Result = PresentationArray[2];
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveNewSettings()
	
	NewSettings = New Structure;
	For Each KeyAndValue In InitialSettings Do
		NewSettings.Insert(KeyAndValue.Key, ThisObject[KeyAndValue.Key]);
	EndDo;
	
	NewSettings = New FixedStructure(NewSettings);
	
	DataAreaBackupFormDataInterface.SetAreaSettings(
		Parameters.DataArea,
		NewSettings,
		InitialSettings);
		
	Modified = False;
	InitialSettings = NewSettings;
	
EndProcedure

&AtServer
Procedure SetDefaultSettingsAtServer()
	
	FillFormBySettings(
		DataAreaBackupFormDataInterface.GetStandardSettings(),
		False);
	
EndProcedure

#EndRegion
