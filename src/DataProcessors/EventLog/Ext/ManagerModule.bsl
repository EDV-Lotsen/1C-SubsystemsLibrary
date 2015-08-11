////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns the enum value corresponding to the event status string name.
//
// Parameters:
//	Name - String - Entry transaction status.
//
// Returns:
//	EventLogEntryTransactionStatus - Transaction status value.
//
Function EventLogEntryTransactionStatusValueByName(Name) Export
	
	EnumValue = Undefined;
	If Name = "Committed" Then
		EnumValue = EventLogEntryTransactionStatus.Committed;
	ElsIf Name = "Unfinished" Then
		EnumValue = EventLogEntryTransactionStatus.Unfinished;
	ElsIf Name = "NotApplicable" Then
		EnumValue = EventLogEntryTransactionStatus.NotApplicable;
	ElsIf Name = "RolledBack" Then
		EnumValue = EventLogEntryTransactionStatus.RolledBack;
	EndIf;
	Return EnumValue;
	
EndFunction

// Returns the enum value corresponding to the event log string level.
//
// Parameters:
//	Name - String - event log level.
//
// Returns:
//	EventLogLevel - event log level value.
//
Function EventLogLevelValueByName(Name) Export
	
	EnumValue = Undefined;
	If Name = "Information" Then
		EnumValue = EventLogLevel.Information;
	ElsIf Name = "Error" Then
		EnumValue = EventLogLevel.Error;
	ElsIf Name = "Warning" Then
		EnumValue = EventLogLevel.Warning;
	ElsIf Name = "Note" Then
		EnumValue = EventLogLevel.Note;
	EndIf;
	Return EnumValue;
	
EndFunction

// Sets the picture number in the log event row
//
// Parameters:
//	LogEvent - value table row - event log string.
//
Procedure SetPictureNumber(LogEvent) Export
	
	// Setting relative image number
	If LogEvent.Level = EventLogLevel.Information Then
		LogEvent.PictureNumber = 0;
	ElsIf LogEvent.Level = EventLogLevel.Warning Then
		LogEvent.PictureNumber = 1;
	ElsIf LogEvent.Level = EventLogLevel.Error Then
		LogEvent.PictureNumber = 2;
	Else
		LogEvent.PictureNumber = 3;
	EndIf;
	
	// Setting absolute image number
	If LogEvent.TransactionStatus = EventLogEntryTransactionStatus.Unfinished
	 or LogEvent.TransactionStatus = EventLogEntryTransactionStatus.RolledBack Then
		LogEvent.PictureNumber = LogEvent.PictureNumber + 4;
	EndIf;
	
EndProcedure