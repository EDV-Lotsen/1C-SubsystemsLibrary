////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Client procedures and functions of common use:
// - for working with lists on forms;
// - for working with the event log;
// - for user action processing during the user works with 
// multiline text like comments in documents;
// - others.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Functions for working with lists on forms 

// Checks that there is a parameter of ExpectedType in Parameter.
// Otherwise this function shows a message box and returns False.
// This situation is possible, for example, when a row that contains a group is selected in list.
//
// The function is to be used in commands that work with dynamic list items in forms.
// Use example:
// 
// If Not CheckCommandParameterType(Items.List.SelectedRows, 
// Type("TaskRef.PerformerTask")) Then
// Return;
// EndIf;
// ...
// 
// Parameters:
// Parameter - Array or reference type - command parameter.
// ExpectedType - Type - expected parameter type.
//
// Returns:
// Boolean - True if the parameter type is the expected type.
//
Function CheckCommandParameterType(Val Parameter, Val ExpectedType) Export
	
	If Parameter = Undefined Then
		Return False;
	EndIf;
	
	Result = True;
	
	If TypeOf(Parameter) = Type("Array") Then
		// If there is only one item in the array and a type of it is incorrect
		Result = Not (Parameter.Count() = 1 And TypeOf(Parameter[0]) <> ExpectedType);
	Else
		Result = TypeOf(Parameter) = ExpectedType;
	EndIf;
	
	If Not Result Then
		DoMessageBox(NStr("en = 'Command can not be executed for the current object.'"));
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Common use client procedures

// Returns the current date in the session time zone.
//
// Returned time is close to the CurrentSessionDate() function result in the server context.
// Error is related to server call execution time.
// Function is to be used instead of CurrentDate().
//
Function SessionDate() Export
	Return CurrentDate() + StandardSubsystemsClientCached.ClientParameters().SessionTimeOffset;
EndFunction

// Suggests user to install the file system extension at the web client.
// It initializes the SuggestFileSystemExtensionInstallation session parameter.
//
// The function is to be used in the beginning of script parts worked with files.
// Example:
//
// SuggestFileSystemExtensionInstallationNow("Document printing requires installation of the file system extension.");
// // document printing script
// //...
//
// Parameters
// SuggestionText - String - message text. If text is not specified default text is displayed.
// 
// Returns:
// String - possible values:
// Attached - extension is installed
// NotAttached - user refused to install extension
// UnsupportedWebClient - extension cannot be installed because the corrent web client does not support it
//
Function SuggestFileSystemExtensionInstallationNow(SuggestionText = Undefined) Export
	
#If WebClient Then
	ExtensionAttached = AttachFileSystemExtension();
	If ExtensionAttached Then
		Return "Attached"; // extension is already installed, there is no need to ask about it
	EndIf;
	
	If CommonUseClientCached.IsWebClientWithoutFileSystemExtension() Then
		Return "UnsupportedWebClient";
	EndIf;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	FirstCallInSession = False;
	
	If SuggestFileSystemExtensionInstallation = Undefined Then
		
		FirstCallInSession = True;
		SuggestFileSystemExtensionInstallation = CommonUse.CommonSettingsStorageLoad(
			"ProgramSettings/SuggestFileSystemExtensionInstallation", ClientID);
		If SuggestFileSystemExtensionInstallation = Undefined Then
			SuggestFileSystemExtensionInstallation = True;
			CommonUse.CommonSettingsStorageSave(
				"ProgramSettings/SuggestFileSystemExtensionInstallation", ClientID,
				SuggestFileSystemExtensionInstallation);
		EndIf;
		
	EndIf;
	
	If SuggestFileSystemExtensionInstallation = False Then
		Return ?(ExtensionAttached, "Attached", "NotAttached");
	EndIf;
	
	If FirstCallInSession Then
		FormParameters = New Structure("Message", SuggestionText);
		ReturnCode = OpenFormModal("CommonForm.FileSystemExtensionInstallationQuestion", FormParameters);
		If ReturnCode = Undefined Then
			ReturnCode = True;
		EndIf;
		
		SuggestFileSystemExtensionInstallation = ReturnCode;
		CommonUse.CommonSettingsStorageSave(
			"ProgramSettings/SuggestFileSystemExtensionInstallation", ClientID,
			SuggestFileSystemExtensionInstallation);
	EndIf;
	Return ?(AttachFileSystemExtension(), "Attached", "NotAttached");
	
#Else
	Return "Attached";
#EndIf
	
EndFunction

// Suggests user to attach the file system extension at the web client
// and, in case of refuse, notifies about impossibility of action continuation.
//
// The function is to be used in the beginning of script parts that worked with files
// only if file system extension is attached.
// Example:
//
// If Not FileSystemExtensionAttached("Document printing requires the file system extension to be attached.") Then
// Return;
// EndIf; 
// // document printing script
// //...
//
// Parameters
// SuggestionText - String - text that suggests to attach the file system extension. 
// If the text is not specified the default text is desplayed.
// WarningText - String - warning text that notifies about impossibility of action continuation. 
// If the text is not specified the default text is desplayed.
//
// Returns:
// Boolean - True if extension is attached.
//
Function FileSystemExtensionAttached(SuggestionText = Undefined, WarningText = Undefined) Export
	
	Result = SuggestFileSystemExtensionInstallationNow(SuggestionText);
	MessageText = "";
	If Result = "NotAttached" Then
		If WarningText <> Undefined Then
			MessageText = WarningText;
		Else
			MessageText = NStr("en = 'The action is not accessible because the file system extension is not attached at the Web client.'")
		EndIf;
	ElsIf Result = "UnsupportedWebClient" Then
		MessageText = NStr("en = 'The action is not accessible in the current Web client because the file system extension cannot be attached to it.'");
	EndIf;
	If Not IsBlankString(MessageText) Then
		DoMessageBox(MessageText);
	EndIf;
	Return Result = "Attached";
	
EndFunction

// Registers the "comcntr.dll" component for the current platform version.
// If registration is successful the procedure suggests user to restart the client session 
// in order to registration takes effect.
//
// The function is to be used before a client script that uses the COM connection manager (V82.COMConnector)
// and is initiated by interactive user actions. Example:
// 
// RegisterCOMConnector();
// // script that uses COM connection manager (V82.COMConnector)
// // ...
Procedure RegisterCOMConnector() Export
	#If Not WebClient Then
	CommandText = "";
	Try
		BatFileName		= GetTempFileName("bat");
		LogFileName	= GetTempFileName("log");
		BatFile = New TextWriter(BatFileName);
		CommandText = "echo off
				|""regsvr32.exe"" /n /i:user /s ""%1comcntr.dll""
				| echo %2 >>""%3""";
		CommandText = StringFunctionsClientServer.SubstituteParametersInString(CommandText,BinDir(),"%errorlevel%",LogFileName);
		BatFile.WriteLine(CommandText);
		BatFile.Close();
	 Shell = New COMObject("WScript.Shell");
		Shell.Run(BatFileName, 0, True); // launching a bat file with hidden window (0) and completion waiting (True)
	Except
		ErrorInfo = ErrorInfo();
		MessageText = NStr("en = 'Error registering the comcntr component.'") + Chars.LF;
		AddMessageForEventLog(NStr("en = 'Comcntr component registration'"), "Error", 
			MessageText + DetailErrorDescription(ErrorInfo));
		CommonUse.WriteEventsToEventLog(MessagesForEventLog);
		DoMessageBox(MessageText + NStr("en = 'See details in the Event log.'"));
		Return;
	EndTry;
	
	Str = "";
	Try
		DeleteFiles(BatFileName);
		LogFile	= New TextReader(LogFileName);
		Str			= LogFile.ReadLine();
		LogFile.Close();
		DeleteFiles(LogFileName);
	Except
		ErrorInfo = ErrorInfo();
		MessageText = NStr("en = 'Error registering the comcntr component.'") + Chars.LF;
		AddMessageForEventLog(NStr("en = 'Comcntr component registration'"), "Error",
			MessageText + DetailErrorDescription(ErrorInfo));
		CommonUse.WriteEventsToEventLog(MessagesForEventLog);
		DoMessageBox(MessageText + NStr("en = 'See details in the Event log.'"));
		Return;
	EndTry;
		
	If TrimAll(Str) <> "0" Then
		MessageText = NStr("en = 'Error registering the comcntr component.'") + Chars.LF;
		AddMessageForEventLog(NStr("en = 'Comcntr component registration'"), "Error",MessageText + 
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Regsvr32 error code is: %1.
				| (Error code 5 means that you have insufficient access rights. Execute the command on behalf of a local administrator.)
			 |
				|Command text: 
				|%2'"), Str, CommandText));
		CommonUse.WriteEventsToEventLog(MessagesForEventLog);
		DoMessageBox(MessageText + NStr("en = '
			|See details in the Event log.'"));
		Return;
	EndIf;
	
	Response = DoQueryBox(NStr("en = 'Restart of the 1C:Enterprise session is required to finish re-registration of the comcntr component .
		|Restart now?'"), QuestionDialogMode.YesNo);
	If Response = DialogReturnCode.Yes Then
		SkipExitConfirmation = True;
		Exit(True, True);
	EndIf;
	#EndIf

EndProcedure

// Is used to choose time in a combo box.
// Parameters:
// Form - Managed form / form - form that contained an item,
// whose time will be chosen
// FormInputField - FormField - owner item of a list. A combo box will be shown 
// by this item
// CurrentValue - Date - combo box will be positioned on this date
// Interval - Number - time interval (in seconds) between values in the list. The default value is an hour 
//
Function ChooseTime(Form, FormInputField, Val CurrentValue, Interval = 3600) Export
	
	WorkingDayBeginning = '00010101000000';
	WorkingDayEnd = '00010101235959';
	
	TimeList = New ValueList;
	WorkingDayBeginning = BegOfHour(BegOfDay(CurrentValue) +
		Hour(WorkingDayBeginning) * 3600 +
		Minute(WorkingDayBeginning)*60);
	WorkingDayEnd = BegOfHour(BegOfDay(CurrentValue) +
		Hour(WorkingDayEnd) * 3600 +
		Minute(WorkingDayEnd)*60);
	
	ListTime = WorkingDayBeginning;
	
	While BegOfHour(ListTime) <= BegOfHour(WorkingDayEnd) Do
		
		If Not ValueIsFilled(ListTime) Then
			TimePresentation = "00:00";
		Else
			TimePresentation = Format(ListTime,"DF=HH:mm");
		EndIf;
		
		TimeList.Add(ListTime, TimePresentation);
		
		ListTime = ListTime + Interval;
		
	EndDo;
	
	InitialValue = TimeList.FindByValue(CurrentValue);
	
	If InitialValue = Undefined Then
		SelectedTime = Form.ChooseFromList(TimeList, FormInputField);
	Else
		SelectedTime = Form.ChooseFromList(TimeList, FormInputField, InitialValue);
	EndIf;
	
	If SelectedTime = Undefined Then
		Return Undefined;
	EndIf;
	
	Return SelectedTime.Value;
	
EndFunction

// Returns True if a client application is connected to InfoBase via a web server.
//
Function ClientConnectedViaWebServer() Export
	
	Return Find(Upper(InfoBaseConnectionString()), "WS=") = 1;
	
EndFunction

// Asks about continuation of actions that lead to loss of changes.
//
// Parameters:
// Cancel - Boolean - returned parameter. It indicates refusal of action continuation;
// Modified - Boolean - form modify flag. It indicates if form from which this procedure is called, is modified;
// ActionSelected - Boolean - this flag shows if a user selected an action that leads to the form closing;
// WarningText - String - dialog text with a user.
//
Procedure RequestCloseFormConfirmation(Cancel, Modified = True, ActionSelected = False, WarningText = "") Export
	
	If ActionSelected = True or Not Modified Then 
		Return;
	EndIf;
	
	QuestionText = ?(IsBlankString(WarningText), 
		NStr("en = 'Data has been changed, all changes will be canceled.
		 |Cancel changes and close the form?'"),
		WarningText);
	Result = DoQueryBox(QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, 
		NStr("en = 'Discard changes'"));
		
	Cancel = (Result = DialogReturnCode.No);	
	
EndProcedure

// Gets a style color by the style item name
//
// Parameters:
//	StyleColorName - string that contains the item name
//
// Returns - style color
Function StyleColor(StyleColorName) Export
	
	Return CommonUseCached.StyleColor(StyleColorName);
	
EndFunction

// Gets a style font by the style item name
//
// Parameters:
//	StyleFontName - string that contains the item name
//
// Returns - style font
Function StyleFont(StyleFontName) Export
	
	Return CommonUseCached.StyleFont(StyleFontName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for working with the Event log

// Writes a message into the global message array.
//
// Parameters: 
// EventName - string - event name for the event log;
// LevelPresentation - string - event level details. Event level will be defined by it on writing at the server;
// MetadataObject - MetadataObject - see "WriteLogEvent" is the syntax assistant for details;
// Data - any type- Data that is related with an event (like object reference for example);
// Comment - String - comment for the event log;
// ModePresentation - String - transaction mode presentation for this event;
// EventDate - Date - accurate date of the event that is described in the message. This date will be added to the begining of comment;
// WriteEvents - Boolean - this flag indicates if the procedure of accumulated message direct writing should be called after this message adding.
//
Procedure AddMessageForEventLog(EventName, LevelPresentation = "Information", 
	Comment = "", EventDate = "", WriteEvents = False) Export
	
	// In case of need, the global message list for the event log must be initialized.
	If MessagesForEventLog = Undefined Then
		MessagesForEventLog = New ValueList;
	EndIf;
	
	MessageStructure = New Structure("EventName, LevelPresentation, Comment, EventDate", 
		EventName, LevelPresentation, Comment, EventDate);
		
	MessagesForEventLog.Add(MessageStructure);
	
	If WriteEvents Then
		CommonUse.WriteEventsToEventLog(MessagesForEventLog);
	EndIf;
		
EndProcedure

// Checks the current variant of event log using.
// If change registration is disabled it suggests to enable it.
//
// Parameters: 
// CheckList - ValueList - list of event log mode string presentations whose registration must be enabled;
// AskForRegistration - Boolean - flag that shows if a question about event log registration enabling will be asked.
// MustEnableEvenLogMessage - String - this message will be displayed to a user if check established that the event log registrstion must be enabled;
//
Procedure EventLogEnabled(CheckList = Undefined, 
	AskForRegistration = True, MustEnableEvenLogMessage = "") Export
	
	// Registration of this event type is already enabled
	If CommonUse.EventLogEnabled(CheckList) Then
		Return;
	EndIf;
	
	If AskForRegistration Then 
		
		If Not IsBlankString(MustEnableEvenLogMessage) Then // If any message was passed then it should be displayed to user
			QuestionText = MustEnableEvenLogMessage;
		Else	
			
			If CheckList = Undefined Then
				QuestionText = NStr("en = 'It is recommended that you turn on the event log writing. 
					|Otherwise, events will not be recorded in the Event log. 
					|Turn it on now?'");
			Else
				QuestionText = NStr("en = 'It is recommended that you turn on event log writing for the following event types: %1. 
					|Otherwise, information in the Event log will not be full. 
					|Turn it on now?'");
				QuestionText = StringFunctionsClientServer.SubstituteParametersInString(QuestionText, CheckList);
			EndIf;
		EndIf;
	
		Mode = QuestionDialogMode.YesNo;
		Default = DialogReturnCode.Yes;
		Title = NStr("en = 'Event log'");
		ReturnCode = DoQueryBox(QuestionText, Mode, , Default, Title);
	Else
		ReturnCode = DialogReturnCode.Yes;
	EndIf;
	
	
	If ReturnCode = DialogReturnCode.Yes Then
		Try 
			CommonUse.EnableUseEventLog(CheckList);
			Text = NStr("en = 'Settings are changed'");
			Comment = NStr("en = 'List of registered in the Event log events is changed'");
			ShowUserNotification(Text,,Comment);
		Except

			EventName = NStr("en = 'Event log setup'");
			LevelPresentation = "Error";
			Comment = NStr("en = Failed to set exclusive access. Event log settings are not changed'");
			AddMessageForEventLog(EventName, LevelPresentation, Comment,, True);
			
			OpenForm("CommonForm.EnableEventLog",New Structure("CheckList",CheckList)); 
			
		EndTry;

	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for processing user actions at editing of multiline text,
// like comments in documents.

// Opens the editing form of any multiline text in modal mode.
//
// Parameters:
// MultilineText - String - any text to be edited;
// EditResult - String - edited result will be put in this parameter;
// Modified - String - form modified flag;
// Title - String - form title text.
//
Procedure OpenMultilineTextEditForm(Val MultilineText, EditResult, Modified = False, 
		Val Title = Undefined) Export
	
	If Title = Undefined Then
		TextEntered = InputString(MultilineText,,, True);
	Else
		TextEntered = InputString(MultilineText, Title,, True);
	EndIf;
	
	If Not TextEntered Then
		Return;
	EndIf;
		
	EditResult = MultilineText;
	If Not Modified Then
		Modified = True;
	EndIf;
	
EndProcedure

// Opens the editing form of any multiline comment in modal mode.
//
// Parameters:
// MultilineText - string - any text to be edited;
// EditResult - String - edited result will be put in this parameter;
// Modified - String - form modified flag;
//
// Example:
// OpenCommentEditForm(Item.EditText, Object.Comment, Modified);
//
Procedure OpenCommentEditForm(Val MultilineText, EditResult,
	Modified = False) Export
	
	OpenMultilineTextEditForm(MultilineText, EditResult, Modified, 
		NStr("en='Comment'"));
	
EndProcedure