&AtClient
Var AnswerBeforeClose;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	BackupSettings = 
DataAreaBackup.GetAreaBackupSettings(
		SaaSOperations.SessionSeparatorValue());
	FillPropertyValues(ThisObject, BackupSettings);
	
	For MonthNumber = 1 To 12 Do
		Items.YearlyBackupCreationMonth.ChoiceList.Add(MonthNumber, 
			Format(Date(2, MonthNumber, 1), "DF=MMMM"));
	EndDo;
	
	TimeZone = SessionTimeZone();
	AreaTimeZone = TimeZone + " (" + TimeZonePresentation(TimeZone) + ")";
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not Modified Then
		Return;
	EndIf;
	
	If AnswerBeforeClose <> True Then
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'The settings have been changed. Do you want to save the changes?'"), 
			QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
	EndIf;
		
EndProcedure
		
&AtClient
Procedure BeforeCloseCompletion(Answer, AdditionalParameters) Export	
	
	If Answer = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Answer = DialogReturnCode.Yes Then
		WriteBackupSettings();
	EndIf;
	AnswerBeforeClose = True;
    Close();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetDefault(Command)
	
	SetDefaultAtServer();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteBackupSettings();
	Modified = False;
	Close(DialogReturnCode.OK);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetDefaultAtServer()
	
	BackupSettings = 
DataAreaBackup.GetAreaBackupSettings();
	FillPropertyValues(ThisObject, BackupSettings);
	
EndProcedure

&AtServer
Procedure WriteBackupSettings()

	SettingsMap = 
DataAreaBackupCached.MapBetweenSMSettingsAndAppSettings();
	
	BackupSettings = New Structure;
	For Each KeyAndValue In SettingsMap Do
		BackupSettings.Insert(KeyAndValue.Value, ThisObject
[KeyAndValue.Value]);
	EndDo;
	
	DataAreaBackup.SetAreaBackupSettings(
		SaaSOperations.SessionSeparatorValue(), BackupSettings);
		
EndProcedure

#EndRegion
