////////////////////////////////////////////////////////////////////////////////
// Calendar schedules SaaS subsystem.
//  
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.SuppliedData\OnDefineSuppliedDataHandlers"].Add(
				"CalendarSchedulesInternalSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations.JobQueue\OnDefineHandlerAliases"].Add(
				"CalendarSchedulesInternalSaaS");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SUPPLIED DATA GETTING HANDLERS

// Registers supplied data handlers, both daily and total.
//
Procedure RegisterSuppliedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "BusinessCalendars";
	Handler.HandlerCode = "BusinessCalendarsData";
	Handler.Handler = CalendarSchedulesInternalSaaS;
	
EndProcedure

// The procedure is called when a new data notification is received.
// In the procedure body check whether the application requires this data.
// If it does, set the Import flag.
// Parameters:
//   Descriptor - XDTODataObject - descriptor.
//   Import     - Boolean - return value.
//
Procedure NewDataAvailable(Val Descriptor, Import) Export
	
 	If Descriptor.DataType = "BusinessCalendars" Then
		Import = True;
	EndIf;
	
EndProcedure

// The procedure is called after calling NewDataAvailable, it parses the data.
//
// Parameters:
//   Descriptor   - XDTODataObject - descriptor.
//   PathToFile   - String - Extracted file full name. The file is automatically 
//                  deleted once the procedure is executed.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(PathToFile);
	XMLReader.MoveToContent();
	If Not StartElement(XMLReader, "CalendarSuppliedData") Then
		Return;
	EndIf;
	XMLReader.Read();
	If Not StartElement(XMLReader, "Calendars") Then
		Return;
	EndIf;
	
	// Updating the list of business calendars
	CalendarTable = CommonUse.ReadXMLToTable(XMLReader).Data;
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(CalendarTable);
	
	XMLReader.Read();
	If Not EndElement(XMLReader, "Calendars") Then
		Return;
	EndIf;
	XMLReader.Read();
	If Not StartElement(XMLReader, "CalendarData") Then
		Return;
	EndIf;
	
	// Updates the BusinessCalendars catalog from the template.
	DataTable = Catalogs.BusinessCalendars.BusinessCalendarsDataFromXML(XMLReader);
	
	Catalogs.BusinessCalendars.UpdateBusinessCalendarsData(DataTable);
	
EndProcedure

// The procedure is called if data processing is canceled due to an error.
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
	
	SuppliedData.AreaProcessed(Descriptor.FileGUID, "BusinessCalendarsData", Undefined);
	
EndProcedure	

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// SL event handlers.

// Registers supplied data handlers, both daily and total.
//
// When a new shared data notification is received, NewDataAvailable procedures 
// from modules registered with GetSuppliedDataHandlers are called.
// The descriptor passed to the procedure is XDTODataObject Descriptor.
// 
// If NewDataAvailable sets Import to True, the data is imported, and 
// the descriptor and the path to the data file are passed to ProcessNewData() procedure. 
// The file is automatically deleted once the procedure is executed.
// If the file is not specified in Service Manager, the parameter value is Undefined.
//
// Parameters: 
//   Handlers - ValueTable - table for adding handlers. 
//       Columns:
//        DataKind    - String - code of the data kind processed by the handler. 
//        HandlerCode - String(20) -  used for recovery after a data processing error.
//        Handler, CommonModule - module that contains the following procedures:
//          NewDataAvailable(Descriptor, Import) Export
//          ProcessNewData(Descriptor, Import) Export
//          DataProcessingCanceled(Descriptor) Export
//
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	RegisterSuppliedDataHandlers(Handlers);
	
EndProcedure

// Fills a map of method names and their aliases for calling from a job queue.
//
// Parameters:
//  NameAndAliasMap - Map:
//   Key   - method alias, example: ClearDataArea.
//   Value - method name, example: SaaSOperations.ClearDataArea. You can pass Undefined if the
//           name is identical to the alias.
//    
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("CalendarSchedulesInternalSaaS.UpdateWorkSchedules");
	
EndProcedure

// The procedure is called when a business calendar is changed.
//
Procedure ScheduleWorkScheduleUpdate(Val UpdateConditions) Export
	
	MethodParameters = New Array;
	MethodParameters.Add(UpdateConditions);
	MethodParameters.Add(New UUID);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName",            "CalendarSchedulesInternalSaaS.UpdateWorkSchedules");
	JobParameters.Insert("Parameters",            MethodParameters);
	JobParameters.Insert("RestartCountOnFailure", 3);
	JobParameters.Insert("DataArea",              -1);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

// The procedure is called from a job queue. 
// It is placed to the queue by the ScheduleWorkScheduleUpdate method.
// 
// Parameters:
//  UpdateConditions - ValueTable with schedule update conditions. 
//  UpdateID         - UUID.
//
Procedure UpdateWorkSchedules(Val UpdateConditions, Val UpdateID) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		
		// Getting data areas to process
		AreasForUpdate = SuppliedData.AreasRequireProcessing(
			UpdateID, "BusinessCalendarsData");
			
		// Updating work schedules by data areas
		DistributeBusinessCalendarsDataOnWorkSchedules(UpdateConditions, AreasForUpdate, 
			UpdateID, "BusinessCalendarsData", WorkSchedulesModule);
			
	EndIf;

EndProcedure

// Fills work schedules according to business calendar data in all data areas.
//
// Parameters
//  UpdateConditions    - ValueTable with work schedule update conditions.
//  AreasForUpdate      - Array of area codes.
//  FileID              - UUID of the file with the calendar to be processed. 
//  HandlerCode         - String - handler code.
//  WorkSchedulesModule - CommonModule.
//
Procedure DistributeBusinessCalendarsDataOnWorkSchedules(Val UpdateConditions, 
	Val AreasForUpdate, Val FileID, Val HandlerCode, Val WorkSchedulesModule)
	
	UpdateConditions.Collapse("BusinessCalendarCode, Year");
	
	For Each DataArea In AreasForUpdate Do
	
		SetPrivilegedMode(True);
		CommonUse.SetSessionSeparation(True, DataArea);
		SetPrivilegedMode(False);
		
		BeginTransaction();
		WorkSchedulesModule.UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions);
		SuppliedData.AreaProcessed(FileID, HandlerCode, DataArea);
		CommitTransaction();
		
	EndDo;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Other internal procedures and functions.

Function StartElement(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Or XMLReader.Name <> Name Then
		WriteLogEvent(NStr("en = 'Supplied data.Calendar schedules.'", 
			Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error,
			,, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid data file format. Beginning of %1 element expected.'"), Name));
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function EndElement(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.EndElement Or XMLReader.Name <> Name Then
		WriteLogEvent(NStr("en = 'Supplied data.Calendar schedules.'", 
			Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error,
			,, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Invalid data file format. End of %1 element expected.'"), Name));
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion
