#Region LocalVariables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	RefreshInterface = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure LogOnToDataArea(Command)
	
	If LoggedInDataArea() Then
		
		CompletionHandler = New NotifyDescription(
			"ContinueLogOnToDataAreaAfterBeforeExitActions", ThisObject);
		
		SkipExitConfirmation = True;
		StandardSubsystemsClient.BeforeExit(, CompletionHandler);
	Else
		LogOnToDataAreaAfterLogOff();
	EndIf;
	
EndProcedure

&AtClient
Procedure LogOffFromDataArea(Command)
	
	If LoggedInDataArea() Then
		
		CompletionHandler = New NotifyDescription(
			"ContinueLogOffFromDataAreaAfterBeforeExitActions", ThisObject);
		
		SkipExitConfirmation = True;
		StandardSubsystemsClient.BeforeExit(, CompletionHandler);
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure RefreshInterfaceIfNecessary()
	
	If RefreshInterface Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueLogOnToDataAreaAfterBeforeExitActions(Result, NotDefined) Export
	
	If Result.Cancel Then
		Activate();
		RefreshInterfaceIfNecessary();
		Return;
	EndIf;
	
	LogOffFromDataAreaAtServer();
	RefreshInterface = True;
	StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	
	LogOnToDataAreaAfterLogOff();
	
EndProcedure

&AtClient
Procedure LogOnToDataAreaAfterLogOff()
	
	If Not IsFilledDataArea(DataArea) Then
		NotifyDescription = New NotifyDescription("LogOnToDataAreaAfterLogOff2", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'The selected data area is not used, do you want to continue logging on?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	LogOnToDataAreaAfterLogOff2();
	
EndProcedure

&AtClient
Procedure LogOnToDataAreaAfterLogOff2(Answer = Undefined, Parameters = Undefined) Export
	
	If Answer = DialogReturnCode.No Then
		RefreshInterfaceIfNecessary();
		Return;
	EndIf;
	
	LogOnToDataAreaAtServer(DataArea);
	
	RefreshInterface = True;
	
	CompletionHandler = New NotifyDescription(
		"ContinueLogOnToDataAreaAfterBeforeStartActions", ThisObject);
	
	StandardSubsystemsClient.BeforeStart(CompletionHandler);
	
EndProcedure

&AtClient
Procedure ContinueLogOnToDataAreaAfterBeforeStartActions(Result, NotDefined) Export
	
	If Result.Cancel Then
		LogOffFromDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
		RefreshInterfaceIfNecessary();
		Activate();
	Else
		CompletionHandler = New NotifyDescription(
			"ContinueLogOnToDataAreaAfterOnStartActions", ThisObject);
		
		StandardSubsystemsClient.OnStart(CompletionHandler);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueLogOnToDataAreaAfterOnStartActions(Result, NotDefined) Export
	
	If Result.Cancel Then
		LogOffFromDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	EndIf;
	
	RefreshInterfaceIfNecessary();
	Activate();
	
EndProcedure

&AtClient
Procedure ContinueLogOffFromDataAreaAfterBeforeExitActions(Result, NotDefined) Export
	
	If Result.Cancel Then
		Return;
	EndIf;
	
	LogOffFromDataAreaAtServer();
	RefreshInterface();
	StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	
	Activate();
	
EndProcedure

&AtServerNoContext
Function IsFilledDataArea(Val DataArea)
	
	SetPrivilegedMode(True);
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.DataAreas");
	LockItem.SetValue("DataAreaAuxiliaryData", DataArea);
	LockItem.Mode = DataLockMode.Shared;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.Status AS Status
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataAreaAuxiliaryData = &DataArea";
	Query.SetParameter("DataArea", DataArea);
	
	BeginTransaction();
	Try
		Lock.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		Return False;
	Else
		Selection = Result.StartChoosing();
		Selection.Next();
		Return Selection.Status = Enums.DataAreaStatuses.Used
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure LogOnToDataAreaAtServer(Val DataArea)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
	BeginTransaction();
	
	Try
		
		AreaKey = SaaSOperations.CreateAuxiliaryDataInformationRegisterRecordKey(
			InformationRegisters.DataAreas,
			New Structure(SaaSOperations.AuxiliaryDataSeparator(), DataArea));
		LockDataForEdit(AreaKey);
		
		Lock = New DataLock;
		Item = Lock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataAreaAuxiliaryData", DataArea);
		Item.Mode = DataLockMode.Shared;
		Lock.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			RecordManager.DataAreaAuxiliaryData = DataArea;
			RecordManager.Status = Enums.DataAreaStatuses.Used;
			RecordManager.Write();
		EndIf;
		UnlockDataForEdit(AreaKey);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure LogOffFromDataAreaAtServer()
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

&AtServerNoContext
Function LoggedInDataArea()
	
	SetPrivilegedMode(True);
	Return CommonUse.UseSessionSeparator();
	
EndFunction

#EndRegion
