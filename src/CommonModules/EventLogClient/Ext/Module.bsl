////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem
// Internal procedures and functions for working with the event log.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// SERVICE INTERFACE

// Opens the form for viewing additional event data.
//
// Parameters:
//	CurrentData - Value table row - event log row.
//
Procedure OpenDataForViewing(CurrentData) Export
	
	If CurrentData = Undefined or CurrentData.Data = Undefined Then
		ShowMessageBox(, NStr("en = 'This event log item is not linked to data (see Data column)'"));
		Return;
	EndIf;
	
	Try
		ShowValue(, CurrentData.Data);
	Except
		WarningText = NStr("en = 'This event log item is linked to data, but there is no way to display them.
									|%1'");
		If CurrentData.Event = "_$Data$_.Delete" Then 
			// This is a delete event 
			WarningText =
					StringFunctionsClientServer.SubstituteParametersInString(
						WarningText,
						NStr("en = 'Data was removed from the Infobase'"));
		Else
			WarningText =
				StringFunctionsClientServer.SubstituteParametersInString(
						WarningText,
						NStr("en = 'Perhaps, data was removed from the Infobase'"));
		EndIf;
		ShowMessageBox(, WarningText);
	EndTry;
	
EndProcedure // OpenDataForViewing

// Opens the event view form of the Event log data processor
// to display selected event detailed data. 
//
// Parameters:
//	Data - Value table row - event log row.
//
Procedure ViewCurrentEventInSeparateWindow(Data) Export
	
	If Data = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Date", Data.Date);
	FormParameters.Insert("UserName", Data.UserName);
	FormParameters.Insert("ApplicationPresentation", Data.ApplicationPresentation);
	FormParameters.Insert("Computer", Data.Computer);
	FormParameters.Insert("Event", Data.Event);
	FormParameters.Insert("EventPresentation", Data.EventPresentation);
	FormParameters.Insert("Comment", Data.Comment);
	FormParameters.Insert("MetadataPresentation", Data.MetadataPresentation);
	FormParameters.Insert("Data", Data.Data);
	FormParameters.Insert("DataPresentation", Data.DataPresentation);
	FormParameters.Insert("TransactionID", Data.TransactionID);
	FormParameters.Insert("TransactionStatus", Data.TransactionStatus);
	FormParameters.Insert("Session", Data.Session);
	FormParameters.Insert("ServerName", Data.ServerName);
	FormParameters.Insert("Port", Data.Port);
	FormParameters.Insert("SyncPort", Data.SyncPort);
	
	If ValueIsFilled(Data.DataAddress) Then
		FormParameters.Insert("DataAddress", Data.DataAddress);
	EndIf;
	
	OpenForm("DataProcessor.EventLog.Form.EventForm", FormParameters);
	
EndProcedure // ViewCurrentEventInSeparateWindow

// Requests a period restriction from a user 
// and includes it in the event log filter
//
// Parameters:
//	DateInterval - StandardPeriod - filter date interval;
//	EventLogFilter - Structure - event log filter
//
Procedure SetViewDateInterval(DateInterval, EventLogFilter) Export
	
	IntervalSet = False;
		
	// Getting current period
	StartDate = Undefined;
	EndDate = Undefined;
	EventLogFilter.Property("StartDate", StartDate);
	EventLogFilter.Property("EndDate", EndDate);
	StartDate = ?(TypeOf(StartDate) = Type("Date"), StartDate, '00010101000000');
	EndDate = ?(TypeOf(EndDate) = Type("Date"), EndDate, '00010101000000');
	
	If DateInterval.StartDate <> StartDate Then
		DateInterval.StartDate = StartDate;
	EndIf;
	
	If DateInterval.EndDate <> EndDate Then
		DateInterval.EndDate = EndDate;
	EndIf;
	
	// Editing current period
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = DateInterval;
	
	FunctionParameters = New Structure;
	FunctionParameters.Insert("EventLogFilter", EventLogFilter);
	Dialog.Show(New NotifyDescription("SetViewDateIntervalAfterEdit", ThisObject, FunctionParameters));
	
EndProcedure 

// The continuation of SetViewDateInterval
Procedure SetViewDateIntervalAfterEdit(Period, AdditionalParameters) Export
	
	// Refreshing current period
	DateInterval = Period;
	If DateInterval.StartDate = '00010101000000' Then
		AdditionalParameters.EventLogFilter.Delete("StartDate");
	Else
		AdditionalParameters.EventLogFilter.Insert("StartDate", DateInterval.StartDate);
	EndIf;
	If DateInterval.EndDate = '00010101000000' Then
		AdditionalParameters.EventLogFilter.Delete("EndDate");
	Else
		AdditionalParameters.EventLogFilter.Insert("EndDate", DateInterval.EndDate);
	EndIf;
	
EndProcedure 

// Performs separate event choise processing in the event table
//
// Parameters:
//	CurrentData - Value table row - event log row;
//	Field - Value table field - Field;
//	DateInterval - Interval;
//	EventLogFilter - Filter - event log filter.
//
Procedure EventsChoice(CurrentData, Field, DateInterval, EventLogFilter) Export
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Field.Name = "Data" or Field.Name = "DataPresentation" Then
		If CurrentData.Data <> Undefined And (TypeOf(CurrentData.Data) <> Type("String") And ValueIsFilled(CurrentData.Data)) Then
			OpenDataForViewing(CurrentData);
			Return;
		EndIf;
	EndIf;
	
	If Field.Name = "Date" Then
		SetViewDateInterval(DateInterval, EventLogFilter);
		Return;
	EndIf;
	
	ViewCurrentEventInSeparateWindow(CurrentData);
	
EndProcedure // EventsChoice

// Fills the filter according to the value in the current events column.
//
// Parameters:
//	CurrentData - Value table row;
//	CurrentControl - Current value table row item;
//	EventLogFilter - Filter - event log filter;
//	ExcludeColumns - List Values - Exclude columns .
//
// Returns:
//	Boolean - True if filter is applied, False in other case.
//
Function SetFilterByValueInCurrentColumn(CurrentData, CurrentControl, EventLogFilter, ExcludeColumns) Export
	
	If CurrentData = Undefined Then
		Return False;
	EndIf;
	PresentationColumnName = CurrentControl.Name;
	If ExcludeColumns.Find(PresentationColumnName) <> Undefined Then
		Return False;
	EndIf;
	SelectValue = CurrentData[PresentationColumnName];
	Presentation = CurrentData[PresentationColumnName];
	
	FilterItemName = PresentationColumnName;
	If PresentationColumnName = "UserName" Then 
		FilterItemName = "User";
		SelectValue = CurrentData["User"];
	ElsIf PresentationColumnName = "ApplicationPresentation" Then
		FilterItemName = "ApplicationName";
		SelectValue = CurrentData["ApplicationName"];
	ElsIf PresentationColumnName = "EventPresentation" Then
		FilterItemName = "Event";
		SelectValue = CurrentData["Event"];
	EndIf;
	
	// Filtering by a blanked string is not allowed
	If TypeOf(SelectValue) = Type("String") And IsBlankString(SelectValue) Then
		// Default user has a blank name, it is allowed to filter by this user.
		If PresentationColumnName <> "UserName" Then 
			Return False;
		EndIf;
	EndIf;
	
	CurrentValue = Undefined;
	If EventLogFilter.Property(FilterItemName, CurrentValue) Then
		// Filter is already applied
		EventLogFilter.Delete(FilterItemName);
	Else
		If FilterItemName = "Data" or // Filter type is not a list but a single value.
			 FilterItemName = "Comment" or
			 FilterItemName = "TransactionID" or
			 FilterItemName = "DataPresentation" Then 
			EventLogFilter.Insert(FilterItemName, SelectValue);
		Else
			FilterList = New ValueList;
			FilterList.Add(SelectValue, Presentation);
			EventLogFilter.Insert(FilterItemName, FilterList);
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction // SetFilterByValueInCurrentColumn

