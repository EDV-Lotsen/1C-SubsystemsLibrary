////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// FillCheckProcessing object handler.
//
Procedure FillCheckProcessing(Cancellation, CheckedAttributes)
	
	ArrayOfExceptions = New Array;
	ArrayOfExceptions.Add(Catalogs.WorkTimeTypes.WeekEndDays);
	ArrayOfExceptions.Add(Catalogs.WorkTimeTypes.MainVacation);
	
	If DataInputMethod = Enums.TimeDataInputMethods.Daily Then
		
		For each TSLine In TimeWorkedByDays Do
			
			For Counter = 1 To 31 Do
			
				If ValueIsFilled(TSLine["FirstTimeKind" + Counter])
					And NOT ValueIsFilled(TSLine["FirstHours" + Counter]) Then
					
					If ArrayOfExceptions.Find(TSLine["FirstTimeKind" + Counter]) = Undefined Then 
					
						_DemoPayrollAndHRServer.ShowErrorMessage(ThisObject, 
						"Number of hours is not defined for a time type.",
						"TimeWorkedByDays",
						TSLine.LineNumber,
						"FirstClock" + Counter,
						Cancellation);
						
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(TSLine["SecondTimeKind" + Counter])
					And NOT ValueIsFilled(TSLine["SecondHours" + Counter]) Then
					
					If ArrayOfExceptions.Find(TSLine["SecondTimeKind" + Counter]) = Undefined Then 
					
						_DemoPayrollAndHRServer.ShowErrorMessage(ThisObject, 
						"Number of hours is not defined for a time type.",
						"TimeWorkedByDays",
						TSLine.LineNumber,
						"SecondHours" + Counter,
						Cancellation);
						
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(TSLine["ThirdTimeKind" + Counter])
					And NOT ValueIsFilled(TSLine["ThirdHours" + Counter]) Then
					
					If ArrayOfExceptions.Find(TSLine["ThirdTimeKind" + Counter]) = Undefined Then 
					
						_DemoPayrollAndHRServer.ShowErrorMessage(ThisObject, 
						"Number of hours is not defined for a time type.",
						"TimeWorkedByDays",
						TSLine.LineNumber,
						"ThirdHours" + Counter,
						Cancellation);
						
					EndIf;
					
				EndIf;
			
			EndDo;		
			
		EndDo; 
		
	Else	
		
		For each TSLine In TimeWorkedPerPeriod Do
			For Counter = 1 To 6 Do
			
				If ValueIsFilled(TSLine["TimeKind" + Counter])
					And NOT ValueIsFilled(TSLine["Days" + Counter])
					And NOT ValueIsFilled(TSLine["Hours" + Counter]) Then
					_DemoPayrollAndHRServer.ShowErrorMessage(ThisObject, 
					"Number of days and hours is not defined for a time type.",
					"TimeWorkedPerPeriod",
					TSLine.LineNumber,
					"TimeKind" + Counter,
					Cancellation);
				EndIf;
			
			EndDo;		
		EndDo;
		
	EndIf;
	
EndProcedure

// Posting event handler.
//
Procedure Posting(Cancellation, PostingMode)
	
	// Initializing additional properties for posting the document.
	_DemoPayrollAndHRServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initializing the document data
	Documents.Timesheet.DataInitializationDocument(Ref, AdditionalProperties);
	
	// Preparing the record sets
	_DemoPayrollAndHRServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Accounting
	_DemoPayrollAndHRServer.ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancellation);
	
	// Writing the record sets
	_DemoPayrollAndHRServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// UndoPosting event handler.
//
Procedure UndoPosting(Cancellation)
	
	// Initializing additional properties for clearing document posting
	_DemoPayrollAndHRServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparing the record sets.
	_DemoPayrollAndHRServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing the record sets
	_DemoPayrollAndHRServer.WriteRecordSets(ThisObject);
		
EndProcedure
