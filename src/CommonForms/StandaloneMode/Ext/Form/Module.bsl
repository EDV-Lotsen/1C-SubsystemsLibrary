
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
  
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;

	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not StandaloneModeInternal.IsStandaloneWorkstation() Then
		Raise NStr("en = 'The infobase is not a standalone workstation.'");
	EndIf;
	
	ApplicationInSaaS = StandaloneModeInternal.ApplicationInSaaS();
	
	ScheduledJob = ScheduledJobsServer.GetScheduledJob(
		Metadata.ScheduledJobs.DataSynchronizationWithWebApplication);
	
	SynchronizeDataOnSchedule = ScheduledJob.Use;
	DataSynchronizationSchedule      = ScheduledJob.Schedule;
	
	OnChangeDataSynchronizationSchedule();
	
	SynchronizeDataOnStart = Constants.SynchronizeDataWithWebApplicationOnStart.Get();
	SynchronizeDataOnExit = Constants.SynchronizeDataWithWebApplicationOnExit.Get();
	
	AddressForRestoringAccountPassword = StandaloneModeInternal.AddressForRestoringAccountPassword();
	
	SetPrivilegedMode(False);
	
	RefreshVisibilityAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshVisibility", 60);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DataExchangeCompleted" Then
		RefreshVisibility();
		
	ElsIf EventName = "UserSettingsChanged" Then
		RefreshVisibility();
		
	ElsIf EventName = "Write_ExchangeTransportSettings" Then
		
		If Parameter.Property("AutomaticSynchronizationSetup") Then
			SynchronizeDataOnSchedule = True;
			SynchronizeDataOnScheduleOnValueChange();
		EndIf;
		
	ElsIf EventName = "DataExchangeResultFormClosed" Then
		UpdateGoToConflictTitle();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowLongSynchronizationWarningOnChange(Item)
	
	SwitchLongSynchronizationWarning(ShowLongSynchronizationWarning);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PerformDataSynchronization(Command)
	
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(ApplicationInSaaS, ThisObject, AddressForRestoringAccountPassword);
	
EndProcedure

&AtClient
Procedure ChangeDataSynchronizationSchedule(Command)
	
	Dialog = New ScheduledJobDialog(DataSynchronizationSchedule);
	NotifyDescription = New NotifyDescription("ChangeDataSynchronizationScheduleCompletion", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure ChangeDataSynchronizationScheduleCompletion(Schedule, AdditionalParameters)
	
	If Schedule <> Undefined Then
		
		DataSynchronizationSchedule = Schedule;
		
		ChangeDataSynchronizationScheduleAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	
	DataExchangeClient.ExecuteInfobaseUpdate();
	
EndProcedure

&AtClient
Procedure SynchronizeDataOnScheduleOnChange(Item)
	
	If SynchronizeDataOnSchedule And Not SaveUserPassword Then
		
		SynchronizeDataOnSchedule = False;
		
		SetUpServerConnect(True);
		
	Else
		
		SynchronizeDataOnScheduleOnValueChange();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DataSynchronizationScheduleOptionOnChange(Item)
	
	DataSynchronizationScheduleOptionOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure SynchronizeDataOnStartOnChange(Item)
	
	SetConstantValue_SynchronizeDataWithWebApplicationOnStart(
		SynchronizeDataOnStart);
EndProcedure

&AtClient
Procedure SynchronizeDataOnExitOnChange(Item)
	
	SetConstantValue_SynchronizeDataWithWebApplicationOnExit(
		SynchronizeDataOnExit);
	
	SuggestDataSynchronizationWithWebApplicationOnExit = SynchronizeDataOnExit;
	
EndProcedure

&AtClient
Procedure SetUpConnection(Command)
	
	SetUpServerConnect();
	
EndProcedure

&AtClient
Procedure GoToConflicts(Command)
	
	ExchangeNodes = New Array;
	ExchangeNodes.Add(ApplicationInSaaS);
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ExchangeNodes", ExchangeNodes);
	OpenForm("InformationRegister.DataExchangeResults.Form.Form", OpenParameters);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure RefreshVisibility()
	
	RefreshVisibilityAtServer();
	
EndProcedure

&AtServer
Procedure RefreshVisibilityAtServer()
	
	SetPrivilegedMode(True);
	
	SynchronizationDatePresentation = DataExchangeServer.SynchronizationDatePresentation(
		StandaloneModeInternal.LastDoneSynchronizationDate(ApplicationInSaaS));
	Items.LastSynchronizationInfo.Title = SynchronizationDatePresentation + ".";
	Items.LastSynchronizationInfo1.Title = SynchronizationDatePresentation + ".";
	
	UpdateGoToConflictTitle();
	
	InstallUpdateRequired = DataExchangeServer.InstallUpdateRequired();
	
	Items.StandaloneMode.CurrentPage = ?(InstallUpdateRequired,
		Items.ConfigurationUpdateReceived,
		Items.DataSynchronization);
	
	Items.PerformDataSynchronization.DefaultButton  = Not InstallUpdateRequired;
	Items.PerformDataSynchronization.DefaultControl = Not InstallUpdateRequired;
	
	Items.InstallUpdate.DefaultButton  = InstallUpdateRequired;
	Items.InstallUpdate.DefaultControl = InstallUpdateRequired;
	
	TransportSettingsWS = InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(ApplicationInSaaS);
	SaveUserPassword = TransportSettingsWS.WSRememberPassword;
	
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DataSynchronizationWithWebApplication);
	SynchronizeDataOnSchedule = ScheduledJob.Use;
	
	Items.SetUpConnection.Enabled = SynchronizeDataOnSchedule;
	Items.DataSynchronizationScheduleOption.Enabled = SynchronizeDataOnSchedule;
	Items.ChangeDataSynchronizationSchedule.Enabled = SynchronizeDataOnSchedule;
	
	SetPrivilegedMode(False);
	
	// Setting item visibility according to user roles
	IsInRoleDataSynchronizationSetup = Users.RolesAvailable("DataSynchronizationSetup");
	Items.DataSynchronizationSetup.Visible = IsInRoleDataSynchronizationSetup;
	Items.InstallUpdate.Visible = IsInRoleDataSynchronizationSetup;
	
	If IsInRoleDataSynchronizationSetup Then
		Items.UpdateReceivedCommentLabel.Title = NStr("en = 'An application update downloaded from the Internet is available.
			|To continue the synchronization, install the update.'");
	Else
		Items.UpdateReceivedCommentLabel.Title = NStr("en = 'An application update downloaded from the Internet is available.
			|Contact the infobase administrator to install the update.'");
	EndIf;
	
	ShowLongSynchronizationWarning = StandaloneModeInternal.LongSynchronizationQuestionSetupFlag();
EndProcedure

&AtServer
Procedure UpdateGoToConflictTitle()
	
	If DataExchangeCached.VersioningUsed() Then
		
		TitleStructure = DataExchangeServer.IssueMonitorHyperlinkTitleStructure(ApplicationInSaaS);
		
		FillPropertyValues (Items.GoToConflicts, TitleStructure);
		FillPropertyValues (Items.GoToConflicts1, TitleStructure);
		
	Else
		
		Items.GoToConflicts.Visible = False;
		Items.GoToConflicts1.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DataSynchronizationScheduleOptionOnChangeAtServer()
	
	NewDataSynchronizationSchedule = "";
	
	If DataSynchronizationScheduleOption = 1 Then
		
		NewDataSynchronizationSchedule = PredefinedScheduleOption1();
		
	ElsIf DataSynchronizationScheduleOption = 2 Then
		
		NewDataSynchronizationSchedule = PredefinedScheduleOption2();
		
	ElsIf DataSynchronizationScheduleOption = 3 Then
		
		NewDataSynchronizationSchedule = PredefinedScheduleOption3();
		
	Else // 4
		
		NewDataSynchronizationSchedule = DataSynchronizationUserSchedule;
		
	EndIf;
	
	If String(DataSynchronizationSchedule) <> String(NewDataSynchronizationSchedule) Then
		
		DataSynchronizationSchedule = NewDataSynchronizationSchedule;
		
		ScheduledJobsServer.SetJobSchedule(
			Metadata.ScheduledJobs.DataSynchronizationWithWebApplication,
			DataSynchronizationSchedule);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SwitchLongSynchronizationWarning(Val Flag)
	
	StandaloneModeInternal.LongSynchronizationQuestionSetupFlag(Flag);
	
EndProcedure

&AtServer
Procedure OnChangeDataSynchronizationSchedule()
	
	Items.DataSynchronizationScheduleOption.ChoiceList.Clear();
	Items.DataSynchronizationScheduleOption.ChoiceList.Add(1, NStr("en = 'Every 15 minutes'"));
	Items.DataSynchronizationScheduleOption.ChoiceList.Add(2, NStr("en = 'Every hour'"));
	Items.DataSynchronizationScheduleOption.ChoiceList.Add(3, NStr("en = 'Every day at 10:00am, except Sa and Su.'"));
	
	// Selecting data synchronization schedule option
	DataSynchronizationScheduleOptions = New Map;
	DataSynchronizationScheduleOptions.Insert(String(PredefinedScheduleOption1()), 1);
	DataSynchronizationScheduleOptions.Insert(String(PredefinedScheduleOption2()), 2);
	DataSynchronizationScheduleOptions.Insert(String(PredefinedScheduleOption3()), 3);
	
	DataSynchronizationScheduleOption = DataSynchronizationScheduleOptions[String(DataSynchronizationSchedule)];
	
	If DataSynchronizationScheduleOption = 0 Then
		
		DataSynchronizationScheduleOption = 4;
		Items.DataSynchronizationScheduleOption.ChoiceList.Add(4, String(DataSynchronizationSchedule));
		DataSynchronizationUserSchedule = DataSynchronizationSchedule;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeDataSynchronizationScheduleAtServer()
	
	ScheduledJobsServer.SetJobSchedule(
		Metadata.ScheduledJobs.DataSynchronizationWithWebApplication,
		DataSynchronizationSchedule);
	
	OnChangeDataSynchronizationSchedule();
	
EndProcedure

&AtServerNoContext
Procedure SetConstantValue_SynchronizeDataWithWebApplicationOnStart(Val Value)
	
	SetPrivilegedMode(True);
	
	Constants.SynchronizeDataWithWebApplicationOnStart.Set(Value);
	
EndProcedure

&AtServerNoContext
Procedure SetConstantValue_SynchronizeDataWithWebApplicationOnExit(Val Value)
	
	SetPrivilegedMode(True);
	
	Constants.SynchronizeDataWithWebApplicationOnExit.Set(Value);
	
EndProcedure

&AtClient
Procedure SetUpServerConnect(AutomaticSynchronizationSetup = False)
	
	Filter         = New Structure("Node", ApplicationInSaaS);
	FillingValues  = New Structure("Node", ApplicationInSaaS);
	FormParameters = New Structure;
	FormParameters.Insert("AddressForRestoringAccountPassword", AddressForRestoringAccountPassword);
	FormParameters.Insert("AutomaticSynchronizationSetup", AutomaticSynchronizationSetup);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "ExchangeTransportSettings",
		ThisObject, "SaaSConnectionSetup", FormParameters);
	
	RefreshVisibilityAtServer();
	
EndProcedure

&AtClient
Procedure SynchronizeDataOnScheduleOnValueChange()
	
	SetUseScheduledJob(SynchronizeDataOnSchedule);
	
	Items.SetUpConnection.Enabled = SynchronizeDataOnSchedule;
	Items.DataSynchronizationScheduleOption.Enabled = SynchronizeDataOnSchedule;
	Items.ChangeDataSynchronizationSchedule.Enabled = SynchronizeDataOnSchedule;
	
EndProcedure

&AtServerNoContext
Procedure SetUseScheduledJob(Val SynchronizeDataOnSchedule)
	
	ScheduledJobsServer.SetUseScheduledJob(
		Metadata.ScheduledJobs.DataSynchronizationWithWebApplication,
		SynchronizeDataOnSchedule);
	
EndProcedure

// Predefined data synchronization schedules

&AtServerNoContext
Function PredefinedScheduleOption1() // Every 15 minutes
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 60*15; // 15 minutes
	Schedule.DaysRepeatPeriod        = 1; // Every day
	
	Return Schedule;
EndFunction

&AtServerNoContext
Function PredefinedScheduleOption2() // Every hour
	
	Return StandaloneModeInternal.DefaultDataSynchronizationSchedule();
	
EndFunction

&AtServerNoContext
Function PredefinedScheduleOption3() // Every day at 10:00am, except Sa and Su.
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	
	Schedule = New JobSchedule;
	Schedule.Months            = Months;
	Schedule.WeekDays         = WeekDays;
	Schedule.BeginTime       = Date('00010101100000'); // 10:00am
	Schedule.DaysRepeatPeriod = 1; // Every day
	
	Return Schedule;
EndFunction

#EndRegion
