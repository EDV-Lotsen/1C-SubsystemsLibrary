////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Sets an application main window caption, using the current user presentation,
// value of the ApplicationCaption constant, and default application caption.
//
Procedure SetAdvancedApplicationTitle() Export
	
	If CommonUseCached.CanUseSeparatedData() Then
		ClientParameters = StandardSubsystemsClientCached.ClientParameters();
		CaptionPresentation = ClientParameters.ApplicationCaption;
		UserPresentation = ClientParameters.AuthorizedUser;
		ConfigurationPresentation = ClientParameters.DetailedInformation;
		
		
		If IsBlankString(TrimAll(CaptionPresentation )) Then
			If ClientParameters.Property("DataAreaPresentation") Then
				TitleTemplate = "%1 / %2 / %3 / ";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(TitleTemplate, 
					ClientParameters.DataAreaPresentation, ClientParameters.DetailedInformation, 
					UserPresentation);
			Else
				TitleTemplate = "%1 / %2 / ";
				ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(TitleTemplate, 
					ClientParameters.DetailedInformation, UserPresentation);
			EndIf;
		Else
			TitleTemplate = "%1 / %2 / %3 / ";
			ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(TitleTemplate, 
				TrimAll(CaptionPresentation ), UserPresentation, ConfigurationPresentation);
		EndIf;
		
		SetApplicationCaption(ApplicationCaption);
	Else
		TitleTemplate = "%1 / %2 / ";
		ApplicationCaption = StringFunctionsClientServer.SubstituteParametersInString(TitleTemplate, 
			NStr("en = 'Separators are not set"), CommonUse.GetConfigurationDetails());
		
		SetApplicationCaption(ApplicationCaption);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Standard actions executed before appication start.
//
// Parameters:
// Cancel - Boolean - flag that shows whether execution is canceled. 
// If it is set to True then application will not start.
//
Procedure ActionsBeforeStart(Cancel) Export
	
	If InfoBaseUpdate.FirstRun() Then
		
		If Find(LaunchParameter, "InitSeparatedInfoBase") <> 0 Then


			
			CommonUse.SetInfoBaseSeparationParameters(True);
			
			Terminate(True, "/CNoParameters");
		EndIf;
		
	EndIf;
	
	CanUseSeparatedData = CommonUseCached.CanUseSeparatedData();
	
	If Not CanUseSeparatedData Then
		InfoBaseUpdate.ExecuteInfoBaseUpdate();
	EndIf;
	
	If Not IsBlankString(LaunchParameter) Then
		LaunchParameters = StringFunctionsClientServer.SplitStringIntoSubstringArray(LaunchParameter, ";");
		LaunchParameterValue = Upper(LaunchParameters[0]);
		
		If LaunchParameterValue = Upper("LogOnDataArea") Then
			If LaunchParameters.Count() < 2 Then
				Raise(NStr("en = 'If the LogOnDataArea startup parameter is specified,
						|the separator parameter must be specified too.''"));
			EndIf;
			
			Try
				SeparatorValue = Number(LaunchParameters[1]);
			Except
				Raise(NStr("en = 'The separator value must be a number.'"));
			EndTry;
			
			CommonUse.SetSessionSeparation(True, SeparatorValue);
			CanUseSeparatedData = True;
		EndIf;
	EndIf;
	
	If CanUseSeparatedData Then
		
		StandardSubsystemsClientOverridable.BeforeStart(Cancel);
		
		If Cancel Then
			Return;
		EndIf;
		
		CommonUseClientOverridable.BeforeStart(Cancel);
		
	EndIf;
	
EndProcedure

// Standard actions executed on appication start.
//
// Parameters
// ProcessLaunchParameters - Boolean - True if the handler is called on 
// a direct application launch and it should processes launch parameters
// (if its logic specifies such processing). False if the handler is called on 
// a shared user interactive logon to a data area and it 
// should not processes launch parameters.
//
Procedure ActionsOnStart(ProcessLaunchParameters = True) Export
	
	StandardSubsystemsClientOverridable.OnStart(ProcessLaunchParameters);
	CommonUseClientOverridable.OnStart(ProcessLaunchParameters);
	
EndProcedure

// Corresponds to the BeforeExit handler
//
// Parameters:
// Cancel - Boolean - flag that shows whether exit from the application is canceled. 
//
Procedure ActionsBeforeExit(Cancel) Export
	
	StandardSubsystemsClientOverridable.BeforeExit(Cancel);
	
	If Cancel = True Then
		Return;
	EndIf;
	
	CommonUseClientOverridable.BeforeExit(Cancel);
	
EndProcedure

// Shows the exit confirmation dialog to the user.
//
// Parameters:
// Cancel - Boolean - flag that shows whether exit from the application is canceled. 
//
// Returns:
// Boolean - True, if the user canceled exit from the application;
// False, if the user confirmed exit from the application, or exit dialog was not called.
//
Function AskExitConfirmation(Cancel) Export
	
	// If exit confirmation is not disabled in configuration, checking if it is enabled in user settings
	If SkipExitConfirmation <> True Then 
		SkipExitConfirmation = Not StandardSubsystemsServerCall.LoadOnExitConfirmationSetting();
	EndIf;
	If SkipExitConfirmation Then
		Return False;
	EndIf;
	
	DontAskAgain = Not StandardSubsystemsClientCached.ClientParameters().AskConfirmationOnExit;
	If DontAskAgain Then
		Return False;
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("DialogReturnCode.Yes",	NStr("en = 'Exit'"));
	Buttons.Add("DialogReturnCode.No",	NStr("en = 'Cancel'"));
	
	Result = QuestionToUser(NStr("en = 'Are you sure you want to exit application?'"), Buttons, , DialogReturnCode.Yes, NStr("en = 'Exit'"), 
		DialogReturnCode.No, DontAskAgain);
	If DontAskAgain Then
		StandardSubsystemsServerCall.SaveExitConfirmationSettings(Not DontAskAgain);
	EndIf;
	
	If Result <> DialogReturnCode.Yes Then
		Cancel = True;
		Return True;
	EndIf;
	
	Return False
	
EndFunction

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
Function CheckPlatformVersionAtStart(CallPosition) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		Return True;
	EndIf;
	
	// For the ordinary mode checking is executed in the "OnStart" handler.
	// For the managed mode checking is executing in the "BeforeStart" handler.
	#If ThickClientOrdinaryApplication Then 
		If CallPosition = "BeforeStart" Then 
			Return True;
		EndIf;
	#Else
		If CallPosition = "OnStart" Then 
			Return True;
		EndIf;
	#EndIf	
	
	CheckParameters = New FixedStructure("PlatformVersion, MustExit", "8.2.15.310", False);
	StandardSubsystemsClientOverridable.GetMinRequiredPlatformVersion(CheckParameters);
	
	Return CheckPlatformVersion(CheckParameters.PlatformVersion, CheckParameters.MustExit);
	
EndFunction	

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
Function CheckPlatformVersion(Val RecommendedPlatformVersion, Val MustExit = False) Export
	
	SystemInfo = New SystemInfo;
	If CommonUseClientServer.CompareVersions(SystemInfo.AppVersion, RecommendedPlatformVersion) >= 0 Then
		Return True;
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
	Result = OpenFormModal("CommonForm.NotRecommendedPlatformVersion", Parameters);
	If MustExit Then
		Terminate();
		Return False;
	ElsIf Result = DialogReturnCode.OK Then
		Terminate();
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Causes a question form.
//
// Parameters:
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
Function QuestionToUser(MessageText, Buttons, Timeout = 0, DefaultButton = Undefined, Title = "", 
	TimeoutButton = Undefined, DontAskAgain = False) Export
	
	DontAskAgain = False;
	
	Parameters = New Structure;
	
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
	
	If TypeOf(DefaultButton) = Type("DialogReturnCode") Then
		DefaultButtonParameter = DialogReturnCodeInString(DefaultButton);
	Else
		DefaultButtonParameter = DefaultButton;
	EndIf;
	
	If TypeOf(TimeoutButton) = Type("DialogReturnCode") Then
		TimeoutButtonParameter = DialogReturnCodeInString(TimeoutButton);
	Else
		TimeoutButtonParameter = TimeoutButton;
	EndIf;
	
	Parameters.Insert("Buttons", ButtonsParameter);
	Parameters.Insert("Timeout", Timeout);
	Parameters.Insert("DefaultButton", DefaultButtonParameter);
	Parameters.Insert("Title", Title);
	Parameters.Insert("TimeoutButton", TimeoutButtonParameter);
	Parameters.Insert("MessageText", MessageText);
	
	Result = OpenFormModal("CommonForm.Question", Parameters);
	If TypeOf(Result) = Type("Structure") Then
		DontAskAgain = Result.DontAskAgain;
		Return Result.Value;
	Else
		Return DialogReturnCode.Cancel;
	EndIf;
	
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
// 
//
// Parameters:
// Cancel - Boolean - flag that shows whether exit is canceled.
//
Procedure OpenOnExitMessageForm(Cancel) Export
	Warnings = New Array;
	StandardSubsystemsClientOverridable.GetWarningList(Warnings);
	
	TransferParameters = New Structure;
	TransferParameters.Insert("Warnings", Warnings);
	
	FormName = "CommonForm.ExitWarnings";
	
	If Warnings.Count() = 0 Then
		If AskExitConfirmation(Cancel) Then
			Return;
		EndIf;
	ElsIf Warnings.Count() = 1 Then
		Cancel = OpenApplicationWarningForm(Warnings.Get(0), FormName, TransferParameters);
	ElsIf Warnings.Count() > 1 Then	
		Cancel = OpenFormModal(FormName, TransferParameters);
	EndIf;	
EndProcedure	

// Generatess one question presentation.
//
//	If there is a HyperlinkText property in UserWarning then FormOfIndividualOpening opens 
//	If there is a FlagText property in UserWarning then CommonForm.QuestionBeforeShuttingDownSystem opens.
//
// Parameters:
//	UserWarning - Structure - passed warning structure.
//	FormName - String - name of a common form with questions.
//	TransferParameters - Structure - Parameters for a form with questuons.
//
// Returns:
//	Boolean - True, if the form is opened, False in the other way.
//
Function OpenApplicationWarningForm(UserWarning, FormName, TransferParameters)
	Cancel = False;
	
	FlagText = "";
	If UserWarning.Property("FlagText", FlagText) Then 
		If Not IsBlankString(FlagText) Then 
			Cancel = OpenFormModal(FormName, TransferParameters);
		EndIf;
			
		Return Cancel;
	EndIf;	
	
	HyperlinkText = "";
	If UserWarning.Property("HyperlinkText", HyperlinkText) Then 
		If Not IsBlankString(HyperlinkText) Then 
			ActionOnHyperlinkClick = Undefined;
			If UserWarning.Property("ActionOnHyperlinkClick", ActionOnHyperlinkClick) Then 
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
						
						FormParameters.Insert("YesButtonTitle",	"Exit");
						FormParameters.Insert("TitleNoButton",	"Cancel");
						
					EndIf;
					Response = OpenFormModal(Form, FormParameters);
					Cancel = GetFormResponse(Response);
					
					Return Cancel;
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
					Response = OpenFormModal(Form, FormParameters);
					Cancel = GetFormResponse(Response);
					
					Return Cancel;
				EndIf;	
			EndIf;	
		EndIf;
			
		Return Cancel;
	EndIf;	
	
	Return Cancel;
EndFunction

// Defines cancel by the form response.
//
// Parameters:
//	Response - Form response.
Function GetFormResponse(Response)
	Return Response = Undefined or Response = DialogReturnCode.No or Response = True;
EndFunction	
	
		
	
	