////////////////////////////////////////////////////////////////////////////////
// Full-text search subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Updates full-text search index.
Procedure FullTextSearchUpdateIndex() Export
	
	UpdateIndex(NStr("en = 'full-text search index update'"), False, True);
	
EndProcedure

// Merges full-text search indexes.
Procedure FullTextSearchMergeIndex() Export
	
	UpdateIndex(NStr("en = 'full-text search index merging.'"), True);
	
EndProcedure

// Returns a flag that shows whether full-text search index is up-to-date.
//   The "UseFullTextSearch" functional option is checked in a caller script.
//
Function SearchIndexTrue() Export
	
	Return (
		// Operations are prohibited,
   // or the index is up-to-date (the infobase in its current state is fully indexed),
		// or the index was updated less than 5 minutes ago.
		Not OperationsAllowed()
		Or FullTextSearch.IndexTrue()
		Or CurrentDate() < FullTextSearch.UpdateDate() + 300); // not CurrentSessionDate()
	
EndFunction

#EndRegion

#Region InternalInterface

////////////////////////////////////////////////////////////////////////////////
// Adding handlers of internal events (subscriptions).

// See the description of the procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers["StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
		"FullTextSearchServer");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers.

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "FullTextSearchServer.InitializeFullTextSearchFunctionalOption";
	Handler.SharedData = True;
	
EndProcedure

// Sets value of UseFullTextSearch constant.
//   This synchronizes UseFullTextSearch functional option value 
//   with FullTextSearch.GetFullTextSearchMode() function value.
//
Procedure InitializeFullTextSearchFunctionalOption() Export
	
	ConstantValue = OperationsAllowed();
	Constants.UseFullTextSearch.Set(ConstantValue);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Scheduled job handler.
Procedure FullTextSearchUpdateIndexOnSchedule() Export
	
	CommonUse.ScheduledJobOnStart();
	
	FullTextSearchUpdateIndex();
	
EndProcedure

// Scheduled job handler.
Procedure FullTextSearchMergeIndexOnSchedule() Export
	
	CommonUse.ScheduledJobOnStart();
	
	FullTextSearchMergeIndex();
	
EndProcedure

// Common procedure for updating and merging full-text search index.
Procedure UpdateIndex(ProcedurePresentation, EnableJoining = False, InPortions = False)
	
	If Not OperationsAllowed() Then
		Return;
	EndIf;
	
	CommonUse.ScheduledJobOnStart();
	
	LogRecord(Undefined, NStr("en = 'Starting %1.'"), , ProcedurePresentation);
	
	Try
		FullTextSearch.UpdateIndex(EnableJoining, InPortions);
		LogRecord(Undefined, NStr("en = 'Completing %1.'"), , ProcedurePresentation);
	Except
		LogRecord(Undefined, NStr("en = 'Error during %1:'"), ErrorInfo(), ProcedurePresentation);
	EndTry;
	
EndProcedure

// Returns the flag that shows whether full-text search operations (index update, index clearing, and search) are allowed.
Function OperationsAllowed() Export
	
	Return FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable;
	
EndFunction

// Creates a record for the event log and for user messages.
//   Support up to 3 parameters in the comment, wich can be substituted
//   with StringFunctionsClientServer.SubstituteParametersInString function. 
//   Supports passing error details to other procedures and functions,  
//   the error details are added to the comment part of the event log record.
//
// Parameters:
//   LogLevel              - EventLogLevel - Message importance for administrator.
//   CommentWithParameters - String - Comment that can include parameters %1, %2, and %3.
//   ErrorInfo             - ErrorInfo, String - error details recorded after the comment.
//   Parameter1            - String - Replaces %1 in CommentWithParameters.
//   Parameter2            - String - Replaces %2 in CommentWithParameters.
//   Parameter3            - String - Replaces %3 in CommentWithParameters.
//
Procedure LogRecord(LogLevel = Undefined, CommentWithParameters = "",
	ErrorInfo = Undefined,
	Parameter1 = Undefined,
	Parameter2 = Undefined,
	Parameter3 = Undefined)
	
	// Determining event log level by type of passed error message.
	If TypeOf(LogLevel) <> Type("EventLogLevel") Then
		If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
			LogLevel = EventLogLevel.Error;
		ElsIf TypeOf(ErrorInfo) = Type("String") Then
			LogLevel = EventLogLevel.Warning;
		Else
			LogLevel = EventLogLevel.Information;
		EndIf;
	EndIf;
	
	// Comment for the event log
	TextForLog = CommentWithParameters;
	If Parameter1 <> Undefined Then
		TextForLog = StringFunctionsClientServer.SubstituteParametersInString(
			TextForLog, Parameter1, Parameter2, Parameter3);
	EndIf;
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		TextForLog = TextForLog + Chars.LF + DetailErrorDescription(ErrorInfo);
	ElsIf TypeOf(ErrorInfo) = Type("String") Then
		TextForLog = TextForLog + Chars.LF + ErrorInfo;
	EndIf;
	TextForLog = TrimAll(TextForLog);
	
	// Recording to the event log 
	WriteLogEvent(
		NStr("en = 'FullTextIndexing'", CommonUseClientServer.DefaultLanguageCode()), 
		LogLevel, , , 
		TextForLog);
	
EndProcedure

#EndRegion
