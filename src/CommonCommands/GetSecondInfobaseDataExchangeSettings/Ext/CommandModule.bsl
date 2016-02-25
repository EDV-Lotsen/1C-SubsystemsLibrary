
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Cancel = False;
	
	TempStorageAddress = "";
	
	GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TempStorageAddress, CommandParameter);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en = 'Error retrieving data exchange settings.'"));
		
	Else
		
		GetFile(TempStorageAddress, NStr("en = 'Synchronization settings.xml'"), True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TempStorageAddress, InfobaseNode)
	
	DataExchangeCreationWizard = DataProcessors.DataExchangeCreationWizard.Create();
	DataExchangeCreationWizard.Initialization(InfobaseNode);
	DataExchangeCreationWizard.ExportWizardParametersToTempStorage(Cancel, TempStorageAddress);
	
EndProcedure

#EndRegion
