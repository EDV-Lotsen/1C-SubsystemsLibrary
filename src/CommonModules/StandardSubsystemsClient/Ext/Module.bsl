////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Sets an application main window caption, using the current user presentation,
// value of the SystemTitle constant, and default application caption.
//
Procedure SetAdvancedSystemTitle(OnStart = False) Export
	
	ClientParameters = ?(OnStart, StandardSubsystemsClientCached.ClientParametersOnStart(),
		StandardSubsystemsClientCached.ClientParameters());
		
	If ClientParameters.CanUseSeparatedData Then
		CaptionPresentation = ClientParameters.SystemTitle;
		UserPresentation = ClientParameters.UserPresentation;
		ConfigurationPresentation = ClientParameters.DetailedInformation;
		
		If IsBlankString(TrimAll(CaptionPresentation)) Then
			If ClientParameters.Property("DataAreaPresentation") Then
				CaptionPattern = "%1 / %2 / %3";
				SystemTitle = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
					ClientParameters.DataAreaPresentation, ConfigurationPresentation, 
					UserPresentation);
			Else
				CaptionPattern = "%1 / %2";
				SystemTitle = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
					ConfigurationPresentation, UserPresentation);
			EndIf;
		Else
			CaptionPattern = "%1 / %2 / %3";
			SystemTitle = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
				TrimAll(CaptionPresentation), UserPresentation, ConfigurationPresentation);
		EndIf;
	Else
		CaptionPattern = "%1 / %2";
		SystemTitle = StringFunctionsClientServer.SubstituteParametersInString(CaptionPattern, 
			NStr("en='Data area separators are not specified'"), 
			ClientParameters.DetailedInformation);
	EndIf;
	
	CommonUseClientOverridable.ClientSystemTitleOnSet(SystemTitle, OnStart);
	
	SetClientApplicationCaption(SystemTitle);
	
EndProcedure

// Сorresponds to the OnStart handler
//
// Parameters
// ProcessLaunchParameters - Boolean - True if the handler is called on 
// a direct application launch and it should process launch parameters
// (if its logic specifies such processing). False if the handler is called on 
// a shared user interactive logon to a data area and it 
// should not processes launch parameters.
//
Procedure OnStart(Val CompletionNotification = Undefined, SolidProcessing = True) Export
	
	If CompletionNotification <> Undefined Then
		CommonUseClientServer.ValidateParameter("StandardSubsystemsClient.OnStart", 
			"CompletionNotification", CompletionNotification, Type("NotifyDescription"));
	EndIf;
	CommonUseClientServer.ValidateParameter("StandardSubsystemsClient.OnStart", 
		"SolidProcessing", SolidProcessing, Type("Boolean"));
	
	If OnStartInteractiveProcessingInProgress() Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	
	// External parameters of the result description.
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalCommandLineParameters", "");
	
	// External parameters for managing the processing.
	Parameters.Insert("InteractiveProcessing", Undefined); // NotifyDescription.
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription.
	Parameters.Insert("SolidProcessing", SolidProcessing);
	Parameters.Вставить("RetrievedClientParameters", New Structure);
	
	// Internal parameters.
	Parameters.Insert("CompletionNotification", CompletionNotification);
	Parameters.Insert("CompletionHandler", New NotifyDescription(
		"ActionsOnStartCompletionHandler", ThisObject, Parameters));
	
	RefreshClientParameters(Parameters, True, CompletionNotification <> Undefined);
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsOnStartInInternalEventHandlers", ThisObject, Parameters));
	
	Parameters.Insert("NextHandlerNumber", 1);
	
	Try
		CheckPlatformVersionAtStart(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If OnStartInteractiveProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Is executed before interactive work with the data area start.
// Corresponds to the BeforeStart handler.
//
// Parameters:
// Cancel - Boolean - Cancel run. If this parameter is set to True
// the work with area will not be started.
//
Procedure BeforeStart(Val CompletionNotification = Undefined) Export
	
	If CompletionNotification <> Undefined Then
		CommonUseClientServer.ValidateParameter("StandardSubsystemsClient.BeforeStart", 
			"CompletionNotification", CompletionNotification, Type("NotifyDescription"));
	EndIf;
	
	SetSessionSeparation();
	
	Parameters = New Structure;
	
	// External parameters of the result description.
	Parameters.Insert("Cancel", False);
	Parameters.Insert("Restart", False);
	Parameters.Insert("AdditionalParametersOfCommandLine", "");
	
	// External parameters of the execution management.
	Parameters.Insert("InteractiveProcessing", Undefined); // NotifyDescription.
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription.
	Parameters.Insert("SolidProcessing", True);
	Parameters.Insert("RetrievedClientParameters", New Structure);
	
	// Internal parameters.
	Parameters.Insert("CompletionNotification", CompletionNotification);
	Parameters.Insert("CompletionHandler", New NotifyDescription(
		"ActionsBeforeStartCompletionHandler", ThisObject, Parameters));
	
	RefreshClientParameters(Parameters, True, CompletionNotification <> Undefined);
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartAfterCheckPlatformVersion", ThisObject, Parameters));
	
	If Find(LaunchParameter, "InitSeparatedInfobaseExecute") <> 0 Then
		CommonUse.SetInfoBaseSeparationParameters(True);
		Terminate(True, "/C");
	EndIf;
	
	Try
		CheckPlatformVersionAtStart(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorDescription(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Corresponds to the BeforeExit handler
//
Procedure BeforeExit(Cancel = False, Val CompletionNotification = Undefined) Export
	
	If ParametersOnApplicationStartAndExit.Property("HideDesktopOnStart") Then
		// One tried to close the application before it was fully initialized.
	#If WebClient Then
		If CompletionNotification = Undefined Then
			Cancel = True;
		EndIf;
	#EndIf
		Return;
	EndIf;
	
	CommonUseClientServer.ValidateParameter(
		"StandardSubsystemsClient.BeforeExit", "Cancel", Cancel, Type("Boolean"));
	
	If CompletionNotification <> Undefined Then
		CommonUseClientServer.ValidateParameter("StandardSubsystemsClient.BeforeExit", 
			"CompletionNotification", CompletionNotification, Type("NotifyDescription"));
	EndIf;
	
	If CompletionNotification = Undefined Then
		If ParametersOnApplicationStartAndExit.Property("ActionsBeforeExitCompleted") Then
			ParametersOnApplicationStartAndExit.Delete("ActionsBeforeExitCompleted");
			Return;
		EndIf;
	EndIf;
	
	// Each time the client exits, the client start and exit parameters should be reacquired.
	If ParametersOnApplicationStartAndExit.Property("ClientParametersOnExit") Then
		ParametersOnApplicationStartAndExit.Delete("ClientParametersOnExit");
	EndIf;
	
	Parameters = New Structure;
	
	// External parameters of the result description.
	Parameters.Insert("Cancel", Cancel);
	
	// External parameters for managing the processing.
	Parameters.Insert("InteractiveProcessing", Undefined); // NotifyDescription.
	Parameters.Insert("ContinuationHandler",   Undefined); // NotifyDescription.
	Parameters.Insert("SolidProcessing", True);
	
	// Internal parameters.
	Parameters.Insert("CompletionNotification", CompletionNotification);
	Parameters.Insert("CompletionHandler", New NotifyDescription(
		"ActionsBeforeExitCompletionHandler", ThisObject, Parameters));
	
	Parameters.Insert("NextHandlerNumber", 1);
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeExitInInternalEventHandlers", ThisObject, Parameters));
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
	If Parameters.Cancel Or Not Parameters.SolidProcessing Then
		Cancel = True;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

//// Standard actions executed before appication start.
////
//// Parameters:
//// Cancel - Boolean - flag that shows whether execution is canceled. 
//// If it is set to True then application will not start.
////
//Procedure ActionsBeforeStart(Val CompletionNotification = Undefined) Export
//	
//	If InfoBaseUpdate.FirstRun() Then
//		
//		If Find(LaunchParameter, "InitSeparatedInfobase") <> 0 Then
//			
//			CommonUse.SetInfoBaseSeparationParameters(True);
//			
//			Terminate(True);
//		EndIf;
//		
//	EndIf;
//	
//	CanUseSeparatedData = CommonUseCached.CanUseSeparatedData();
//	
//	If Not CanUseSeparatedData Then
//		InfoBaseUpdate.ExecuteInfoBaseUpdate();
//	EndIf;
//	
//	If Not IsBlankString(LaunchParameter) Then
//		LaunchParameters = StringFunctionsClientServer.SplitStringIntoSubstringArray(LaunchParameter, ";");
//		LaunchParameterValue = Upper(LaunchParameters[0]);
//		
//		If LaunchParameterValue = Upper("LogOnDataArea") Then
//			If LaunchParameters.Count() < 2 Then
//				Raise(NStr("en = 'If the LogOnDataArea startup parameter is specified,
//                            |the separator parameter must be specified too.'; ru = 'If задан параметр запуска LogOnDataArea, разделитель также должен быть задан.'"));
//			EndIf;
//			
//			Try
//				SeparatorValue = Number(LaunchParameters[1]);
//			Except
//				Raise(NStr("en='The separator value must be a number.'"));
//			EndTry;
//			
//			CommonUse.SetSessionSeparation(True, SeparatorValue);
//			CanUseSeparatedData = True;
//		EndIf;
//	EndIf;
//	
//	If CanUseSeparatedData Then
//		
//		Cancel = False;
//		
//		StandardSubsystemsClientOverridable.BeforeStart(Cancel);
//		
//		If Cancel Then
//			Return;
//		EndIf;
//		
//		CommonUseClientOverridable.BeforeStart(Cancel);
//		
//	EndIf;
//	
//EndProcedure

//// Standard actions executed on appication start.
////
//// Parameters
//// ProcessLaunchParameters - Boolean - True if the handler is called on 
//// a direct application launch and it should processes launch parameters
//// (if its logic specifies such processing). False if the handler is called on 
//// a shared user interactive logon to a data area and it 
//// should not processes launch parameters.
////
//Procedure ActionsOnStart(ProcessLaunchParameters = True) Export
//	
//	StandardSubsystemsClientOverridable.OnStart(ProcessLaunchParameters);
//	CommonUseClientOverridable.OnStart(ProcessLaunchParameters);
//	
//EndProcedure

//// Corresponds to the BeforeExit handler
////
//// Parameters:
//// Cancel - Boolean - flag that shows whether exit from the application is canceled. 
////
//Procedure ActionsBeforeExit(Cancel) Export
//	
//	StandardSubsystemsClientOverridable.BeforeExit(Cancel);
//	
//	If Cancel = True Then
//		Return;
//	EndIf;
//	
//	CommonUseClientOverridable.BeforeExit(Cancel);
//	
//EndProcedure

// Disables confirmation on exit the application.
//
Procedure SkipExitConfirmation() Export
	
	SkipExitConfirmation = True;
	
EndProcedure

// Checks the platform version. The function depends on a call position and returns True, 
// if the platform fits to start the configuration.
//
// Parameters:
//	CallPosition - String - place from which the procedure is called.
//						 Variants: 	"BeforeStart" - If it is called from the BeforeStart() handler
//										"OnStart" - If it is called from the OnStart() handler
//
// Return value - Boolean - if the version is actual then it is True, else it is False.
//
Procedure CheckPlatformVersionAtStart(CallPosition) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// For the ordinary mode checking is executed in the "OnStart" handler.
	// For the managed mode checking is executing in the "BeforeStart" handler.
	#If ThickClientOrdinaryApplication Then 
		If CallPosition = "BeforeStart" Then 
			Return;
		EndIf;
	#Else
		If CallPosition = "OnStart" Then 
			Return;
		EndIf;
	#EndIf	
	
	CheckParameters = New FixedStructure("PlatformVersion, MustExit", "8.2.15.310", False);
	StandardSubsystemsClientOverridable.GetMinRequiredPlatformVersion(CheckParameters);
	
	CheckPlatformVersion(CheckParameters.PlatformVersion, CheckParameters.MustExit);
	
EndProcedure	

// Checks the least allowable to start platform version.
// If the platform version is earlier than RecommendedPlatformVersion, a notification
// will be shown to the user. If Exit is True the application will be closed.
//
// Parameters:
// RecommendedPlatformVersion - String - platform version that is recommended for the application run;
// MustExit - Boolean - if True and the current platform version is earlier then recommended, 
// then continue of this session is impossible.
//
// Returns:
// Boolean - True, if the platform version fits for the application run.
//
Procedure CheckPlatformVersion(Val RecommendedPlatformVersion, Val MustExit = False) Export
	
	SystemInfo = New SystemInfo;
	If CommonUseClientServer.CompareVersions(SystemInfo.AppVersion, RecommendedPlatformVersion) >= 0 Then
		Return;
	EndIf;
	
	If MustExit Then
		MessageText = NStr("en='It is impossible to continue this session, the application will be closed.
			|1C:Enterprise platform version must be updated.'");
	Else
		MessageText = 
			NStr("en='It is recommended to exit application and update 1C:Enterprise platform version.
		 |Otherwise some of application resources will not be available or results would be unreliable.
				 |
		 |Exit application?'");
	EndIf;
	Parameters = New Structure;
	Parameters.Insert("MessageText", MessageText);
	Parameters.Insert("Exit", MustExit);
	Parameters.Insert("RecommendedPlatformVersion", RecommendedPlatformVersion);
	OpenForm("CommonForm.NotRecommendedPlatformVersion", Parameters);
	
EndProcedure

// Causes a question form.
//
// Parameters:
// InteractiveProcessing - NotifyDescription - the procedure that will be called when the question
//												  form will be closed.
// MessageText - String - question text for the user
// Buttons - QuestionDialogMode; ValueList. 
// Sets composition and a text of dialog buttons, and refered to button values.
// Using ValueList:
// Value – contains a refered to a button value. This value is a return value on buttion select.
// DialogReturnCode enum value or other values can be used as the value;
// Note: value must support XDTO serialization.
// Presentation – sets a text of the button.
// Timeout - timeout value in seconds. On the expiry of this time the function returns DialogReturnCode.Timeout
//
// Returns:
// DialogReturnCode
//
Function ShowQuestionToUser(InteractiveProcessing, MessageText, Buttons, Timeout = 0, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters <> Undefined Then
		Parameters = AdditionalParameters;
	Else
		Parameters = QuestionToUserParameters();
	EndIf;
	
	If TypeOf(Buttons) = Type("QuestionDialogMode") Then
		If Buttons = QuestionDialogMode.YesNo Then
			ButtonsParameter = "QuestionDialogMode.YesNo";
		ElsIf Buttons = QuestionDialogMode.YesNoCancel Then
			ButtonsParameter = "QuestionDialogMode.YesNoCancel";
		ElsIf Buttons = QuestionDialogMode.OK Then
			ButtonsParameter = "QuestionDialogMode.OK";
		ElsIf Buttons = QuestionDialogMode.OKCancel Then
			ButtonsParameter = "QuestionDialogMode.OKCancel";
		ElsIf Buttons = QuestionDialogMode.RetryCancel Then
			ButtonsParameter = "QuestionDialogMode.RetryCancel";
		ElsIf Buttons = QuestionDialogMode.AbortRetryIgnore Then
			ButtonsParameter = "QuestionDialogMode.AbortRetryIgnore";
		EndIf;
	Else
		ButtonsParameter = Buttons;
	EndIf;
	
	If TypeOf(Parameters.DefaultButton) = Type("DialogReturnCode") Then
		DefaultButtonParameter = DialogReturnCodeInString(Parameters.DefaultButton);
	Else
		DefaultButtonParameter = Parameters.DefaultButton;
	EndIf;
	
	If TypeOf(Parameters.TimeoutButton) = Type("DialogReturnCode") Then
		TimeoutButtonParameter = DialogReturnCodeInString(Parameters.TimeoutButton);
	Else
		TimeoutButtonParameter = Parameters.TimeoutButton;
	EndIf;
	
	Parameters.Insert("Buttons", ButtonsParameter);
	Parameters.Insert("Timeout", Parameters.Timeout);
	Parameters.Insert("DefaultButton", DefaultButtonParameter);
	Parameters.Insert("Title", Parameters.Title);
	Parameters.Insert("TimeoutButton", TimeoutButtonParameter);
	Parameters.Insert("MessageText", MessageText);
	Parameters.Insert("SuggestDontAskAgain", Parameters.SuggestDontAskAgain);
	Parameters.Insert("Picture", Parameters.Picture);
	
	Result = OpenForm("CommonForm.Question", Parameters, , , , , InteractiveProcessing);
	If TypeOf(Result) = Type("Structure") Then
		DontAskAgain = Result.DontAskAgain;
		Return Result.Value;
	Else
		Return DialogReturnCode.Cancel;
	EndIf;
	
EndFunction

// Returns the structure with ShowQuestionToUser function's AdditionalParameters structure.
// Returns: 
// 	Structure.
Function QuestionToUserParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("DefaultButton", Undefined);
	Parameters.Insert("Timeout", 0);
	Parameters.Insert("TimeoutButton", Undefined);
	Parameters.Insert("Title", GetClientApplicationCaption());
	Parameters.Insert("SuggestDontAskAgain", True);
	Parameters.Insert("DontAskAgain", False);
	Parameters.Insert("LockWholeInterface", False);
	Parameters.Insert("Picture", Undefined);
	Return Parameters;
	
EndFunction	

// Returns value presentation of DialogReturnCode type. 
Function DialogReturnCodeInString(Value)
	
	Result = "DialogReturnCode." + String(Value);
	
	If Value = DialogReturnCode.Yes Then
		Result = "DialogReturnCode.Yes";
	ElsIf Value = DialogReturnCode.No Then
		Result = "DialogReturnCode.No";
	ElsIf Value = DialogReturnCode.OK Then
		Result = "DialogReturnCode.OK";
	ElsIf Value = DialogReturnCode.Cancel Then
		Result = "DialogReturnCode.Cancel";
	ElsIf Value = DialogReturnCode.Retry Then
		Result = "DialogReturnCode.Retry";
	ElsIf Value = DialogReturnCode.Abort Then
		Result = "DialogReturnCode.Abort";
	ElsIf Value = DialogReturnCode.Ignore Then
		Result = "DialogReturnCode.Ignore";
	EndIf;
	
	Return Result;
	
EndFunction

// Displays to user a message form or a message on application exit.
Procedure OpenOnExitMessageForm(Parameters) Export
	
#If WebClient Or ThickClientOrdinaryApplication Then
	Return;
#EndIf

	If SkipExitConfirmation = True Then 
		Return;
	EndIf;
	
	Warnings = New Array;
	StandardSubsystemsClientOverridable.GetWarningList(Warnings);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Parameters", Parameters);
	AdditionalParameters.Insert("FormVariant", "Question");
	
	ResultHandler = New NotifyDescription("AfterCloseExitConfirmationForm",
		ThisObject, AdditionalParameters);
	
	If Warnings.Count() = 0 Then
		
		DontAskAgain = Not StandardSubsystemsClientCached.ClientParameters().AskConfirmationOnExit;
		If DontAskAgain Then
			Return;
		EndIf;
		Parameters.InteractiveProcessing = New NotifyDescription(
			"AskExitConfirmation", ThisObject, ResultHandler);
	Else
		FormParameters = New Structure;
		FormParameters.Insert("Warnings", Warnings);
		
		FormName = "CommonForm.ExitWarnings";
		
		If Warnings.Count() = 1 Then
			If Not IsBlankString(Warnings[0].FlagText) Then 
				AdditionalParameters.Insert("FormVariant", "StandardForm");
				OpenFormParameters = New Structure;
				OpenFormParameters.Insert("FormName", FormName);
				OpenFormParameters.Insert("FormParameters", FormParameters);
				OpenFormParameters.Insert("ResultHandler", ResultHandler);
				Parameters.InteractiveProcessing = New NotifyDescription(
					"InteractiveHandlingApplicationExitWarnings", ThisObject, OpenFormParameters);
			Else
				AdditionalParameters.Insert("FormVariant", "ApplicationForm");
				OpenApplicationWarningForm(Parameters, ResultHandler, Warnings[0], FormName, FormParameters);
			EndIf;
		Else
			AdditionalParameters.Insert("FormVariant", "StandardForm");
			OpenFormParameters = New Structure;
			OpenFormParameters.Insert("FormName", FormName);
			OpenFormParameters.Insert("FormParameters", FormParameters);
			OpenFormParameters.Insert("ResultHandler", ResultHandler);
			Parameters.InteractiveProcessing = New NotifyDescription(
				"InteractiveHandlingApplicationExitWarnings", ThisObject, OpenFormParameters);
		EndIf;
	EndIf;

EndProcedure	

// The continuation of OpenOnExitMessageForm procedure.
Procedure InteractiveHandlingApplicationExitWarnings(Parameters, OpenFormParameters) Export
	
	OpenForm(
		OpenFormParameters.FormName,
		OpenFormParameters.FormParameters, , , , ,
		OpenFormParameters.ResultHandler);
	
EndProcedure
	
// Shows the confirmation of exit the application dialog box.
Procedure AskExitConfirmation(Parameters, ResultProcessing) Export
	
	Buttons = New ValueList;
	Buttons.Add("DialogReturnCode.Yes",  NStr("en='Exit'"));
	Buttons.Add("DialogReturnCode.No", NStr("en='Cancel'"));
	
	QuestionParameters = QuestionToUserParameters();
	QuestionParameters.LockWholeInterface = True;
	QuestionParameters.DefaultButton = "DialogReturnCode.Yes";
	QuestionParameters.Title = NStr("en='Exit confirmation'");
	QuestionParameters.DontAskAgain = False;
	
	ShowQuestionToUser(ResultProcessing, NStr("en='Exit the application?'"), Buttons, QuestionParameters);
	
EndProcedure

// Internal use only.
Procedure AfterCloseExitConfirmationForm(Result, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	
	If AdditionalParameters.FormVariant = "Question" Then
		
		If Result <> Undefined And Result.DontAskAgain Then
			StandardSubsystemsServerCall.SaveExitConfirmationSettings(
				Not Result.DontAskAgain);
		EndIf;
		
		If Result = Undefined Or Result.Value <> DialogReturnCode.Yes Then
			Parameters.Cancel = True;
		EndIf;
		
	ElsIf AdditionalParameters.FormVariant = "StandardForm" Then
	
		If Result = True Or Result = Undefined Then
			Parameters.Cancel = True;
		EndIf;
		
	Else // ApplicationForm
		If Result = True Or Result = Undefined Or Result = DialogReturnCode.No Then
			Parameters.Cancel = True;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Shows a dialog box with a single question.
//	If there is a HyperlinkText property in UserWarning then FormOfIndividualOpening opens 
//	If there is a FlagText property in UserWarning then CommonForm.QuestionBeforeShuttingDownSystem opens.
//
// Parameters:
//	Parameters - Structure - Parameters of the procedure execution.
//	ResultHandler - String - the handler of the form closing result.
//	UserWarning - Structure - passed warning structure.
//	FormName - String - name of a common form with questions.
//	FormParameters - Structure - Parameters for a form with questuons.
//
// Returns:     
//	None.
//
Procedure OpenApplicationWarningForm(Parameters, ResultHandler, UserWarning, FormName, FormParameters)
	
	HyperlinkText = "";
	If Not UserWarning.Property("HyperlinkText", HyperlinkText) Then
		Return;
	EndIf;
	If IsBlankString(HyperlinkText) Then
		Return;
	EndIf;
	
	ActionOnHyperlinkClick = Undefined;
	If Not UserWarning.Property("ActionOnHyperlinkClick", ActionOnHyperlinkClick) Then
		Return;
	EndIf;
	
	ActionHyperlink = UserWarning.ActionOnHyperlinkClick;
	Form = Undefined;
	
	If ActionHyperlink.Property("ApplicationWarningForm", Form) Then
		FormParameters = Undefined;
		If ActionHyperlink.Property("ApplicationWarningFormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ExitApplication", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ExitApplication", True);
			EndIf;
			
			FormParameters.Insert("YesButtonTitle",  NStr("en='Exit'"));
			FormParameters.Insert("NoButtonTitle", NStr("en='Cancel'"));
			
		EndIf;
		OpenFormParameters = New Structure;
		OpenFormParameters.Insert("FormName", Form);
		OpenFormParameters.Insert("FormParameters", FormParameters);
		OpenFormParameters.Insert("ResultHandler", ResultHandler);
		Parameters.InteractiveProcessing = New NotifyDescription(
			"InteractiveHandlingApplicationExitWarnings", ThisObject, OpenFormParameters);
		
	ElsIf ActionHyperlink.Property("Form", Form) Then 
		FormParameters = Undefined;
		If ActionHyperlink.Property("FormParameters", FormParameters) Then
			If TypeOf(FormParameters) = Type("Structure") Then 
				FormParameters.Insert("ExitApplication", True);
			ElsIf FormParameters = Undefined Then 
				FormParameters = New Structure;
				FormParameters.Insert("ExitApplication", True);
			EndIf;
		EndIf;
		OpenFormParameters = New Structure;
		OpenFormParameters.Insert("FormName", Form);
		OpenFormParameters.Insert("FormParameters", FormParameters);
		OpenFormParameters.Insert("ResultHandler", ResultHandler);
		Parameters.InteractiveProcessing = New NotifyDescription(
			"InteractiveHandlingApplicationExitWarnings", ThisObject, OpenFormParameters);
		
	EndIf;
	
EndProcedure

// Updates the client parameters after the interactive handling during the application start.
Procedure RefreshClientParameters(Parameters, FirstCall = False, RefreshReusableValues = True)
	
	If FirstCall Then
		If TypeOf(ParametersOnApplicationStartAndExit) <> Type("Structure") Then
			ParametersOnApplicationStartAndExit = New Structure;
		EndIf;
		
	ElsIf Parameters.RetrievedClientParametersCount =
	          Parameters.RetrievedClientParameters.Count() Then
		Return;
	EndIf;
	
	Parameters.Insert("RetrievedClientParametersCount",
		Parameters.RetrievedClientParameters.Count());
	
	ParametersOnApplicationStartAndExit.Insert("RetrievedClientParameters",
		Parameters.RetrievedClientParameters);
	
	If RefreshReusableValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

// Internal use only.
Function OnStartInteractiveProcessingInProgress()
	
	If Not ParametersOnApplicationStartAndExit.Property("ProcessingParameters") Then
		Return False;
	EndIf;
	
	Parameters = ParametersOnApplicationStartAndExit.ProcessingParameters;
	
	If Parameters.InteractiveProcessing <> Undefined Then
		Parameters.SolidProcessing = False;
		InteractiveProcessing = Parameters.InteractiveProcessing;
		Parameters.InteractiveProcessing = Undefined;
		ExecuteNotifyProcessing(InteractiveProcessing, Parameters);
		ParametersOnApplicationStartAndExit.Delete("ProcessingParameters");
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Internal use only.
Procedure HandleStartExitError(Parameters, ErrorInfo, Event, Exit = False)
	
	If Event = "Start" Then
		If Exit Then
			Parameters.Cancel = True;
			Parameters.ContinuationHandler = Parameters.ContinuationHandler;
		EndIf;
	Else
		AdditionalParameters = New Structure(
			"Parameters, ContinuationHandler", Parameters, Parameters.ContinuationHandler);
		
		Parameters.ContinuationHandler = New NotifyDescription(
			"ActionsBeforeStartAfterErrorProcessing", ThisObject, AdditionalParameters);
	EndIf;
	
	ErrorDescriptionBegin = StandardSubsystemsServerCall.WriteErrorToEventLogOnStartOrExit(
		Exit, Event, DetailErrorDescription(ErrorInfo));	
	
	WarningText = ErrorDescriptionBegin + Chars.LF
		+ NStr("en='The technical information is written to the Event log.'")
		+ Chars.LF + Chars.LF
		+ BriefErrorDescription(ErrorInfo);
	
	InteractiveProcessing = New NotifyDescription(
		"ShowMessageBoxAndContinue",
		StandardSubsystemsClient.ThisObject,
		WarningText);
	
	Parameters.InteractiveProcessing = InteractiveProcessing;
	
EndProcedure

// Internal use only.
Function OnStartInteractiveProcessing(Parameters)
	
	If Parameters.InteractiveProcessing = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionHandler);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	InteractiveProcessing = Parameters.InteractiveProcessing;
	
	Parameters.SolidProcessing = False;
	Parameters.InteractiveProcessing = Undefined;
	
	ExecuteNotifyProcessing(InteractiveProcessing, Parameters);
	
	Return True;
	
EndFunction

// Internal use only.
Procedure SetInterfaceFunctionalOptionParametersOnStart()
	InterfaceOptions = StandardSubsystemsClientCached.ClientParametersOnStart().InterfaceOptions;
	If TypeOf(InterfaceOptions) = Type("FixedStructure") Then
		#If WebClient Then
			Structure = New Structure;
			CommonUseClientServer.SupplementStructure(Structure, InterfaceOptions, True);
			InterfaceOptions = Structure;
		#Else
			InterfaceOptions = New Structure(InterfaceOptions);
		#EndIf
	EndIf;

	If InterfaceOptions.Count() > 0 Then
		SetInterfaceFunctionalOptionParameters(InterfaceOptions);
	EndIf;
	
EndProcedure

// Internal use only.
Function InteractiveBeforeStartProcessing(Parameters)
	
	If Parameters.InteractiveProcessing = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionHandler);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	RefreshClientParameters(Parameters);
	
	If Not Parameters.SolidProcessing Then
		InteractiveProcessing = Parameters.InteractiveProcessing;
		Parameters.InteractiveProcessing = Undefined;
		ExecuteNotifyProcessing(InteractiveProcessing, Parameters);
		
	ElsIf Parameters.CompletionNotification = Undefined Then
		ParametersOnApplicationStartAndExit.Insert("ProcessingParameters", Parameters);
		HideDesktopOnStart();
		ParametersOnApplicationStartAndExit.Insert("SkipClearingDesktopHiding");
		SetInterfaceFunctionalOptionParametersOnStart();
	Else
		If ParametersOnApplicationStartAndExit.Property("ProcessingParameters") Then
			ParametersOnApplicationStartAndExit.Delete("ProcessingParameters");
		EndIf;
		
		Parameters.SolidProcessing = False;
		InteractiveProcessing = Parameters.InteractiveProcessing;
		Parameters.InteractiveProcessing = Undefined;
		ExecuteNotifyProcessing(InteractiveProcessing, Parameters);
	EndIf;
	
	Return True;
	
EndFunction

// Internal use only.
Function InteractiveOnStartProcessing(Parameters)
	
	If Parameters.InteractiveProcessing = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionHandler);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	InteractiveProcessing = Parameters.InteractiveProcessing;
	
	Parameters.SolidProcessing = False;
	Parameters.InteractiveProcessing = Undefined;
	
	ExecuteNotifyProcessing(InteractiveProcessing, Parameters);
	
	Return True;
	
EndFunction

// Internal use only.
Function InteractiveBeforeExitProcessing(Parameters)
	
	If Parameters.InteractiveProcessing = Undefined Then
		If Parameters.Cancel Then
			ExecuteNotifyProcessing(Parameters.CompletionHandler);
			Return True;
		EndIf;
		Return False;
	EndIf;
	
	If Not Parameters.SolidProcessing Then
		InteractiveProcessing = Parameters.InteractiveProcessing;
		Parameters.InteractiveProcessing = Undefined;
		ExecuteNotifyProcessing(InteractiveProcessing, Parameters);
		
	ElsIf Parameters.CompletionNotification = Undefined Then
		ParametersOnApplicationStartAndExit.Insert("CompletionNotificationParameters", Parameters);
		Parameters.SolidProcessing = False;
		AttachIdleHandler(
			"BeforeExitInteractiveProcessingIdleHandler", 0.1, True);
	Else
		Parameters.SolidProcessing = False;
		InteractiveProcessing = Parameters.InteractiveProcessing;
		Parameters.InteractiveProcessing = Undefined;
		ExecuteNotifyProcessing(InteractiveProcessing, Parameters);
	EndIf;
	
	Return True;
	
EndFunction

// Internal use only.
Procedure InteractiveRestoreConnectionToMasterNodeProcessing(Parameters, NotSet) Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If ClientParameters.RestoreConnectionToMasterNode = False Then
		Parameters.Cancel = True;
		ShowMessageBox(
			NotificationWithoutResult(Parameters.ContinuationHandler),
			NStr("en='Unable to log on the application until the connection to the master node will be restored."
"Contact the administrator for details.'"),
			15);
		Return;
	EndIf;
	
	Form = OpenForm("CommonForm.ReconnectionToMasterNode",,,,,,
		New NotifyDescription("AfterCloseReconnectionToMasterNodeForm", ThisObject, Parameters));
	
	If Form = Undefined Then
		AfterCloseReconnectionToMasterNodeForm(New Structure("Cancel", True), Parameters);
	EndIf;
	
EndProcedure

// Internal use only.
Procedure AfterCloseReconnectionToMasterNodeForm(Result, Parameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Parameters.Cancel = True;
		
	ElsIf Result.Cancel Then
		Parameters.Cancel = True;
	Else
		Parameters.RetrievedClientParameters.Insert("RestoreConnectionToMasterNode");
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor);
	
EndProcedure

// Internal use only.
Function NotificationWithoutResult(NotificationWithResult) Export
	
	Return New NotifyDescription("ProcessNotificationWithEmptyResult", ThisObject, NotificationWithResult);
	
EndFunction

// Internal use only.
Function ContinueActionsBeforeStart(Parameters)
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
		Return False;
	EndIf;
	
	RefreshClientParameters(Parameters);
	
	Return True;
	
EndFunction

// Internal use only.
Procedure ActionsBeforeStartCompletionHandler(NotSet, Parameters) Export
	
	ParametersOnApplicationStartAndExit.Delete("RetrievedClientParameters");
	
	If Parameters.CompletionNotification <> Undefined Then
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalParametersOfCommandLine", Parameters.AdditionalParametersOfCommandLine);
		ExecuteNotifyProcessing(Parameters.CompletionNotification, Result);
		Return;
	EndIf;
	
	If Parameters.Cancel Then
		If Parameters.Restart <> True Then
			Terminate();
		ElsIf ValueIsFilled(Parameters.AdditionalParametersOfCommandLine) Then
			Terminate(Parameters.Restart, Parameters.AdditionalParametersOfCommandLine);
		Else
			Terminate(Parameters.Restart);
		EndIf;
		
	ElsIf Not Parameters.SolidProcessing Then
		If ParametersOnApplicationStartAndExit.Property("ProcessingParameters") Then
			ParametersOnApplicationStartAndExit.Delete("ProcessingParameters");
		EndIf;
		AttachIdleHandler("OnStartIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterCheckPlatformVersion(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartAfterRestoreConnectionToMasterNode", ThisObject, Parameters));
	
	Try
		CheckRestoreConnectionToMasterNodeRequired(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler, False);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterRestoreConnectionToMasterNode(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.ServiceMode") Then
		
		Parameters.Insert("ContinuationHandler", Parameters.CompletionHandler);
		Try
			ServiceModeClientModule = CommonUseClient.CommonModule("ServiceModeClient");
			ServiceModeClientModule.BeforeStart(Parameters);
		Except
			HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If InteractiveBeforeStartProcessing(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartAfterLegalityCheck", ThisObject, Parameters));
	
	If CommonUseClient.SubsystemExists(
		   "StandardSubsystems.UpdateObtainingLegalityCheck") Then
		
		Try
			UpdateObtainingLegalityCheckClientModule =
				CommonUseClient.CommonModule("UpdateObtainingLegalityCheckClient");
			
			UpdateObtainingLegalityCheckClientModule.CheckUpdateObtainingLegalityOnStart(Parameters);
		Except
			HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If InteractiveBeforeStartProcessing(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler, False);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterLegalityCheck(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartAfterRepeatImportDataExchangeMessage", ThisObject, Parameters));
	
	Try
		If CommonUseClient.SubsystemExists("StandardSubsystems.DataExchange") Then
			DataExchangeClientModule = CommonUseClient.CommonModule("DataExchangeClient");
			DataExchangeClientModule.BeforeStart(Parameters);
		EndIf;
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler, False);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterRepeatImportDataExchangeMessage(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If ClientParameters.CanUseSeparatedData Then
		
		Parameters.Insert("ContinuationHandler", New NotifyDescription(
			"ActionsBeforeStartAfterRefreshClientParameters", ThisObject, Parameters));
	Else
		Parameters.Insert("ContinuationHandler", New NotifyDescription(
			"ActionsBeforeStartAfterOverridableProcedure", ThisObject, Parameters));
	EndIf;
	
	Try
		InfoBaseUpdateClient.BeforeStart(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterRefreshClientParameters(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionHandler);
	
	Try
		UsersInternalClient.BeforeStart(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	Try
		SetAdvancedSystemTitle(True); 
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartAfterProcessingLogOnWithUnlockCode", ThisObject, Parameters));
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.UserSessions") Then
		
		Try
			InfoBaseConnectionsClientModule = CommonUseClient.CommonModule("InfoBaseConnectionsClient");
			InfoBaseConnectionsClientModule.BeforeStart(Parameters);
		Except
			HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If InteractiveBeforeStartProcessing(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterProcessingLogOnWithUnlockCode(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("NextHandlerNumber", 1);
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartInInternalEventHandlers", ThisObject, Parameters));
	
	Try
		InfoBaseUpdateClient.UpdateInfobase(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler, False);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterOverridableProcedure(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionHandler);
	
	Try
		SetInterfaceFunctionalOptionParametersOnStart();
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartInInternalEventHandlers(NotSet, Parameters) Export
	
	If Not ContinueActionsBeforeStart(Parameters) Then
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\BeforeStart");
	
	EventHandlerCount = EventHandlers.Count();
	FirstNumber = Parameters.NextHandlerNumber;
	
	For Number = FirstNumber To EventHandlerCount Do
		Parameters.InteractiveProcessing = Undefined;
		Parameters.NextHandlerNumber = Number + 1;
		Handler = EventHandlers.Get(Number - 1);
		
		Try
			Handler.Module.BeforeStart(Parameters);
		Except
			HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
		EndTry;
		If InteractiveBeforeStartProcessing(Parameters) Then
			Return;
		EndIf;
	EndDo;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeStartAfterOverridableProcedure", ThisObject, Parameters));
	
	Parameters.InteractiveProcessing = Undefined;
		
	Try
		CommonUseClientOverridable.BeforeStart(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start", True);
	EndTry;
	If InteractiveBeforeStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeStartAfterErrorProcessing(NotSet, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	Parameters.ContinuationHandler = AdditionalParameters.ContinuationHandler;
	
	If Parameters.Cancel Then
		Parameters.Cancel = False;
		ExecuteNotifyProcessing(Parameters.CompletionHandler);
	Else
		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	EndIf;
	
EndProcedure

// Internal use only.
Procedure ActionsOnStartCompletionHandler(NotSet, Parameters) Export
	
	If Not Parameters.Cancel Then
		If ParametersOnApplicationStartAndExit.Property("SkipClearingDesktopHiding") Then
			ParametersOnApplicationStartAndExit.Delete("SkipClearingDesktopHiding");
		EndIf;
		HideDesktopOnStart(False);
	EndIf;
	
	If Parameters.CompletionNotification <> Undefined Then
		
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		Result.Insert("Restart", Parameters.Restart);
		Result.Insert("AdditionalParametersOfCommandLine", Parameters.AdditionalParametersOfCommandLine);
		ExecuteNotifyProcessing(Parameters.CompletionNotification, Result);
		Return;
		
	Else
		If Parameters.Cancel Then
			If Parameters.Restart <> True Then
				Terminate();
				
			ElsIf ValueIsFilled(Parameters.AdditionalParametersOfCommandLine) Then
				Terminate(Parameters.Restart, Parameters.AdditionalParametersOfCommandLine);
			Else
				Terminate(Parameters.Restart);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Internal use only.
Procedure ActionsOnStartInInternalEventHandlers(NotSet, Parameters) Export

	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionHandler);
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\OnStart");
	
	EventHandlerCount = EventHandlers.Count();
	If EventHandlerCount > 0 Then
		FirstNumber = Parameters.NextHandlerNumber;
		
		For Number = FirstNumber To EventHandlerCount Do
			Parameters.NextHandlerNumber = Number + 1;
			Handler = EventHandlers.Get(Number - 1);
			
			Try
				Handler.Module.OnStart(Parameters);
			Except
				HandleStartExitError(Parameters, ErrorInfo(), "Start");
			EndTry;
			If InteractiveOnStartProcessing(Parameters) Then
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	Parameters.Insert("NextHandlerNumber", 1);
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsAfterStartInInternalEventHandlers", ThisObject, Parameters));
	
	Try
		CommonUseClientOverridable.OnStart(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start");
	EndTry;
	If InteractiveOnStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsAfterStartInInternalEventHandlers(NotSet, Parameters) Export

	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionHandler);
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\AfterStart");
	
	EventHandlerCount = EventHandlers.Count();
	FirstNumber = Parameters.NextHandlerNumber;
	
	For Number = FirstNumber To EventHandlerCount Do
		Parameters.NextHandlerNumber = Number + 1;
		Handler = EventHandlers.Get(Number - 1);
		
		Try
			Handler.Module.AfterStart();
		Except
			HandleStartExitError(Parameters, ErrorInfo(), "Start");
		EndTry;
		If InteractiveOnStartProcessing(Parameters) Then
			Return;
		EndIf;
	EndDo;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionHandler);
	Try
		CommonUseClientOverridable.AfterStart();
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Start");
	EndTry;
	If InteractiveOnStartProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeExitCompletionHandler(NotSet, Parameters) Export
	
	If Parameters.CompletionNotification <> Undefined Then
		
		Result = New Structure;
		Result.Insert("Cancel", Parameters.Cancel);
		ExecuteNotifyProcessing(Parameters.CompletionNotification, Result);
		
	ElsIf Not Parameters.Cancel And Not Parameters.SolidProcessing Then
		
		ParametersOnApplicationStartAndExit.Insert("ActionsBeforeExitCompleted");
		Exit(True);
		//Terminate();
	EndIf;
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeExitInInternalEventHandlers(NotSet, Parameters) Export

	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionHandler);
		Return;
	EndIf;
	
	EventHandlers = CommonUseClient.InternalEventHandlers(
		"StandardSubsystems.BaseFunctionality\BeforeExit");
		
	If EventHandlers = Undefined Then
		Return;
	EndIf;
	EventHandlerCount = EventHandlers.Count();
	FirstNumber = Parameters.NextHandlerNumber;
	
	For Number = FirstNumber To EventHandlerCount Do
		Parameters.NextHandlerNumber = Number + 1;
		Handler = EventHandlers.Get(Number - 1);
		
		Try
			Handler.Module.BeforeExit(Parameters);
		Except
			HandleStartExitError(Parameters, ErrorInfo(), "Exit");
		EndTry;
		If InteractiveOnStartProcessing(Parameters) Then
			Return;
		EndIf;
	EndDo;
	
	Parameters.Insert("ContinuationHandler", New NotifyDescription(
		"ActionsBeforeExitAfterInternalEventHandlers", ThisObject, Parameters));
	
	Try
		CommonUseClientOverridable.BeforeExit(Parameters);
	Except
		HandleStartExitError(Parameters, ErrorInfo(), "Exit");
	EndTry;
	If InteractiveBeforeExitProcessing(Parameters) Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeExitAfterInternalEventHandlers(NotSet, Parameters) Export
	
	If Parameters.Cancel Then
		ExecuteNotifyProcessing(Parameters.CompletionHandler);
		Return;
	EndIf;
	
	If TypeOf(MessagesForEventLog) = Type("ValueList") And MessagesForEventLog.Count() <> 0 Then
		CommonUse.WriteEventsToEventLog(MessagesForEventLog);
	EndIf;
	
	Parameters.Insert("ContinuationHandler", Parameters.CompletionHandler);
	If StandardSubsystemsClientCached.ClientParameters().CanUseSeparatedData Then
		Try
			OpenOnExitMessageForm(Parameters);
		Except
			HandleStartExitError(Parameters, ErrorInfo(), "Exit");
		EndTry;
		If InteractiveBeforeExitProcessing(Parameters) Then
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure ActionsBeforeExitAfterErrorProcessing(NotSet, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	Parameters.ContinuationHandler = AdditionalParameters.ContinuationHandler;
	
	If Parameters.Cancel Then
		Parameters.Cancel = False;
		ExecuteNotifyProcessing(Parameters.CompletionHandler);
	Else
		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	EndIf;
	
EndProcedure

// Internal use only.
Procedure SetSessionSeparation()

	If IsBlankString(LaunchParameter) Then
		Return;
	EndIf;
	
	LaunchParameters = StringFunctionsClientServer.SplitStringIntoSubstringArray(LaunchParameter, ";");
	LaunchParameterValue = Upper(LaunchParameters[0]);
	
	If LaunchParameterValue <> Upper("LogOnToDataArea") Then
		Return;
	EndIf;
	
	If LaunchParameters.Count() < 2 Then
		Raise
			NStr("en='When LogOnToDataArea startup parameter is specified, "
"the separator value should be specified as well.'");
	EndIf;
	
	Try
		SeparatorValue = Number(LaunchParameters[1]);
	Except
		Raise
			NStr("en='The separator value in LogOnToDataArea parameter should be a number.'");
	EndTry;
	
	CommonUse.SetSessionSeparation(True, SeparatorValue);
	
EndProcedure 

// Internal use only.
Procedure HideDesktopOnStart(Hide = True, AlreadyExecutedOnServer = False) Export
	
	If Hide Then
		If Not ParametersOnApplicationStartAndExit.Property("HideDesktopOnStart") Then
			ParametersOnApplicationStartAndExit.Insert("HideDesktopOnStart");
			If Not AlreadyExecutedOnServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart();
			EndIf;
		EndIf;
	Else
		If ParametersOnApplicationStartAndExit.Property("HideDesktopOnStart") Then
			ParametersOnApplicationStartAndExit.Delete("HideDesktopOnStart");
			If Not AlreadyExecutedOnServer Then
				StandardSubsystemsServerCall.HideDesktopOnStart(False);
			EndIf;
			CurrentActiveWindow = ActiveWindow();
			RefreshInterface();
			If CurrentActiveWindow <> Undefined Then
				CurrentActiveWindow.Activate();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Internal use only.
Procedure CheckRestoreConnectionToMasterNodeRequired(Parameters)
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	
	If Not ClientParameters.Свойство("RestoreConnectionToMasterNode") Then
		Return;
	EndIf;
	
	Parameters.InteractiveProcessing = New NotifyDescription(
		"InteractiveRestoreConnectionToMasterNodeProcessing", ThisObject, Parameters);
	
EndProcedure

// Internal use only.
Procedure ShowMessageBoxAndContinue(Parameters, MessageText) Export
	
	NotificationWithResult = Parameters.ContinuationHandler;
	
	If MessageText = Undefined Then
		ExecuteNotifyProcessing(NotificationWithResult);
		Return;
	EndIf;
		
	If Parameters.Cancel Then
		
		Buttons = New ValueList();
		Buttons.Add("Restart", NStr("en='Restart application'"));
		Buttons.Add("Exit",    NStr("en='Exit application'"));
		
		QuestionParameters = QuestionToUserParameters();
		QuestionParameters.DefaultButton = "Restart";
		QuestionParameters.TimeoutButton    = "Restart";
		QuestionParameters.Timeout = 60;
		QuestionParameters.SuggestDontAskAgain = False;
		QuestionParameters.LockWholeInterface = True;
		QuestionParameters.Picture = PictureLib.Warning32;
		
	Else

		Buttons = New ValueList();
		Buttons.Add("Continue", NStr("en='Continue'"));
		If Parameters.Property("Restart") Then
			Buttons.Add("Restart", NStr("en='Restart'"));
		EndIf;
		Buttons.Add("Exit", NStr("en='Exit the application'"));
		
		QuestionParameters = QuestionToUserParameters();
		QuestionParameters.DefaultButton = "Continue";
		QuestionParameters.SuggestDontAskAgain = False;
		QuestionParameters.LockWholeInterface = True;
		QuestionParameters.Picture = PictureLib.Warning32;
		
	EndIf;
	
	ExitNotification = New NotifyDescription("ShowMessageBoxAndContinueCompletion", ThisObject, Parameters);
	ShowQuestionToUser(ExitNotification, MessageText, Buttons, QuestionParameters);
	
EndProcedure

// Internal use only.
Procedure ShowMessageBoxAndContinueCompletion(Result, Parameters) Export
	
	If Result <> Undefined Then
		If Result.Value = "Exit" Then
			Parameters.Cancel = True;
		ElsIf Result.Value = "Restart" Then
			Parameters.Cancel = True;
			Parameters.Restart = True;
		EndIf;
	EndIf;
	ExecuteNotifyProcessing(Parameters.ContinuationHandler);
	
EndProcedure

// Internal use only.
Procedure StartInteractiveBeforeExitProcessing() Export
	
	If Not ParametersOnApplicationStartAndExit.Property("CompletionNotificationParameters") Then
		Return;
	EndIf;
	
	Parameters = ParametersOnApplicationStartAndExit.CompletionNotificationParameters;
	ParametersOnApplicationStartAndExit.Delete("CompletionNotificationParameters");
	
	ExecuteNotifyProcessing(Parameters.InteractiveProcessing, Parameters);
	
EndProcedure
