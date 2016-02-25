////////////////////////////////////////////////////////////////////////////////
// Performance monitor subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Ends the measurement of execution time on the client.
//
Procedure EndTimeMeasurementAutoNotGlobal() Export
	
	EndTimeMeasurement();
	
EndProcedure

// Writes accumulated measurements of key operation execution time on the server.
//
// Parameters:
//  BeforeCompletion - Boolean - True if the method is called before closing the application.
//
Procedure WriteResultsAutoNotGlobal(BeforeCompletion = False) Export
	
	If Not PerformanceMonitorTimeMeasurement = Undefined Then
		
		If PerformanceMonitorTimeMeasurement["Measurements"].Count() = 0 Then
			
			NewRecordPeriod = PerformanceMonitorTimeMeasurement["RecordPeriod"];
		Else
			Measurements = PerformanceMonitorTimeMeasurement["Measurements"];
			NewRecordPeriod = PerformanceMonitorServerCallFullAccess.RegisterKeyOperationDuration (Measurements);
			PerformanceMonitorTimeMeasurement["RecordPeriod"] = NewRecordPeriod;
			If BeforeCompletion Then
				Return;
			EndIf;
			
			For Each KeyOperationDateData In Measurements Do
				Buffer = KeyOperationDateData.Value;
				ForDeletion = New Array;
				For Each DateData In Buffer Do
					Date = DateData.Key;
					Data = DateData.Value;
					Duration = Data.Get("Duration");
					// If the operation is completed, delete it from the buffer.
					If Duration <> Undefined Then
						ForDeletion.Add(Date);
					EndIf;
				EndDo;
				For Each Date In ForDeletion Do
					PerformanceMonitorTimeMeasurement["Measurements"][KeyOperationDateData.Key].Delete(Date);
				EndDo;
			EndDo;
		EndIf;
		AttachIdleHandler("WriteResultsAuto", NewRecordPeriod, True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Ends the measurement of execution time on the client.
// Parameters:
//   AutoMeasurement - Boolean - True if the idle handler that measures execution time is completed.
Procedure EndTimeMeasurement(AutoMeasurement = True)
	
	EndDate = PerformanceMonitorClientServer.TimerValue(False);
	EndTime = PerformanceMonitorClientServer.TimerValue();
	
	If AutoMeasurement And TypeOf(EndTime) = Type("Number") Then
		EndTime = EndTime - 0.100;
	EndIf;
	
	ClientDateOffset = PerformanceMonitorTimeMeasurement["ClientDateOffset"];
	EndDate = EndDate + ClientDateOffset;
	
	Measurements = PerformanceMonitorTimeMeasurement["Measurements"];
	For Each KeyOperationBuffers In Measurements Do
		For Each DateData In KeyOperationBuffers.Value Do
			Buffer = DateData.Value;
			BeginTime = Buffer["BeginTime"];
			Duration = Buffer.Get("Duration");
			If Duration = Undefined Then
				Buffer.Insert("Duration", EndTime - BeginTime);
				Buffer.Insert("EndTime", EndTime);
				Buffer.Insert("EndDate", EndDate);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of SL subsystems

// The procedure is called before a user interactively logs off from a data area.
// It corresponds to BeforeExit application module events.
//
Procedure BeforeExit(Parameters) Export
	
	WriteResultsAutoNotGlobal(True);
	
EndProcedure

#EndRegion
