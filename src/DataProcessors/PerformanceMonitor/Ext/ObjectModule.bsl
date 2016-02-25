#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

//Generates a value table that will be displayed to users.
//
// Returns:
//  ValueTable - resulting value table.
//
Function PerformanceIndicators() Export
	
	EvaluationParameters = ParameterStructureForAPDEXCalculation();
	
	StepNumber = 0;
	StepCount = 0;
	If Not ChartPeriodicity(StepNumber, StepCount) Then
		Return Undefined;
	EndIf;
	
	EvaluationParameters.StepNumber = StepNumber;
	EvaluationParameters.StepCount  = StepCount;
	EvaluationParameters.StartDate  = StartDate;
	EvaluationParameters.EndDate    = EndDate;
	EvaluationParameters.KeyOperationTable = Performance.Unload(, "KeyOperation, Priority, TargetTime");
	If Not ValueIsFilled(OverallSystemPerformance) Or Performance.Find(OverallSystemPerformance, "KeyOperation") = Undefined Then
		EvaluationParameters.OutputTotals = False
	Else
		EvaluationParameters.OutputTotals = True;
	EndIf;
	
	Return EvaluateApdex(EvaluationParameters);
	
EndFunction

// Generates a query dynamically and gets the Apdex value.
//
// Parameters:
//  EvaluationParameters - Structure - see ParameterStructureForAPDEXCalculation().
//
// Returns:
//  ValueTable - table that stores key operations and performance indicators
//               for the specified period of time.
//
Function EvaluateApdex(EvaluationParameters) Export
	
	Query = New Query;
	Query.SetParameter("KeyOperationTable", EvaluationParameters.KeyOperationTable);
	Query.SetParameter("BeginOfPeriod",     EvaluationParameters.StartDate);
	Query.SetParameter("EndOfPeriod",       EvaluationParameters.EndDate);
	Query.SetParameter("KeyOperationTotal", OverallSystemPerformance);
	
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT
	|	KeyOperations.KeyOperation AS KeyOperation,
	|	KeyOperations.Priority AS Priority,
	|	KeyOperations.TargetTime AS TargetTime
	|INTO KeyOperations
	|FROM
	|	&KeyOperationTable AS KeyOperations";
	Query.Execute();
	
	QueryText = 
	"SELECT
	|	KeyOperations.KeyOperation AS KeyOperation,
	|	KeyOperations.Priority AS Priority,
	|	KeyOperations.TargetTime AS TargetTime%Columns%
	|FROM
	|	KeyOperations AS KeyOperations
	|		LEFT JOIN InformationRegister.TimeMeasurements AS TimeMeasurements
	|		ON KeyOperations.KeyOperation = TimeMeasurements.KeyOperation
	|		AND TimeMeasurements.MeasurementStartDate BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|WHERE
	|	NOT KeyOperations.KeyOperation = &KeyOperationTotal
	|
	|GROUP BY
	|	KeyOperations.KeyOperation,
	|	KeyOperations.Priority,
	|	KeyOperations.TargetTime
	|%Totals%";

	Expression = 
	"
	|	,CASE
	|		WHEN 
	|			// No key operation measurement records within this period
	|			Not 1 IN (
	|				SELECT TOP 1
	|					1 
	|				FROM 
	|					InformationRegister.TimeMeasurements AS InternalTimeMeasurements
	|				WHERE
	|					InternalTimeMeasurements.KeyOperation = KeyOperations.KeyOperation 
	|					AND InternalTimeMeasurements.KeyOperation <> &KeyOperationTotal
	|					AND InternalTimeMeasurements.MeasurementStartDate BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|					AND InternalTimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number% 
	|					AND InternalTimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|			) 
	|			THEN 0
	|
	|		ELSE (CAST((SUM(CASE
	|								WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|										AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|									THEN CASE
	|											WHEN TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime
	|												THEN 1
	|											ELSE 0
	|										END
	|								ELSE 0
	|							END) + SUM(CASE
	|								WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|										AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|									THEN CASE
	|											WHEN TimeMeasurements.ExecutionTime > KeyOperations.TargetTime
	|													AND TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime * 4
	|												THEN 1
	|											ELSE 0
	|										END
	|								ELSE 0
	|							END) / 2) / SUM(CASE
	|								WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|										AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|									THEN 1
	|								ELSE 0
	|							END) + 0.001 AS NUMBER(6, 3)))
	|	END AS Performance%Number%";
	
	ExpressionForTotals = 
	"
	|	,SUM(CASE
	|			WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|					AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|				THEN 1
	|			ELSE 0
	|		END) AS TimeTotal%Number%,
	|	SUM(CASE
	|			WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|					AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|				THEN CASE
	|						WHEN TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime
	|							THEN 1
	|						ELSE 0
	|					END
	|			ELSE 0
	|		END) AS TimeBefore%Number%,
	|	SUM(CASE
	|			WHEN TimeMeasurements.MeasurementStartDate >= &BeginOfPeriod%Number%
	|					AND TimeMeasurements.MeasurementStartDate <= &EndOfPeriod%Number%
	|				THEN CASE
	|						WHEN TimeMeasurements.ExecutionTime > KeyOperations.TargetTime
	|								AND TimeMeasurements.ExecutionTime <= KeyOperations.TargetTime * 4
	|							THEN 1
	|						ELSE 0
	|					END
	|			ELSE 0
	|		END) AS TempBetweenT4T%Number%";
	
	Total = 
	"
	|	MAX(TempTotal%Number%)";
	
	ByOverall = 
	"
	|	BY OVERALL";
	
	ColumnHeaders = New Array;
	Columns = "";
	Totals = "";
	BeginOfPeriod = EvaluationParameters.StartDate;
	For a = 0 To EvaluationParameters.StepCount - 1 Do
		
		EndOfPeriod = ?(a = EvaluationParameters.StepCount - 1, EvaluationParameters.EndDate, BeginOfPeriod + EvaluationParameters.StepNumber - 1);
		
		StepIndex = Format(a, "NZ=0; NG=0");
		Query.SetParameter("BeginOfPeriod" + StepIndex, BeginOfPeriod);
		Query.SetParameter("EndOfPeriod" + StepIndex, EndOfPeriod);
		
		ColumnHeaders.Add(ColumnHeader(BeginOfPeriod));
		
		BeginOfPeriod = BeginOfPeriod + EvaluationParameters.StepNumber;
		
		Columns = Columns + ?(EvaluationParameters.OutputTotals, ExpressionForTotals, "") + Expression;
		Columns = StrReplace(Columns, "%Number%", StepIndex);
		
		If EvaluationParameters.OutputTotals Then
			Totals = Totals + Total + ?(a = EvaluationParameters.StepCount - 1, "", ",");
			Totals = StrReplace(Totals, "%Number%", StepIndex);
		EndIf;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "%Columns%", Columns);
	QueryText = StrReplace(QueryText, "%Totals%", ?(EvaluationParameters.OutputTotals, "TOTALS" + Totals, ""));
	QueryText = QueryText + ?(EvaluationParameters.OutputTotals, ByOverall, "");
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return New ValueTable;
	Else
		KeyOperationTable = Result.Unload();
		
		KeyOperationTable.Sort("Priority");
		If EvaluationParameters.OutputTotals Then
			KeyOperationTable[0][0] = OverallSystemPerformance;
			CalculateTotalApdex(KeyOperationTable);
 
		EndIf;
		
		a = 0;
		ArrayIndex = 0;
		While a <= KeyOperationTable.Columns.Count() - 1 Do
			
			KeyOperationTableColumn = KeyOperationTable.Columns[a];
			If Left(KeyOperationTableColumn.Name, 4) = "Time" Then
				KeyOperationTable.Columns.Delete(KeyOperationTableColumn);
				Continue;
			EndIf;
			
			If a < 3 Then
				a = a + 1;
				Continue;
			EndIf;
			KeyOperationTableColumn.Title = ColumnHeaders[ArrayIndex];
			
			ArrayIndex = ArrayIndex + 1;
			a = a + 1;
			
		EndDo;
		
		Return KeyOperationTable;
	EndIf;
	
EndFunction

// Creates a parameter structure for Apdex calculation.
//
// Returns:
//  Structure:
//  	StepNumber   - Number - step size, in seconds.
//  	StepCount    - Number - number of steps in the period. 
//  	StartDate    - Date - measurement start date.
//  	EndDate      - Date - measurement end date.
//  	KeyOperationTable - ValueTable:
//  		   KeyOperation - CatalogRef.KeyOperations - key operation.
//  		   LineNumber - Number - key operation priority.
//  		   TargetTime - Number - key operation target time. 
//  	OutputTotals - Boolean - True if the resulting performance is calculated,
//  		             otherwise False.
//
Function ParameterStructureForAPDEXCalculation() Export
	
	Return New Structure(
		"StepNumber," +
		"StepCount," + 
		"StartDate," + 
		"EndDate," + 
		"KeyOperationTable," + 
		"OutputTotals");
	
EndFunction

// Calculates the number and size of steps in the specified interval.
//
// Parameters:
//  StepNumber [OUT] - Number - number of seconds that must be added to the start date 
//                              to execute the next step. 
//  StepCount [OUT]  - Number - number of steps in the specified interval.
//
// Returns:
//  Boolean - True if parameters have been calculated, otherwise False.
//
Function ChartPeriodicity(StepNumber, StepCount) Export
	
	TimeDifference = EndDate - StartDate + 1;
	
	If TimeDifference <= 0 Then
		Return False;
	EndIf;
	
	//StepCount is rounded up to an integer number
	StepCount = 0;
	If Step = "Hour" Then
		StepNumber = 86400 / 24;
		StepCount = TimeDifference / StepNumber;
		StepCount = Int(StepCount) + ?(StepCount - Int(StepCount) > 0, 1, 0);
	ElsIf Step = "Day" Then
		StepNumber = 86400;
		StepCount = TimeDifference / StepNumber;
		StepCount = Int(StepCount) + ?(StepCount - Int(StepCount) > 0, 1, 0);
	ElsIf Step = "Week" Then
		StepNumber = 86400 * 7;
		StepCount = TimeDifference / StepNumber;
		StepCount = Int(StepCount) + ?(StepCount - Int(StepCount) > 0, 1, 0);
	ElsIf Step = "Month" Then
		StepNumber = 86400 * 30;
		Time = EndOfDay(StartDate);
		While Time < EndDate Do
			Time = AddMonth(Time , 1);
			StepCount = StepCount + 1;
		EndDo;
	Else
		StepNumber = 0;
		StepCount = 1;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Calculates the resulting Apdex value.
//
// Parameters:
//  KeyOperationTable - ValueTable - result of the query that calculates APDEX value.
//
Procedure CalculateTotalApdex(KeyOperationTable)
	
	// Start from column 4, first 3 columns are KeyOperation, Priority, and TargetTime.
	InitialColumnIndex  = 3;
	TotalRowIndex		    = 0;
	PriorityColumnIndex = 1;
	LatestRowIndex	 = KeyOperationTable.Count() - 1;
	LatestColumnIndex	= KeyOperationTable.Columns.Count() - 1;
	MinimumPriority	= KeyOperationTable[LatestRowIndex][PriorityColumnIndex];
	
	// Clearing the totals row
	For Column = PriorityColumnIndex To LatestColumnIndex Do
		KeyOperationTable[TotalRowIndex][Column] = 0;
	EndDo;
	
	If MinimumPriority < 1 Then
		MessageText = NStr("en = 'Cannot calculate Apdex due to invalid priority values.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	MaximumActionsOverPeriodCount = KeyOperationTable[TotalRowIndex][InitialColumnIndex];
	
	Column = InitialColumnIndex;
	While Column < LatestColumnIndex Do
		
		// Starting the loop from 1 because 0 is a total row
		For Row = 1 To LatestRowIndex Do
			
			CurrentOperationPriority = KeyOperationTable[Row][PriorityColumnIndex];
			CurrentOperationCount    = KeyOperationTable[Row][Column];
			
			Coefficient = ?(CurrentOperationCount = 0, 0, 
							MaximumActionsOverPeriodCount / CurrentOperationCount * (1 - (CurrentOperationPriority - 1) / MinimumPriority));
			
			KeyOperationTable[Row][Column]     = KeyOperationTable[Row][Column] * Coefficient;
			KeyOperationTable[Row][Column + 1] = KeyOperationTable[Row][Column + 1] * Coefficient;
			KeyOperationTable[Row][Column + 2] = KeyOperationTable[Row][Column + 2] * Coefficient;
			
		EndDo;
		
		N  = KeyOperationTable.Total(KeyOperationTable.Columns[Column].Name);
		NS = KeyOperationTable.Total(KeyOperationTable.Columns[Column + 1].Name);
		NT = KeyOperationTable.Total(KeyOperationTable.Columns[Column + 2].Name);
		If N = 0 Then
			FinalApdex = 0;
		ElsIf NS = 0 And NT = 0 And N <> 0 Then
			FinalApdex = 0.001;
		Else
			FinalApdex = (NS + NT / 2) / N;
		EndIf;
		KeyOperationTable[TotalRowIndex][Column + 3] = FinalApdex;
		
		Column = Column + 4;
		
	EndDo;
	
EndProcedure

Function ColumnHeader(BeginOfPeriod)
	
	If Step = "Hour" Then
 
		ColumnHeader = String(Format(BeginOfPeriod, "L=en_US; DLF=T"));
	Else
		ColumnHeader = String(Format(BeginOfPeriod, "DF=M/d/yyyy"));
	EndIf;
	
	Return ColumnHeader;
	
EndFunction

#EndRegion
 
#EndIf