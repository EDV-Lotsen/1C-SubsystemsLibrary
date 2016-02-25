////////////////////////////////////////////////////////////////////////////////
//  Methods that start and end the measurement of key operation execution time.
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Starts the measurement of key operation execution time.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations - key operation 
// 					        or String - key operation name. 
//  When the function is called from the server, this parameter is ignored. 
//
// Returns:
//  Date or Number - start time with an accuracy of 1 millisecond or 1 second, 
//  depending on the platform version.
Function BeginTimeMeasurement(KeyOperation = Undefined) Export
	
	StartTime = 0;
	If PerformanceMonitorServerCallCached.EnablePerformanceMeasurements() Then
		StartDate = TimerValue(False);
		StartTime = TimerValue();
		#If Client Then
			If Not ValueIsFilled(KeyOperation) Then
				Raise NStr("en = 'The key operation is not specified.'");
			EndIf;
			If PerformanceMonitorTimeMeasurement = Undefined Then
				PerformanceMonitorTimeMeasurement = New Structure;
				PerformanceMonitorTimeMeasurement.Insert("Measurements", New Map);
				
				CurrentRecordPeriod = PerformanceMonitorServerCallFullAccess.RecordPeriod();
				PerformanceMonitorTimeMeasurement.Insert("RecordPeriod", CurrentRecordPeriod);
				
				DateAndTimeAtServer = PerformanceMonitorServerCallFullAccess.DateAndTimeAtServer();
				DateAndTimeAtClient = CurrentDate();
				PerformanceMonitorTimeMeasurement.Insert(
					"ClientDateOffset", 
					DateAndTimeAtServer - DateAndTimeAtClient);
				
				AttachIdleHandler("WriteResultsAuto", CurrentRecordPeriod, True);
			EndIf;
			Measurements = PerformanceMonitorTimeMeasurement["Measurements"]; 
			
			KeyOperationBuffer = Measurements.Get(KeyOperation);
			If KeyOperationBuffer = Undefined Then
				KeyOperationBuffer = New Map;
				Measurements.Insert(KeyOperation, KeyOperationBuffer);
			EndIf;
			
			ClientDateOffset = PerformanceMonitorTimeMeasurement["ClientDateOffset"];
			StartDate = StartDate + ClientDateOffset;
			StartedMeasurement = KeyOperationBuffer.Get(StartDate);
			If StartedMeasurement = Undefined Then
				MeasurementBuffer = New Map;
				MeasurementBuffer.Insert("StartTime", StartTime);
				KeyOperationBuffer.Insert(StartDate, MeasurementBuffer);
			EndIf;
			
			AttachIdleHandler("EndTimeMeasurementAuto", 0.1, True);
		#EndIf
	EndIf;

	Return StartTime;
	
EndFunction

// Ends the measurement of key operation execution time on the server 
// and writes the result on the server.
//  Parameters:
//   KeyOperation - CatalogRef.KeyOperations - key operation 
// 					         or String - key operation name.
//   StartTime    - Number or Date.
Procedure EndTimeMeasurement(KeyOperation, StartTime) Export
	
	EndDate = TimerValue(False);
	EndTime = TimerValue();
	If TypeOf(StartTime) = Type("Number") Then
		Duration = (EndTime - StartTime);
		StartDate = EndDate - Duration;
	Else
		Duration = (EndDate - StartTime);
		StartDate = StartTime;
	EndIf;
	PerformanceMonitorServerCallFullAccess.CommitKeyOperationsDuration(
		KeyOperation,
		Duration,
		StartDate,
		EndDate);
	
EndProcedure

// The function is called at the start and end of the execution time measurement.
// Usage of CurrentDate instead of CurrentSessionDate is intentional.
// Note that if the start time is retrieved on the client, the end time must be calculated on the client too. 
// The same is true for the server.
// Returns:
//  Date - start date of the measurement.
Function TimerValue(HighAccuracy = True) Export
	
	Var TimerValue;
	If HighAccuracy Then
		
		TimerValue = CurrentUniversalDateInMilliseconds() / 1000.0;
		Return TimerValue;
		
	Else
		
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Return CurrentSessionDate();
#Else
		Return CurrentDate();
#EndIf
		
	EndIf;
	
EndFunction

// Returns scheduled job parameter key that corresponds to the local export directory.

Function LocalExportDirectoryJobKey() Export
	
	Return "LocalExportDirectory";
	
EndFunction

// Returns scheduled job parameter key that corresponds to the export FTP directory.
Function FTPExportDirectoryJobKey() Export
	
	Return "FTPExportDirectory";
	
EndFunction

#If Server Then
// Writes data to the event log.
//
// Parameters:
//  EventName - String.
//  Level - EventLogLevel.
//  MessageText - String.
//
Procedure WriteToEventLog(EventName, Level, MessageText) Export
	
	WriteLogEvent(EventName,
		Level,
		,
		NStr("en = 'Performance monitor'"),
		MessageText);
	
EndProcedure
#EndIf

// Gets the name of the additional property that shows whether priority check is skipped
// when writing key operations.
// Returns:
//  String - additional property name.
//
Function DontCheckPriority() Export
	
	Return "DontCheckPriority";
	
EndFunction

#EndRegion
