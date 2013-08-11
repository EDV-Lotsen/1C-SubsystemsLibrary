////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUse.FileInfoBase()
		Or Not Users.InfoBaseUserWithFullAccess(, True) Then
		
		Items.InfoBaseAdministrationParameters.Visible = False;
		Items.DisableScheduledJobs.Visible = False;
		Items.ComcntrGroup.Visible = False;
		Items.ParametersGroup.Visible = False;
	EndIf;
	
	GetLockParameters();
	InitialUserWorkProhibitionState = Object.ProhibitUserWorkTemporarily;
	RefreshSettingsPage();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ClientConnectedViaWebServer = CommonUseClient.ClientConnectedViaWebServer();
	If SessionTerminationInProgress = True Then
		Items.ModeGroup.CurrentPage = Items.LockStatePage;
		RefreshStatePage(ThisForm);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	InfoBaseConnectionNames = "";
	ClientApplicationsOnly = OnlyClientApplicationsActive(InfoBaseConnectionNames);
	
	If CommonUse.FileInfoBase() Then
		
		// Checking whether forced session termination is possible in the file mode
		If Not ClientApplicationsOnly Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'There are active sessions that cannot be terminated forcibly. The application is not locked.
					|%1'"), 
				InfoBaseConnectionNames);
			Raise MessageText;
		EndIf;
		
		SessionCount = StrLineCount(InfoBaseConnectionNames);
		
	Else	
		// Checking whether forced session termination is possible if a client application connects to the infobase through the web server.
		// The application cannot be locked if the server is not running Windows and the data separation is disabled (that is, the application is running in the local mode).
		If Not ClientApplicationsOnly And Not CommonUseCached.DataSeparationEnabled() And ClientConnectedViaWebServer
			And Not InfoBaseConnectionsCached.SessionTerminationParameters().WindowsPlatformAtServer Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'There are active sessions that cannot be terminated forcibly (because the server is not running Windows). The application is not locked.
					|%1'"), 
				InfoBaseConnectionNames);
			Raise MessageText;
		EndIf;	
		
		SessionCount = GetInfoBaseSessions().Count();
		
	EndIf;
	
	// Checking whether the application can be locked
	If Object.LockPeriodStart > Object.LockPeriodEnd 
		And ValueIsFilled(Object.LockPeriodEnd) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The lock end date cannot be less than the lock start date. The application is not locked.'"),,
			"Object.LockPeriodEnd",,Cancel);
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.LockPeriodStart) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The lock start date is not specified.'"),,	"Object.LockPeriodStart",,Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSessions" Then
		SessionCount = Parameter.SessionCount;
		UpdateLockState(ThisForm);
		If Parameter.Status = "Done" Then
			Close();
		ElsIf Parameter.Status = "Error" Then
			DoMessageBox(NStr("en = 'Cannot terminate all active user sessions.
				|See the event log for details.'"), 30);
			Close();
		EndIf;
	ElsIf EventName = "Write_InfoBaseAdministrationParameters" Then
		GetLockParameters(True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ActiveUsers(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form",, ThisForm);
	
EndProcedure

&AtClient
Procedure InfoBaseAdministrationParameters(Command)
	
	OpenForm("CommonForm.ServerInfoBaseAdministrationSettings");
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	ClearMessages();
	
	Object.ProhibitUserWorkTemporarily = Not InitialUserWorkProhibitionState;
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
		
		QuestionTitle = NStr("en = 'Application locking'");
		If SessionCount > 1 And Object.LockPeriodStart < CommonUseClient.SessionDate() + 5 * 60 Then
			QuestionText = NStr("en = 'All active user sessions will be terminated.
				|The specified lock start time can be not enough for users to save their data and exit application.
				|It is recommended that you set the lock start time in 5 minutes from now.
				|
				|• Click Yes to modify the lock start date and continue (recommended);
				|• Click No to continue without modifying.'");
			Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNoCancel,,, QuestionTitle);
			If Response = DialogReturnCode.Yes Then
				Object.LockPeriodStart = CommonUseClient.SessionDate() + 5 * 60;
			ElsIf Response <> DialogReturnCode.No Then
				Return;
			EndIf;
		ElsIf Object.LockPeriodStart > CommonUseClient.SessionDate() + 5 * 60 Then
			QuestionText = NStr("en = 'All active user sessions will be terminated.
				|The interval between the present time and the data lock time that you specified 
				|is too long, new users can log on before this time.
				|It is recommended that you set the lock start time in 5 minutes from now.
				|
				|• Click Yes to modify the lock start date and continue (recommended);
				|• Click No to continue without modifying.'");
			Response = DoQueryBox(QuestionText, QuestionDialogMode.YesNoCancel,,, QuestionTitle);
			If Response = DialogReturnCode.Yes Then
				Object.LockPeriodStart = CommonUseClient.SessionDate() + 5 * 60;
			ElsIf Response <> DialogReturnCode.No Then
				Return;
			EndIf;
		Else	
			QuestionText = NStr("en = 'All active user sessions will be terminated.
				|Do you want to continue?'");
			Response = DoQueryBox(QuestionText, QuestionDialogMode.OKCancel,,, QuestionTitle);
			If Response <> DialogReturnCode.OK Then
				Return;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not LockUnlock() Then
		Return;	
	EndIf;
	
	ShowUserNotification(NStr("en = 'Application locking'"),
		"e1cib/app/DataProcessor.ApplicationLocking",
		?(Object.ProhibitUserWorkTemporarily, NStr("en= 'Locked.'"), NStr("en= 'Unlocked.'")), 
		PictureLib.Information32);
	InfoBaseConnectionsClient.SetSessionTerminationHandlers(
		Object.ProhibitUserWorkTemporarily);
	If Object.ProhibitUserWorkTemporarily Then	
		RefreshStatePage(ThisForm);
	Else
		RefreshSettingsPage();
	EndIf;
	
EndProcedure

&AtClient
Procedure Stop(Command)
	
	If Not Unlock() Then
		Return;
	EndIf;
	InfoBaseConnectionsClient.SetSessionTerminationHandlers(False);
	DoMessageBox(NStr("en = 'Active user session termination was canceled. 
		|The infobase is still locked."));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Function CheckLockPreconditions()
	
	Return CheckFilling();

EndFunction

&AtServerNoContext
Function OnlyClientApplicationsActive(ActiveSessionNames)
	
	Result = True;
	InfoBaseConnectionNames = "";
	CurrentSessionNumber = InfoBaseSessionNumber();
	For Each Session In GetInfoBaseSessions() Do
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
		WriteLogEvent(NStr("en = 'User sessions'"), 
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If Users.InfoBaseUserWithFullAccess(, True) Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	InitialUserWorkProhibitionState = Object.ProhibitUserWorkTemporarily;
	SessionCount = GetInfoBaseSessions().Count();
	Return True;
	
EndFunction

&AtServer
Function Unlock()
	
	Try
		FormAttributeToValue("Object").Unlock();
	Except
		WriteLogEvent(NStr("en= 'User sessions'"), 
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If Users.InfoBaseUserWithFullAccess(, True) Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
		Return False;
	EndTry;
	InitialUserWorkProhibitionState = Object.ProhibitUserWorkTemporarily;
	Items.ModeGroup.CurrentPage = Items.SettingsPage;
	RefreshSettingsPage();
	Return True;
	
EndFunction

&AtServer
Procedure RefreshSettingsPage()
	
	Items.ApplyCommand.Visible = True;
	Items.ApplyCommand.DefaultButton = True;
	Items.StopCommand.Visible = False;
	Items.ApplyCommand.Title = ?(Object.ProhibitUserWorkTemporarily,
		NStr("en = 'Unlock'"), NStr("en = 'Lock'"));
	Items.DisableScheduledJobs.Title = ?(Object.ProhibitUserWorkTemporarily,
		NStr("en = 'Leave schedule jobs locked"), NStr("en = 'Disable schedule jobs too'"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshStatePage(Form)
	
	Form.Items.StopCommand.Visible = True;
	Form.Items.ApplyCommand.Visible = False;
	Form.Items.CloseCommand.DefaultButton = True;
	UpdateLockState(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateLockState(Form)
	
	Form.Items.State.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Please wait...
			|Terminating user sessions. %1 active session(s) left.'"),
			Form.SessionCount);
	
EndProcedure

&AtServer
Procedure GetLockParameters(CheckOnly = False)
	DataProcessor = FormAttributeToValue("Object");
	Try
		DataProcessor.GetLockParameters();
		Items.ErrorGroup.Visible = False;
	Except
		WriteLogEvent(NStr("en = 'User sessions'"), 
			EventLogLevel.Error,,, 
			DetailErrorDescription(ErrorInfo()));
		If Users.InfoBaseUserWithFullAccess(, True) Then
			Items.ErrorGroup.Visible = True;
			Items.ErrorText.Title = ErrorShortInfo(ErrorDescription());
		EndIf;
	EndTry;
	If Not CheckOnly Then
		ValueToFormAttribute(DataProcessor, "Object");
	EndIf;
EndProcedure

&AtServer
Function ErrorShortInfo(ErrorDescription)
	ErrorText = ErrorDescription;
	Position = Find(ErrorText, "}:");
	If Position > 0 Then
		ErrorText = TrimAll(Mid(ErrorText, Position + 2, StrLen(ErrorText)));
	EndIf;
	Return ErrorText;
EndFunction	