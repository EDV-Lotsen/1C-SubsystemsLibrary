////////////////////////////////////////////////////////////////////////////////
//  Methods related to writing key operation performance measurement   
//  results and further export of the results.
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Writes an array of measurement results. 
//
// Parameters:
//  Measurements - array with items of the Structure type.
//
// Returns:
//  Number - period of writing performance measurement results on the server, in seconds.
Function RegisterKeyOperationDuration (Measurements) Export
	
	For Each KeyOperationMeasurement In Measurements Do
		KeyOperationRef = KeyOperationMeasurement.Key;
		Buffer = KeyOperationMeasurement.Value;
		For Each DateData In Buffer Do
			Data = DateData.Value;
			Duration = Data.Get("Duration");
			If Duration = Undefined Then
				// Unfinished measurement, too early to write it
				Continue;
			EndIf;
			CommitKeyOperationsDuration(
				KeyOperationRef,
				Duration,
				DateData.Key,
				Data["EndDate"]);
		EndDo;
	EndDo;
	Return RecordPeriod();
EndFunction

// Returns the period of writing performance measurement results on the server.
//
// Returns:
// Number - period, in seconds. 
Function RecordPeriod() Export
	CurrentPeriod = Constants.PerformanceMonitorRecordPeriod.Get();
	Return ?(CurrentPeriod >= 1, CurrentPeriod, 60);
EndFunction

// Processes a data export scheduled job.
//
// Parameters:
//  DirectoriesForExport - structure with a value of the Array type.
//
Procedure PerformanceMonitorDataExport(DirectoriesForExport) Export
	
	CommonUse.ScheduledJobOnStart();
	
	// Skipping data export if performance measurement is turned off
	If Not PerformanceMonitorServerCallCached.EnablePerformanceMeasurements() Then
	    Return;	
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MAX(Measurements.RecordDate) AS MeasurementDate
	|FROM 
	|	InformationRegister.TimeMeasurements AS Measurements";
	Selection = Query.Execute().Select();
	If Selection.Next() And Selection.MeasurementDate <> Null Then
		MeasurementsDateUpperRange = Selection.MeasurementDate;
	Else 
		Return;	
	EndIf;
	
	Query = New Query;
	Query.SetParameter("MeasurementDate", MeasurementsDateUpperRange);
	GenerateQueryForApdexCalculation(Query);	
	APDEXSelection = Query.Execute().Select();
	
	MeasurementArrays = MeasurementsDividedByKeyOperations(MeasurementsDateUpperRange);
	ExportResults(DirectoriesForExport, APDEXSelection, MeasurementArrays);
	
EndProcedure

// Gets the current server date.
//
// Returns:
// Date - server date and time.
Function DateAndTimeAtServer() Export
	Return CurrentDate();
EndFunction

// Creates an item of the "Key operations" catalog.
//
// Parameters:
//  KeyOperationName - String - key operation name.
//
// Returns:
// CatalogRef.KeyOperations
//
Function CreateKeyOperation(KeyOperationName) Export
	
	BeginTransaction();
	
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("Catalog.KeyOperations");
		LockItem.SetValue("Name", KeyOperationName);
		LockItem.Mode = DataLockMode.Exclusive;
		DataLock.Lock();
		
		Query = New Query;
		Query.Text = "SELECT TOP 1
		               |	KeyOperations.Ref AS Ref
		               |FROM
		               |	Catalog.KeyOperations AS KeyOperations
		               |WHERE
		               |	KeyOperations.Name = &Name
		               |
		               |ORDER BY
		               |	Ref";
		
		Query.SetParameter("Name", KeyOperationName);
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			Description = SplitStringByWords(KeyOperationName);
			
			NewItem = Catalogs.KeyOperations.CreateItem();
			NewItem.Name = KeyOperationName;
			NewItem.Description = Description;
			NewItem.Write();
			KeyOperationRef = NewItem.Ref;
		Else
			Selection = QueryResult.Select();
			Selection.Next();
			KeyOperationRef = Selection.Ref;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise
	EndTry;
	
	Return KeyOperationRef;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

///////////////////////////////////////////////////////////////////////////////
// Writing key operation performance measurement result.

// Writes a single measurement.
//
// Parameters:
//  KeyOperation - CatalogRef.KeyOperations - key operation, 
// 	              or String - key operation name.				
//  Duration - Number.
//  KeyOperationStartDate - Date.
Procedure CommitKeyOperationsDuration(
	KeyOperation, 
	Duration, 
	KeyOperationStartDate,
	KeyOperationEndDate = Undefined
) Export
	
	If TypeOf(KeyOperation) = Type("String") Then
		KeyOperationRef = PerformanceMonitorServerCallCached.GetKeyOperationByName(KeyOperation);
	Else
		KeyOperationRef = KeyOperation;
	EndIf;
	
	Write = InformationRegisters.TimeMeasurements.CreateRecordManager();
	Write.KeyOperation         = KeyOperationRef;
	Write.MeasurementStartDate = ToUniversalTime(KeyOperationStartDate);
	Write.SessionNumber        = InfobaseSessionNumber();
	
	Write.ExecutionTime        = ?(Duration = 0, 0.001, Duration); // Duration is less than timer resolution
	
	Write.RecordDate           = ToUniversalTime(CurrentDate());
	If KeyOperationEndDate <> Undefined Then
		Write.EndDate = ToUniversalTime(KeyOperationEndDate);
	EndIf;
	Write.User            = InfobaseUsers.CurrentUser();
	Write.RecordDateLocal = CurrentSessionDate();
	
	Write.Write();
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Scheduled job that exports measurement results.

Function MeasurementsDividedByKeyOperations(MeasurementsDateUpperRange)
	Query = New Query;
	
	LastExportDate = Constants.LastPerformanceMeasurementExportDateUTC.Get();
	Constants.LastPerformanceMeasurementExportDateUTC.Set(MeasurementsDateUpperRange);
	
	Query.SetParameter("LastExportDate", LastExportDate);	
	Query.SetParameter("MeasurementsDateUpperRange", MeasurementsDateUpperRange);	
	
	Query.Text = "SELECT
	|	Measurements.KeyOperation,
	|	Measurements.MeasurementStartDate,
	|	Measurements.ExecutionTime,
	|	Measurements.User,
	|	Measurements.RecordDate,
	|	  Measurements.SessionNumber 
	|	FROM
	|		InformationRegister.TimeMeasurements AS Measurements
	|	WHERE
	|		Measurements.RecordDate >= &LastExportDate AND
	|	      Measurements.RecordDate <= &MeasurementsDateUpperRange
	|	ORDER BY
	|		Measurements.MeasurementStartDate";	
	ResultSelection = Query.Execute().Unload(); // Select();
	Columns = ResultSelection.Columns;	
	DividedMeasurements = New Map;
	KeyOperationColumnName = "KeyOperation";
	For Each ResultString In ResultSelection Do
		
		KeyOperationString = String(ResultString[KeyOperationColumnName]);
		MeasurementArrayByKeyOperation = DividedMeasurements.Get(KeyOperationString);
		If MeasurementArrayByKeyOperation = Undefined Then
			MeasurementArrayByKeyOperation = New Array;
			DividedMeasurements.Insert(KeyOperationString, MeasurementArrayByKeyOperation);	
		EndIf;
		Measurement = New Structure;
		For Each Column In Columns Do							
			Measurement.Insert(Column.Name, ResultString[Column.Name]);	
		EndDo;	
		
		MeasurementArrayByKeyOperation.Add(Measurement);
	EndDo;
	Return DividedMeasurements;
EndFunction	

// Generates a query for Apdex index calculation and sets the values of required parameters.
//
// Parameters:
//  Query - Query - the procedure fills the text and parameters of a passed query.
//
Procedure GenerateQueryForApdexCalculation(Query)
	
	OverallSystemPerformance = PerformanceMonitorInternal.GetOverallSystemPerformanceItem();
	
	GetMeasurements = 
	"SELECT
	|	&KeyOperation%KeyOperationNumber% AS KeyOperation,
	|	Measurements.ExecutionTime AS ExecutionTime
	|%TemporaryTableName%
	|FROM
	|	(SELECT TOP 100
	|		Measurements.KeyOperation AS KeyOperation,
	|		Measurements.ExecutionTime AS ExecutionTime
	|	FROM
	|		InformationRegister.TimeMeasurements AS Measurements
	|	WHERE
	|		Measurements.MeasurementStartDate < &MeasurementDate
	|		AND Measurements.KeyOperation = &KeyOperation%KeyOperationNumber%
	|       AND Measurements.ExecutionTime > 0
	|       AND Measurements.ExecutionTime < &KeyOperation%KeyOperationNumber%_MaxTime
	|	
	|	ORDER BY
	|		Measurements.MeasurementStartDate DESC) AS Measurements";
	
	UnionAll =
	"
	|
	|UNION ALL
	|
	|";
	
	IndexBy = 
	"
	|
	|INDEX
	|	BY KeyOperation";
	
	TemporaryTableSeparator = 
	"
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	EmptySelection = 
	"SELECT	
	|	VALUE(Catalog.KeyOperations.EmptyRef),
	|	0";
	
	QueryText = 
	"SELECT
	|	KeyOperations.Ref AS KeyOperation,
	|	KeyOperations.TargetTime AS TargetTime,
	|	KeyOperations.MinimumValidLevel AS ValidLevel
	|INTO TT_KeyOperations
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.DeletionMark = FALSE
	|	AND KeyOperations.Ref <> &OverallSystemPerformance";
	
	QueryText = QueryText + IndexBy + TemporaryTableSeparator;
	
	QueryForKeyOperations = New Query;
	QueryForKeyOperations.Text = "SELECT
	|	KeyOperations.Ref,
	|	KeyOperations.TargetTime
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.DeletionMark = FALSE
	|	AND KeyOperations.Ref <> &OverallSystemPerformance";
	
	QueryForKeyOperations.SetParameter("OverallSystemPerformance", OverallSystemPerformance);
	Selection = QueryForKeyOperations.Execute().Select();
	
	NoKeyOperations = True;
	KeyOperationNumber = 1;
	While Selection.Next() Do
		
		Query.SetParameter("KeyOperation" + KeyOperationNumber, Selection.Ref);
		Query.SetParameter("KeyOperation" + KeyOperationNumber + "_MaxTime", 1000 * Selection.TargetTime);
		Time = StrReplace(GetMeasurements, "%KeyOperationNumber%", String(KeyOperationNumber));
		Time = StrReplace(Time, "%TemporaryTableName%", ?(KeyOperationNumber = 1, "INTO TT_Measurements", ""));
		QueryText = QueryText + Time + UnionAll;
		
		KeyOperationNumber = KeyOperationNumber + 1;
		NoKeyOperations = False;
	EndDo;
	
	// If no key operations are available, return an empty selection
	If NoKeyOperations Then
		Query.Text = "Select 1 WHERE 1 < 0;";
		Return;
	EndIf;
	
	QueryText = QueryText + EmptySelection + IndexBy + TemporaryTableSeparator;
	
	QueryText = QueryText + 
	"SELECT
	|	TT_KeyOperations.KeyOperation AS KeyOperation,
	|	CASE
	|		WHEN
	|			// Key operation execution time is zero (no operations with execution time greater than zero)
	|			Not 1 IN (
	|				SELECT TOP 1 
	|					1
	|				FROM
	|					TT_Measurements AS MeasurementsInternal
	|				WHERE
	|					MeasurementsInternal.KeyOperation = TT_KeyOperations.KeyOperation
	|					AND MeasurementsInternal.ExecutionTime > 0
	|			)
	|			THEN -1
	|		ELSE CAST((SUM(CASE
	|						WHEN TT_Measurements.ExecutionTime <= TT_KeyOperations.TargetTime
	|							THEN 1
	|						ELSE 0
	|					END) + SUM(CASE
	|						WHEN TT_Measurements.ExecutionTime > TT_KeyOperations.TargetTime
	|								AND TT_Measurements.ExecutionTime <= TT_KeyOperations.TargetTime * 4
	|							THEN 1
	|						ELSE 0
	|					END) / 2) / SUM(1) AS NUMBER(6, 3))
	|	END AS CurrentApdex,
	|	CASE
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Excellent)
	|			THEN 1
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Good)
	|			THEN 0.94
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Fair)
	|			THEN 0.85
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Poor)
	|			THEN 0.7
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Unacceptable)
	|			THEN 0.5
	|	END AS MinimumApdex
	|FROM
	|	TT_KeyOperations AS TT_KeyOperations
	|		LEFT JOIN TT_Measurements AS TT_Measurements
	|		ON TT_KeyOperations.KeyOperation = TT_Measurements.KeyOperation
	|
	|GROUP BY
	|	TT_KeyOperations.KeyOperation,
	|	CASE
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Excellent)
	|			THEN 1
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Good)
	|			THEN 0.94
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Fair)
	|			THEN 0.85
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Poor)
	|			THEN 0.7
	|		WHEN TT_KeyOperations.ValidLevel = VALUE(Enum.PerformanceLevels.Unacceptable)
	|			THEN 0.5
	|	END
	|
	|HAVING
	|	CASE
	|		WHEN
	|			// Key operation execution time is zero (no operations with execution time greater than zero)
	|			NOT 1 IN (
	|				SELECT TOP 1 
	|					1
	|				FROM
	|					TT_Measurements AS MeasurementsInternal
	|				WHERE
	|					MeasurementsInternal.KeyOperation = TT_KeyOperations.KeyOperation
	|					AND MeasurementsInternal.ExecutionTime > 0
	|			)
	|			THEN -1
	|		ELSE CAST((SUM(CASE
	|						WHEN TT_Measurements.ExecutionTime <= TT_KeyOperations.TargetTime
	|							THEN 1
	|						ELSE 0
	|					END) + SUM(CASE
	|						WHEN TT_Measurements.ExecutionTime > TT_KeyOperations.TargetTime
	|								AND TT_Measurements.ExecutionTime <= TT_KeyOperations.TargetTime * 4
	|							THEN 1
	|						ELSE 0
	|					END) / 2) / SUM(1) AS NUMBER(6, 3))
	|	END >= 0";
	
	Query.SetParameter("OverallSystemPerformance", OverallSystemPerformance);
	Query.Text = QueryText;
	
EndProcedure

// Saves Apdex calculation result to a file.
//
// Parameters:
//  DirectoriesForExport - Structure with a value of the Array type.
//  APDEXSelection - query result.
//  MeasurementArrays - Structure with a value of the Array type.
Procedure ExportResults(DirectoriesForExport, APDEXSelection, MeasurementArrays)
	
	FileFormationDate = ToUniversalTime(CurrentSessionDate());
	Namespace = "www.v8.1c.ru/ssl/performace-assessment/apdexExport";
	TempFileName = GetTempFileName(".xml");
	
	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(TempFileName, "UTF-8");
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("Performance", Namespace);
	XMLWriter.WriteNamespaceMapping("prf", Namespace);
	XMLWriter.WriteNamespaceMapping("xs", "http://www.w3.org/2001/XMLSchema");
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	
	XMLWriter.WriteAttribute("version", Namespace, "1.0.0.0");
	XMLWriter.WriteAttribute("period", Namespace, String(FileFormationDate));
	
	TypeKeyOperation = XDTOFactory.Type(Namespace, "KeyOperation");
	TypeMeasurement = XDTOFactory.Type(Namespace, "Measurement");
		    
	While APDEXSelection.Next() Do
		KeyOperation = XDTOFactory.Create(TypeKeyOperation);
		KeyOperationString = String(APDEXSelection.KeyOperation);
		
		KeyOperation.name = KeyOperationString;
		KeyOperation.currentApdexValue = APDEXSelection.CurrentApdex;
		KeyOperation.minimalApdexValue = ?(APDEXSelection.MinimumApdex = NULL, 0, APDEXSelection.MinimumApdex);
		
		KeyOperation.priority = APDEXSelection.KeyOperation.Priority;
		KeyOperation.targetValue = APDEXSelection.KeyOperation.TargetTime;
		KeyOperation.uid = String(APDEXSelection.KeyOperation.Ref.UUID());
		
		Measurements = MeasurementArrays.Get(KeyOperationString);
		If Measurements <> Undefined Then
			For Each Measurement In Measurements Do
				XMLMeasurement = XDTOFactory.Create(TypeMeasurement);
				XMLMeasurement.value = Measurement.ExecutionTime;
				If TypeOf(Measurement.MeasurementStartDate) = Type("Number") Then
					MeasurementDate = Date("00010101") + Measurement.MeasurementStartDate / 1000;
				Else
					MeasurementDate = Measurement.MeasurementStartDate;
				EndIf;
				XMLMeasurement.tUTC = MeasurementDate;
				XMLMeasurement.userName = Measurement.User;
				XMLMeasurement.tSaveUTC = Measurement.RecordDate;
				XMLMeasurement.sessionNumber = Measurement.SessionNumber;
				KeyOperation.measurement.Add(XMLMeasurement);
			EndDo;
		EndIf;
		XDTOFactory.WriteXML(XMLWriter, KeyOperation);
		
	EndDo;
	XMLWriter.WriteEndElement();
	XMLWriter.Close();
	
	For Each ExecuteDirectoryKey In DirectoriesForExport Do
		ExecuteDirectory = ExecuteDirectoryKey.Value;
		ToExecute = ExecuteDirectory[0];
		If Not ToExecute Then
			Continue;
		EndIf;
		
		ExportDirectory = ExecuteDirectory[1];
		Key = ExecuteDirectoryKey.Key;
		If Key = PerformanceMonitorClientServer.LocalExportDirectoryJobKey() Then
			CreateDirectory(ExportDirectory);
		EndIf;
		
		FileCopy(TempFileName, ExportFileFullName(ExportDirectory, FileFormationDate, ".xml"));
	EndDo;
	DeleteFiles(TempFileName);
EndProcedure

// Generates a file name for exporting measurement results.
//
// Parameters:
//  Directory - String. 
//  FileFormationDate - Date - measurement date and time.
//  ExtentionWithDot - String - file extension in ".xxx" format. 
// Returns:
//  String - full path to the file.
//
Function ExportFileFullName(Directory, FileFormationDate, ExtentionWithDot)
	
	Separator = ?(Upper(Left(Directory, 3)) = "FTP", "/", CommonUseClientServer.PathSeparator());
	Return RemoveSeparatorsAtFileNameEnd(Directory, Separator) + Separator + Format(FileFormationDate, "DF=""yyyy-MM-dd HH-mm-ss""") + ExtentionWithDot;

EndFunction

// Checks whether a path ends with a slash mark and deletes the slash mark.
//
// Parameters:
//  FileName - String.
//  Separator - String.
// Returns:
//  FileName - String - file name without a slash mark at the end.
Function RemoveSeparatorsAtFileNameEnd(Val FileName, Separator)
	
	PathLength = StrLen(FileName);	
	If PathLength = 0 Then
		Return FileName;
	EndIf;
	
	While PathLength > 0 And Right(FileName, 1) = Separator Do
		FileName = Left(FileName, PathLength - 1);
		PathLength = StrLen(FileName);
	EndDo;
	
	Return FileName;
	
EndFunction

// Splits a string of several merged words into a string with separated words.
// A sign of new word beginning is an uppercase letter.
//
// Parameters:
//  String - String - text with separators.
//
// Returns:
//  String - String with separated words.
//
// Examples:
//  SplitStringByWords("OneTwoThree") returns the string "One two three".
//
Function SplitStringByWords(Val String)
	
	WordArray = New Array;
	
	WordPositions = New Array;
	For CharPosition = 1 To StrLen(String) Do
		CurrentChar = Mid(String, CharPosition, 1);
		If CurrentChar = Upper(CurrentChar) 
			And (StringFunctionsClientServer.OnlyLatinInString(CurrentChar)) Then 
				//Or StringFunctionsClientServer.OnlyRomanInString(CurrentChar)) Then 
			WordPositions.Add(CharPosition);
		EndIf;
	EndDo;
	
	If WordPositions.Count() > 0 Then
		PreviousPosition = 0;
		For Each Position In WordPositions Do
			If PreviousPosition > 0 Then
				Substring = Mid(String, PreviousPosition, Position - PreviousPosition);
				If Not IsBlankString(Substring) Then
					WordArray.Add(TrimAll(Substring));
				EndIf;
			EndIf;
			PreviousPosition = Position;
		EndDo;
		
		Substring = Mid(String, Position);
		If Not IsBlankString(Substring) Then
			WordArray.Add(TrimAll(Substring));
		EndIf;
	EndIf;
	
	For Index = 1 To WordArray.UBound() Do
		WordArray[Index] = Lower(WordArray[Index]);
	EndDo;
	
	Result = StringFunctionsClientServer.StringFromSubstringArray(WordArray, " ");
	
	Return Result;
	
EndFunction

#EndRegion