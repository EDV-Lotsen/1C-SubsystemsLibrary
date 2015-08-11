////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Internal procedures and functions for working with the event log.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// SERVICE INTERFACE

// Reads event log message texts taking into account filfer settings 
//
// Parameters:
// ReportParameters - structure. It contains parameters for reading event log message texts;
//	StorageAddress - temporary storage address where the result is placed;
//
//	Log	- ValueTable that contains event log records;
//	EventLogFilterAtClient - structure that contains filter settings for reading event log message texts;
//	EventCount - Number that limits the number of event log message texts to be read;
//	UUID - UUID - unique form ID;
//	OwnerManager - object manager. Event log is displayed on this object form. 
//						The manager is used to call appearance functions back.
// 	AddAdditionalColumns - Boolean. Determines if there is need of a callback for additional columns adding.
//
Procedure ReadEventLogEvents(ReportParameters, StorageAddress) Export
	
	Log = ReportParameters.Log;
	EventLogFilterAtClient = ReportParameters.EventLogFilter;
	EventCount = ReportParameters.EventCountLimit;
	UUID = ReportParameters.UUID;
	OwnerManager = ReportParameters.OwnerManager;
	AddAdditionalColumns = ReportParameters.AddAdditionalColumns;
	
	// Deleting previously prepared temporary data
	AddressDetails = Log.UnloadColumn("DataAddress");
	For Each Address In AddressDetails Do
		If ValueIsFilled(Address) Then
			DeleteFromTempStorage(Address);
		EndIf;
	EndDo;
	
	// Filter preparation
	Filter = New Structure;
	For Each FilterItem In EventLogFilterAtClient Do
		Filter.Insert(FilterItem.Key, FilterItem.Value);
	EndDo;
	FilterConversion(Filter);
	
	// Unloading selected events
	LogEvents = New ValueTable;
	UnloadEventLog(LogEvents, Filter, , , EventCount);
	LogEvents.Columns.Add("PictureNumber", New TypeDescription("Number"));
	LogEvents.Columns.Add("DataAddress", New TypeDescription("String"));
	
	PictureRules = Undefined;
	
	If AddAdditionalColumns Then
		// Adding columns
		OwnerManager.AddAdditionalEventColumns(LogEvents);
	EndIf;
	
	For Each LogEvent In LogEvents Do
		
		// Filling numbers of row pictures
		OwnerManager.SetPictureNumber(LogEvent);
		
		If AddAdditionalColumns Then
			// Filling additional fields that are defined for the owner only
			OwnerManager.FillAdditionalEventColumns(LogEvent);
		EndIf;
		
		// Conversing the metadata arrey into a value list
		MetadataPresentationList = New ValueList;
		If TypeOf(LogEvent.MetadataPresentation) = Type("Array") Then
			MetadataPresentationList.LoadValues(LogEvent.MetadataPresentation);
		Else
			MetadataPresentationList.Add(String(LogEvent.MetadataPresentation));
		EndIf;
		LogEvent.MetadataPresentation = MetadataPresentationList;
		
		// Processing special event data
		If LogEvent.Event = "_$Access$_.Access" Then
			LogEvent.DataAddress = PutToTempStorage(LogEvent.Data, UUID);
			If LogEvent.Data <> Undefined Then
				LogEvent.Data = ?(LogEvent.Data.Data = Undefined, "", "...");
			EndIf;
			
		ElsIf LogEvent.Event = "_$Access$_.AccessDenied" Then
			LogEvent.DataAddress = PutToTempStorage(LogEvent.Data, UUID);
			If LogEvent.Data <> Undefined Then
				If LogEvent.Data.Property("Right") Then
					LogEvent.Data = NStr("en = 'Right: '") + LogEvent.Data.Right;
				Else
					LogEvent.Data = NStr("en = 'Action: '") + LogEvent.Data.Action + 
						?(LogEvent.Data.Data = Undefined, "", ", ...");
				EndIf;
			EndIf;
			
		ElsIf LogEvent.Event = "_$Session$_.Authentication"
		 or LogEvent.Event = "_$Session$_.AuthenticationError" Then
			LogEvent.DataAddress = PutToTempStorage(LogEvent.Data, UUID);
			LogEventData = "";
			If LogEvent.Data <> Undefined Then
				For Each KeyAndValue In LogEvent.Data Do
					If ValueIsFilled(LogEventData) Then
						LogEventData = LogEventData + ", ...";
						Break;
					EndIf;
					LogEventData = KeyAndValue.Key + ": " + KeyAndValue.Value;
				EndDo;
			EndIf;
			LogEvent.Data = LogEventData;
			
		ElsIf LogEvent.Event = "_$User$_.Delete" Then
			LogEvent.DataAddress = PutToTempStorage(LogEvent.Data, UUID);
			LogEventData = "";
			If LogEvent.Data <> Undefined Then
				For Each KeyAndValue In LogEvent.Data Do
					LogEventData = KeyAndValue.Key + ": " + KeyAndValue.Value;
					Break;
				EndDo;
			EndIf;
			LogEvent.Data = LogEventData;
			
		ElsIf LogEvent.Event = "_$User$_.New"
		 or LogEvent.Event = "_$User$_.Update" Then
			LogEvent.DataAddress = PutToTempStorage(LogEvent.Data, UUID);
			IBUserName = "";
			If LogEvent.Data <> Undefined Then
				LogEvent.Data.Property("Name", IBUserName);
			EndIf;
			LogEvent.Data = NStr("en = 'Name: '") + IBUserName + ", ...";
			
		EndIf;
		
		SetPrivilegedMode(True);
		// Processing special user name values
		If LogEvent.User = New UUID("00000000-0000-0000-0000-000000000000") Then
			LogEvent.UserName = NStr("en='<Undefined>'");
			
		ElsIf LogEvent.UserName = "" Then
			LogEvent.UserName = Users.UnspecifiedUserFullName();
			
		ElsIf InfoBaseUsers.FindByUUID(LogEvent.User) = Undefined Then
			LogEvent.UserName = LogEvent.UserName + " " + NStr("en='<Deleted>'");
			
		EndIf;
		// Conversion of the UUID into a name. Further this name will be used in filter settings.
		LogEvent.User = InfoBaseUsers.FindByUUID(LogEvent.User);
		SetPrivilegedMode(False);
	EndDo;
	 	
	PutToTempStorage(New Structure("LogEvents", 
									LogEvents), StorageAddress);
	
EndProcedure // ReadEventLogEvents

// Creates a custom event log presentation 
//
// Parameters:
//	FilterPresentation - String - this string contains a custom filter presentation;
//	EventLogFilter - Structure - this structure contains event log filter values;
//	DefaultEventLogFilter - Structure - this structure contains the default event log filter value;
//										(Default filter value is not included in the custom presentation)
//
Procedure GenerateFilterPresentation(FilterPresentation, EventLogFilter, 
	DefaultEventLogFilter = Undefined) Export

	FilterPresentation = "";
	// Interval
	IntervalStartDate = Undefined;
	IntervalEndDate = Undefined;
	If Not EventLogFilter.Property("StartDate", IntervalStartDate) or
		 IntervalStartDate = Undefined Then 
		IntervalStartDate = '00010101000000';
	EndIf;
	If Not EventLogFilter.Property("EndDate", IntervalEndDate) or
		 IntervalEndDate = Undefined Then 
		IntervalEndDate = '00010101000000';
	EndIf;
	If Not (IntervalStartDate = '00010101000000' And IntervalEndDate = '00010101000000') Then
		FilterPresentation = PeriodPresentation(IntervalStartDate, IntervalEndDate);
	EndIf;
	
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "User");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, 
		"Event", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, 
		"ApplicationName", DefaultEventLogFilter);
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Session");
	AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, "Level");
	
	// All other restrictions are specified by presentations without values
	For Each FilterItem In EventLogFilter Do
		RestrictionName = FilterItem.Key;
		If Upper(RestrictionName) = Upper("StartDate") 
				or Upper(RestrictionName) = Upper("EndDate") 
				or Upper(RestrictionName) = Upper("Event") 
				or Upper(RestrictionName) = Upper("ApplicationName") 
				or Upper(RestrictionName) = Upper("User")
				or Upper(RestrictionName) = Upper("Session")
				or Upper(RestrictionName) = Upper("Level") Then
			Continue; // Interval and special restrictions are already displayed
		EndIf;
		
		// Changing restrictions for some of presentations
		If Upper(RestrictionName) = Upper("ApplicationName") Then
			RestrictionName = NStr("en = 'Application'");
			
		ElsIf Upper(RestrictionName) = Upper("TransactionStatus") Then
			RestrictionName = NStr("en = 'Transaction status'");
			
		ElsIf Upper(RestrictionName) = Upper("DataPresentation") Then
			RestrictionName = NStr("en = 'Data presentation'");
			
		ElsIf Upper(RestrictionName) = Upper("ServerName") Then
			RestrictionName = NStr("en = 'Server name'");
			
		ElsIf Upper(RestrictionName) = Upper("Port") Then
			RestrictionName = NStr("en = 'Port'");
			
		ElsIf Upper(RestrictionName) = Upper("SyncPort") Then
			RestrictionName = NStr("en = 'Sync port'");
			
		EndIf;
		
		If Not IsBlankString(FilterPresentation) Then 
			FilterPresentation = FilterPresentation + "; ";
		EndIf;
		FilterPresentation = FilterPresentation + RestrictionName;
	EndDo;
	
	If IsBlankString(FilterPresentation) Then
		FilterPresentation = NStr("en = 'Not defined'");
	EndIf;
	
EndProcedure // GenerateFilterPresentation

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURE AND FUNCTION

// Filter conversion.
//
// Filter - filter - passed filter.
//
Procedure FilterConversion(Filter)
	
	For Each FilterItem In Filter Do
		If TypeOf(FilterItem.Value) = Type("ValueList") Then
			FilterItemConversion(Filter, FilterItem);
		ElsIf Upper(FilterItem.Key) = Upper("TransactionID") Then
			If Find(FilterItem.Value, "(") = 0 Then
				Filter.Insert(FilterItem.Key, "(" + FilterItem.Value);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Filter item conversion.
//
// Parameters:
//	Filter - filter - passed filter.
//	FilterItem - filter item - passed filter item.
//
Procedure FilterItemConversion(Filter, FilterItem)
	
	// Is called if a filter item is a value list.
	// It transforms the value list into an array because the filter cannot constain a list.
	NewValue = New Array;
	
	For Each ValueFromList In FilterItem.Value Do
		If Upper(FilterItem.Key) = Upper("Level") Then
			// Message text level is a string, it mast be converted into an enum
			NewValue.Add(DataProcessors.EventLog.EventLogLevelValueByName(ValueFromList.Value));
		ElsIf Upper(FilterItem.Key) = Upper("TransactionStatus") Then
			// Transaction status is a string, it mast be converted into an enum
			NewValue.Add(DataProcessors.EventLog.EventLogEntryTransactionStatusValueByName(ValueFromList.Value));
		Else
			NewValue.Add(ValueFromList.Value);
		EndIf;
	EndDo;
	
	Filter.Insert(FilterItem.Key, NewValue);
	
EndProcedure

// Adding a restriction to the filter presentation.
//	
//	Parameters:
//	EventLogFilter - Filter - event log filter;
//	FilterPresentation - String - filter presentation;
//	RestrictionName - String - restriction name;
//	DefaultEventLogFilter - Filter - default event log filter.
// 
Procedure AddRestrictionToFilterPresentation(EventLogFilter, FilterPresentation, RestrictionName,
	DefaultEventLogFilter = Undefined)
	
	RestrictionList = "";
	Restriction = "";
	
	If EventLogFilter.Property(RestrictionName, RestrictionList) Then
		
		// If filter value is a default value there is no need to get a presentation of it
		If DefaultEventLogFilter <> Undefined Then
			DefaultRestrictionList = "";
			If DefaultEventLogFilter.Property(RestrictionName, DefaultRestrictionList) 
				And CommonUseClientServer.ValueListsEqual(DefaultRestrictionList, RestrictionList) Then
				Return;
			EndIf;
		EndIf;
		
		For Each ListItem In RestrictionList Do
			If Not IsBlankString(Restriction) Then
				Restriction = Restriction + ", ";
			EndIf;
			If Upper(RestrictionName) = Upper("Session")
			or Upper(RestrictionName) = Upper("Level")
			And IsBlankString(Restriction) Then
				Restriction = NStr("en = '[RestrictionName]: [Value]'");
				Restriction = StrReplace(Restriction, "[Value]", ListItem.Value);
				Restriction = StrReplace(Restriction, "[RestrictionName]", RestrictionName);
			ElsIf Upper(RestrictionName) = Upper("Session")
			or Upper(RestrictionName) = Upper("Level")Then
				Restriction = Restriction + ListItem.Value;
			Else
				Restriction = Restriction + ListItem.Presentation;
			EndIf;
		EndDo;
	
		If Not IsBlankString(FilterPresentation) Then 
			FilterPresentation = FilterPresentation + "; ";
		EndIf;
	
		FilterPresentation = FilterPresentation + Restriction;
	
	EndIf;
	
EndProcedure //AddRestrictionToFilterPresentation