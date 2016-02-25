&AtClient
Var AdministrationParameters, CurrentLockValue;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	IsFileInfobase = CommonUse.FileInfobase();
	IsFullAdministrator = Users.InfobaseUserWithFullAccess(, True);
	SessionWithoutSeparators = CommonUseCached.SessionWithoutSeparators();
	
	If IsFileInfobase Or Not IsFullAdministrator Then
		Items.DisableScheduledJobsGroup.Visible = False;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled() Then
		Items.UnlockCode.Visible = False;
	EndIf;
	
	GetLockParameters();
	SetInitialUserLogonRestrictionStatus();
	RefreshSettingsPage();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ClientConnectedViaWebServer = CommonUseClient.ClientConnectedViaWebServer();
	If InfobaseConnectionsClient.SessionTerminationInProgress() Then
		Items.ModeGroup.CurrentPage = Items.LockStatePage;
		RefreshStatePage(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	InfobaseConnectionNames = "";
	ClientApplicationsOnly = OnlyClientApplicationsActive(InfobaseConnectionNames);
	
	If IsFileInfobase Then
		
		// Checking whether sessions can be terminated while in file mode
		If Not ClientApplicationsOnly Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot terminate some of the active sessions. The lock is not set.
					|%1'"), 
				InfobaseConnectionNames);
			Raise MessageText;
		EndIf;
		
		SessionCount = StrLineCount(InfobaseConnectionNames);
		
	Else	
		
		SessionCount = GetInfobaseSessions().Count();
		
	EndIf;
	
	// Checking whether lock can be set
	If Object.LockPeriodStart > Object.LockPeriodEnd 
		And ValueIsFilled(Object.LockPeriodEnd) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The lock end date cannot precede the lock start date. The lock is not set.'"),,
			"Object.LockPeriodEnd",,Cancel);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.LockPeriodStart) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Lock start date is not specified.'"),,	"Object.LockPeriodStart",,Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSessions" Then
		SessionCount = Parameter.SessionCount;
		UpdateLockState(ThisObject);
		If Parameter.Status = "Done" Then
			Close();
		ElsIf Parameter.Status = "Error" Then
			ShowMessageBox(,NStr("en = 'Cannot log out some of the active users.
				|See the event log for details.'"), 30);
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ActiveUsers(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form",, ThisObject);
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	ClearMessages();
	
	Object.ProhibitUserWorkTemporarily = Not InitialUserLogonRestrictionStatusValue;
	If Object.ProhibitUserWorkTemporarily Then
		
		SessionCount = 1;
		Try
			If Not CheckLockPreconditions() Then
				Return;
			EndIf;
		Except
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		QuestionTitle = NStr("en = 'Application lock'");
		If SessionCount > 1 And Object.LockPeriodStart < CommonUseClient.SessionDate() + 5 * 60 Then
			QuestionText = NStr("en = 'The specified lock start time is too soon; users may need more time to save their data and end their sessions.
				|We recommend that you set the lock start time to 5 minutes from now.'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Lock in 5 minutes'"));
			Buttons.Add(DialogReturnCode.No, NStr("en = 'Lock now'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
			Notification = New NotifyDescription("ApplyCompletion", ThisObject, "LockTimeTooSoon");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		ElsIf Object.LockPeriodStart > CommonUseClient.SessionDate() + 60 * 60 Then
			QuestionText = NStr("en = 'The specified lock start time is too late (more than 1 hour from now).
				|Schedule application lock for that time anyway?'");
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.No, NStr("en = 'Schedule'"));
			Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Lock now'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
			Notification = New NotifyDescription("ApplyCompletion", ThisObject, "LockTimeTooLate");
			ShowQueryBox(Notification, QuestionText, Buttons,,, QuestionTitle);
		Else
			If Object.LockPeriodStart - CommonUseClient.SessionDate() > 15*60 Then
				QuestionText = NStr("en = 'All active users will be logged out of the application between %1 and %2.
					|Do you want to continue?'");
			Else
				QuestionText = NStr("en = 'All active user sessions will be terminated at %2.
					|Do you want to continue?'");
			EndIf;
			Notification = New NotifyDescription("ApplyCompletion", ThisObject, "Confirmation");
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			QuestionText, Object.LockPeriodStart - 900, Object.LockPeriodStart);
			ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,,, QuestionTitle);
		EndIf;
		
	Else
		
		Notification = New NotifyDescription("ApplyCompletion", ThisObject, "Confirmation");
		ExecuteNotifyProcessing(Notification, DialogReturnCode.OK);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyCompletion(Answer, Option) Export
	
	If Option = "LockTimeTooSoon" Then
		If Answer = DialogReturnCode.Yes Then
			Object.LockPeriodStart = CommonUseClient.SessionDate() + 5 * 60;
		ElsIf Answer <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Option = "LockTimeTooLate" Then
		If Answer = DialogReturnCode.Yes Then
			Object.LockPeriodStart = CommonUseClient.SessionDate() + 5 * 60;
		ElsIf Answer <> DialogReturnCode.No Then
			Return;
		EndIf;
	ElsIf Option = "Confirmation" Then
		If Answer <> DialogReturnCode.OK Then
			Return;
		EndIf;
	EndIf;
	
	If CorrectAdministrationParametersEntered And IsFullAdministrator And Not IsFileInfobase
		And CurrentLockValue <> Object.DisableScheduledJobs Then
		
		Try
			
			If ClientConnectedViaWebServer Then
				SetScheduledJobLockAtServer(AdministrationParameters);
			Else
				ClusterAdministrationClientServer.LockInfobaseScheduledJobs(
					AdministrationParameters,, Object.DisableScheduledJobs);
			EndIf;
			
		Except
			EventLogOperationsClient.AddMessageForEventLog(InfobaseConnectionsClientServer.EventLogMessageText(), "Error",
				DetailErrorDescription(ErrorInfo()),, True);
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDetails(ErrorDescription());
			Return;
		EndTry;
		
	EndIf;
	
	If Not IsFileInfobase And Not CorrectAdministrationParametersEntered And SessionWithoutSeparators Then
		
		NotifyDescription = New NotifyDescription("AfterReceiveAdministrationParametersOnLock", ThisObject);
		FormTitle = NStr("en = 'Session lock management'");
		CommentLabel = NStr("en = 'To access session lock management functionality,
			|enter the server cluster and infobase administration parameters'");
		InfobaseConnectionsClient.ShowAdministrationParameters(NotifyDescription,,, AdministrationParameters, FormTitle, CommentLabel);
		
	Else
		
		AfterReceiveAdministrationParametersOnLock(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Stop(Command)
	
	If Not IsFileInfobase And Not CorrectAdministrationParametersEntered And SessionWithoutSeparators Then
		
		NotifyDescription = New NotifyDescription("AfterReceiveAdministrationParametersOnUnlock", ThisObject);
		FormTitle = NStr("en = 'Session lock management'");
		CommentLabel = NStr("en = 'To access session lock management functionality,
			|enter the server cluster and infobase administration parameters'");
		InfobaseConnectionsClient.ShowAdministrationParameters(NotifyDescription,,, AdministrationParameters, FormTitle, CommentLabel);
		
	Else
		
		AfterReceiveAdministrationParametersOnUnlock(True, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdministrationParameters(Command)
	
	NotifyDescription = New NotifyDescription("AfterReceiveAdministrationParameters", ThisObject);
	FormTitle = NStr("en = 'Scheduled job lock management'");
	CommentLabel = NStr("en = 'To access scheduled job lock management functionality,
		|enter the server cluster and infobase administration parameters'");
	InfobaseConnectionsClient.ShowAdministrationParameters(NotifyDescription,,, AdministrationParameters, FormTitle, CommentLabel);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserLogonRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UserLogonRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = 'Prohibited'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ErrorInformationText);

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserLogonRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UserLogonRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = 'Scheduled'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ErrorInformationText);

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserLogonRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UserLogonRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = 'Expired'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.LockedAttributeColor);

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.InitialUserLogonRestrictionStatus.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UserLogonRestrictionStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = 'Allowed'");

	Item.Appearance.SetParameterValue("TextColor", StyleColors.FormTextColor);

EndProcedure

&AtServer
Function CheckLockPreconditions()
	
	Return CheckFilling();

EndFunction

&AtServerNoContext
Function OnlyClientApplicationsActive(ActiveSessionNames)
	
	Result = True;
	InfobaseConnectionNames = "";
	CurrentSessionNumber = InfobaseSessionNumber();
	For Each Session In GetInfobaseSessions() Do
		If Session.SessionNumber = CurrentSessionNumber Then
			Continue;
		EndIf;
		If Session.ApplicationName <> "1CV8" And Session.ApplicationName <> "1CV8C" And
			Session.ApplicationName <> "WebClient" Then
			ActiveSessionNames = ActiveSessionNames + Chars.LF + "• " + Session;
			Result = False;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function LockUnlock()
	
	Try
		FormAttributeToValue("Object").SetLock();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMessageText(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If IsFullAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDetails(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	
	SetInitialUserLogonRestrictionStatus();
	SessionCount = GetInfobaseSessions().Count();
	Return True;
	
EndFunction

&AtServer
Function Unlock()
	
	Try
		FormAttributeToValue("Object").Unlock();
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMessageText(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If IsFullAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDetails(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	SetInitialUserLogonRestrictionStatus();
	Items.ModeGroup.CurrentPage = Items.SettingsPage;
	RefreshSettingsPage();
	Return True;
	
EndFunction

&AtServer
Procedure RefreshSettingsPage()
	
	Items.DisableScheduledJobsGroup.Enabled = True;
	Items.ApplyCommand.Visible = True;
	Items.ApplyCommand.DefaultButton = True;
	Items.StopCommand.Visible = False;
	Items.ApplyCommand.Title = ?(Object.ProhibitUserWorkTemporarily,
		NStr("en='Remove lock'"), NStr("en='Set lock'"));
	Items.DisableScheduledJobs.Title = ?(Object.DisableScheduledJobs,
		NStr("en='Keep scheduled job lock'"), NStr("en='Also disable scheduled jobs'"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshStatePage(Form)
	
	Form.Items.DisableScheduledJobsGroup.Enabled = False;
	Form.Items.StopCommand.Visible = True;
	Form.Items.ApplyCommand.Visible = False;
	Form.Items.CloseCommand.DefaultButton = True;
	UpdateLockState(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateLockState(Form)
	
	Form.Items.State.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Please wait.
			|Users are ending their sessions now. Active sessions left: %1'"),
			Form.SessionCount);
	
EndProcedure

&AtServer
Procedure GetLockParameters()
	Processing = FormAttributeToValue("Object");
	Try
		Processing.GetLockParameters();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(InfobaseConnectionsClientServer.EventLogMessageText(),
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If IsFullAdministrator Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = BriefErrorDetails(ErrorDescription());
		EndIf;
	EndTry;
	
	ValueToFormAttribute(Processing, "Object");
	
EndProcedure

&AtServer
Function BriefErrorDetails(ErrorDescription)
	ErrorText = ErrorDescription;
	Position = Find(ErrorText, "}:");
	If Position > 0 Then
		ErrorText = TrimAll(Mid(ErrorText, Position + 2, StrLen(ErrorText)));
	EndIf;
	Return ErrorText;
EndFunction	

&AtServer
Procedure SetInitialUserLogonRestrictionStatus()
	
	InitialUserLogonRestrictionStatusValue = Object.ProhibitUserWorkTemporarily;
	If Object.ProhibitUserWorkTemporarily Then
		If CurrentSessionDate() < Object.LockPeriodStart Then
			InitialUserLogonRestrictionStatus = NStr("en = 'Users will be logged out of the application at the specified time'");
			UserLogonRestrictionStatus = "Scheduled";
		ElsIf CurrentSessionDate() > Object.LockPeriodEnd And Object.LockPeriodEnd <> '00010101' Then
			InitialUserLogonRestrictionStatus = NStr("en = 'Users are allowed to log on to the application (lock duration expired)'");;
			UserLogonRestrictionStatus = "Expired";
		Else
			InitialUserLogonRestrictionStatus = NStr("en = 'Users are logged out of the application'");
			UserLogonRestrictionStatus = "Prohibited";
		EndIf;
	Else
		InitialUserLogonRestrictionStatus = NStr("en = 'Users are allowed to log on to the application'");
		UserLogonRestrictionStatus = "Allowed";
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterReceiveAdministrationParameters(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		AdministrationParameters = Result;
		CorrectAdministrationParametersEntered = True;
		
		Try
			If ClientConnectedViaWebServer Then
				Object.DisableScheduledJobs = InfobaseScheduledJobLockAtServer(AdministrationParameters);
			Else
				Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobLock(AdministrationParameters);
			EndIf;
			CurrentLockValue = Object.DisableScheduledJobs;
		Except;
			CorrectAdministrationParametersEntered = False;
			Raise;
		EndTry;
		
		Items.DisableScheduledJobsGroup.CurrentPage = Items.ScheduledJobManagementGroup;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterReceiveAdministrationParametersOnLock(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		CorrectAdministrationParametersEntered = True;
		EnableScheduledJobLockManagement();
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") And CorrectAdministrationParametersEntered Then
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not LockUnlock() Then
		Return;
	EndIf;
	
	ShowUserNotification(NStr("en = 'Application lock'"),
		"e1cib/app/DataProcessor.ApplicationLock",
		?(Object.ProhibitUserWorkTemporarily, NStr("en = 'The lock is set.'"), NStr("en = 'The lock is removed.'")),
		PictureLib.Information32);
	InfobaseConnectionsClient.SetSessionTerminationHandlers(	Object.ProhibitUserWorkTemporarily);
	
	If Object.ProhibitUserWorkTemporarily Then
		RefreshStatePage(ThisObject);
	Else
		RefreshSettingsPage();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterReceiveAdministrationParametersOnUnlock(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf TypeOf(Result) = Type("Structure") Then
		AdministrationParameters = Result;
		CorrectAdministrationParametersEntered = True;
		EnableScheduledJobLockManagement();
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	ElsIf TypeOf(Result) = Type("Boolean") And CorrectAdministrationParametersEntered Then
		InfobaseConnectionsClient.SaveAdministrationParameters(AdministrationParameters);
	EndIf;
	
	If Not Unlock() Then
		Return;
	EndIf;
	
	InfobaseConnectionsClient.SetSessionTerminationHandlers(False);
	ShowMessageBox(,NStr("en = 'Logging active users out of the application is canceled. 
		|Application logon lock is not removed.'"));
	
EndProcedure

&AtClient
Procedure EnableScheduledJobLockManagement()
	
	If ClientConnectedViaWebServer Then
		Object.DisableScheduledJobs = InfobaseScheduledJobLockAtServer(AdministrationParameters);
	Else
		Object.DisableScheduledJobs = ClusterAdministrationClientServer.InfobaseScheduledJobLock(AdministrationParameters);
	EndIf;
	CurrentLockValue = Object.DisableScheduledJobs;
	Items.DisableScheduledJobsGroup.CurrentPage = Items.ScheduledJobManagementGroup;
	
EndProcedure

&AtServer
Procedure SetScheduledJobLockAtServer(AdministrationParameters)
	
	ClusterAdministrationClientServer.LockInfobaseScheduledJobs(
		AdministrationParameters,, Object.DisableScheduledJobs);
	
EndProcedure
	
&AtServer
Function InfobaseScheduledJobLockAtServer(AdministrationParameters)
	
	Return ClusterAdministrationClientServer.InfobaseScheduledJobLock(AdministrationParameters);
	
EndFunction

#EndRegion