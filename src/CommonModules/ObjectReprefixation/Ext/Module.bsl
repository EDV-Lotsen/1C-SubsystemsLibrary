////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Sets up a new infobase prefix and changes object codes and numbers in accordance 
// with the new prefix and code/number format.
// Only objects that are created in the current infobase can be processed.
// Object creation location is determined by its number prefix or code prefix.
//
//  Parameters:
//  NewInfobasePrefix      - String  - New infobase prefix that requires setting. 
//  PrefixationPeriodBegin - Date    - The date on which a new infobase prefix for documents,
//                                     business processes, and tasks will be set.
//  PreviousInfobasePrefix - String  - Previously set infobase prefix.
//                                     The value of the variable should be set only
//                                     if infobase prefix value is lost, for example,
//                                     during local mode switch to SaaS mode.
//                                     It is also necessary if object numbers and codes have a
//                                     nonstandard file format different from SL file format.
//  ObjectsProcessed       - Number  - The number of objects whose number or code are changed 
//                                     is returned to this parameter.
//
Procedure SetInfobasePrefixAndResetPrefixForThisInfobaseObjects(
									Val NewInfobasePrefix,
									Val PrefixationPeriodBegin = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	InternalSetInfobasePrefixAndResetPrefixForThisInfobaseObjects(NewInfobasePrefix, PrefixationPeriodBegin, PreviousInfobasePrefix, ObjectsProcessed);
	
EndProcedure

// Sets up a new infobase prefix and changes object codes and numbers in accordance with 
// the new prefix and code/number format.
// Objects created in any infobase are to be processed.
// Object creation location is determined by its number prefix or code prefix.
//
//  Parameters:
//  NewInfobasePrefix      - String - New infobase prefix that requires setting.
//  PrefixationPeriodBegin - Date   - The date on which a new infobase prefix for documents, 
//                                    business processes, and tasks will be set.
//  PreviousInfobasePrefix - String - Previously set infobase prefix.
//                                    The value of the variable should be set only
//                                    if infobase prefix value is lost, for example,
//                                    during local mode switch to SaaS mode.
//                                    It is also necessary if object numbers and codes have a
//                                    nonstandard file format different from SL file format.
//  ObjectsProcessed       - Number - The number of objects whose number or code are changed 
//                                    is returned to this parameter.
//
Procedure SetInfobasePrefixAndResetPrefixForAllObjects(
									Val NewInfobasePrefix,
									Val PrefixationPeriodBegin = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	InternalSetInfobasePrefixAndResetPrefixForAllObjects(NewInfobasePrefix, PrefixationPeriodBegin, PreviousInfobasePrefix, ObjectsProcessed);
	
EndProcedure

// Sets up a new infobase prefix and creates new objects,
// one for every data type with a new infobase prefix and number/code SL format.
// Only objects that are created in the current infobase can be processed.
// Object creation location is determined by its number prefix or code prefix.
//
//  Parameters:
//  NewInfobasePrefix            - String - New infobase prefix that requires setting.
//  PrefixationPeriodBegin - Date   - The start date of data analysis.
//  PreviousInfobasePrefix - String - Previously set infobase prefix.
//                                    The value of the variable should be set only
//                                    if infobase prefix value is lost, for example,
//                                    during local mode switch to SaaS mode.
//                                    It is also necessary if object numbers and codes have a
//                                    nonstandard file format different from SL file format.
//  ObjectsProcessed       - Number - The created object number is returned to this parameter.
//
Procedure SetInfobasePrefixAndCreateObjects(
									Val NewInfobasePrefix,
									Val PrefixationPeriodBegin = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	InternalSetInfobasePrefixAndCreateObjects(NewInfobasePrefix, PrefixationPeriodBegin, PreviousInfobasePrefix, ObjectsProcessed);
	
EndProcedure

// Sets up a new infobase prefix and changes the last actual
// object code or number for every data type.
// Only objects that are created in the current infobase can be processed.
// Object creation location is determined by its number prefix or code prefix.
//
// Parameters:
//  NewInfobasePrefix      - String - New infobase prefix that requires setting.
//  PrefixationPeriodBegin - Date   - The start date of data analysis.
//  PreviousInfobasePrefix - String - Previously set infobase prefix.
//                                    The value of the variable should be set only
//                                    if infobase prefix value is lost, for example,
//                                    during local mode switch to SaaS mode.
//                                    It is also necessary if object numbers and codes have a
//                                    nonstandard file format different from SL file format.
//  ObjectsProcessed       - Number - The changed object number is returned to this parameter.
//
Procedure SetInfobasePrefixAndResetPrefixForFinalObjects(
									Val NewInfobasePrefix,
									Val PrefixationPeriodBegin = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ObjectsProcessed = 0
	) Export
	
	InternalSetInfobasePrefixAndResetPrefixForFinalObjects(NewInfobasePrefix, PrefixationPeriodBegin, PreviousInfobasePrefix, ObjectsProcessed);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure InternalSetInfobasePrefixAndResetPrefixForThisInfobaseObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	If TransactionActive() Then
		
		Raise NStr("en = 'Infobase prefix cannot be updated in transaction.'");
		
	ElsIf Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en = 'You do not have sufficient permissions to change infobase prefix.'");
		
	EndIf;
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		SetPrivilegedMode(True);
	EndIf;
	
	FromDate = ?(FromDate = Date('00010101'), Undefined, FromDate);
	
	StandardPrefix = (PreviousInfobasePrefix = Undefined);
	
	ProcessedObjectsCounter = 0;
	
	If StandardPrefix Then
		
		SetNewPrefixAndProcessDataWithStandardCodeFormat(NewPrefix, FromDate, PreviousInfobasePrefix,, ProcessedObjectsCounter);
		
	Else
		
		SetNewPrefixAndProcessDataWithNonStandardCodeFormat(NewPrefix, FromDate, PreviousInfobasePrefix,, ProcessedObjectsCounter);
		
	EndIf;
	
EndProcedure

Procedure InternalSetInfobasePrefixAndResetPrefixForAllObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	If TransactionActive() Then
		
		Raise NStr("en = 'Infobase prefix cannot be updated in transaction.'");
		
	ElsIf Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en = 'You do not have sufficient permissions to change infobase prefix.'");
		
	EndIf;
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		SetPrivilegedMode(True);
	EndIf;
	
	FromDate = ?(FromDate = Date('00010101'), Undefined, FromDate);
	
	StandardPrefix = (PreviousInfobasePrefix = Undefined);
	
	ProcessedObjectsCounter = 0;
	
	If StandardPrefix Then
		
		SetNewPrefixAndProcessDataWithStandardCodeFormat(NewPrefix, FromDate,, True, ProcessedObjectsCounter);
		
	Else
		
		SetNewPrefixAndProcessDataWithNonStandardCodeFormat(NewPrefix, FromDate,, True, ProcessedObjectsCounter);
		
	EndIf;
	
EndProcedure

Procedure InternalSetInfobasePrefixAndCreateObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	ProcessedObjectsCounter = 0;
	
	SetInfobasePrefixAndCreateChangeObjects(NewPrefix, FromDate, PreviousInfobasePrefix, False, ProcessedObjectsCounter);
	
EndProcedure

Procedure InternalSetInfobasePrefixAndResetPrefixForFinalObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									ProcessedObjectsCounter = 0)
	
	ProcessedObjectsCounter = 0;
	
	SetInfobasePrefixAndCreateChangeObjects(NewPrefix, FromDate, PreviousInfobasePrefix, True, ProcessedObjectsCounter);
	
EndProcedure

//

Procedure SetNewPrefixAndProcessDataWithNonStandardCodeFormat(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									Val ProcessAllData = False,
									ProcessedObjectsCounter)
	
	ValidatePrefixInstallationPossibility();
	
	StandardPrefix = False;
	
	If PreviousInfobasePrefix = Undefined Then
		
		OnInfobasePrefixDefinition(PreviousInfobasePrefix);
		
		SupplementStringWithZerosFromLeft(PreviousInfobasePrefix, 2);
		
	EndIf;
	
	Try
		
		SetInfobasePrefix(NewPrefix);
		
		CommonUse.LockInfobase(False);
		
		For Each ObjectDescription In InfobasePrefixUsingMetadata() Do
			
			Selection = DataSelection(
						ObjectDescription.ObjectName,
						FromDate,
						ObjectDescription.IsDocument,
						StandardPrefix,
						PreviousInfobasePrefix,
						ProcessAllData);
			
			If Selection.IsEmpty() Then
				Continue;
			EndIf;
			
			Selection = Selection.Select();
			
			While Selection.Next() Do
				
				// {Filter: To object creation location}
				If Not ProcessAllData Then
					
					ObjectFullPrefix = FullPrefix(Selection.Code);
					
					If Not IsBlankString(ObjectFullPrefix)
						And Find(ObjectFullPrefix, PreviousInfobasePrefix) = 0 Then
						Continue; // Process only objects that are created in the current infobase
					EndIf;
					
				EndIf;
				
				Object = Selection.Ref.GetObject();
				
				If ObjectDescription.IsDocument Then
					
					Object.SetNewNumber();
					
					CodeFormat = Object.Number;
					
				Else
					
					Object.SetNewCode();
					
					CodeFormat = Object.Code;
					
				EndIf;
				
				// {Handler: OnNumberChange} Begin
				StandardProcessing = True;
				BaseCode = "";
				
				If ObjectDescription.IsDocument Then
					
					ObjectPrefixationOverridable.OnNumberChange(Object, Selection.Code, BaseCode, StandardProcessing);
					
				Else
					
					ObjectPrefixationOverridable.OnCodeChange(Object, Selection.Code, BaseCode, StandardProcessing);
					
				EndIf;
				
				If StandardProcessing = True Then
					
					NewCode = NewObjectCode(CodeFormat, Selection.Code, ObjectDescription.IsDocument, Object);
					
				Else
					
					NewCode = NewObjectCodeByBaseCode(CodeFormat, BaseCode, ObjectDescription.IsDocument, Object);
					
				EndIf;
				// {Handler: OnNumberChange} End
				
				ObjectModified = (Selection.Code <> NewCode);
				
				If ObjectModified Then
					
					Object[?(ObjectDescription.IsDocument, "Number", "Code")] = NewCode;
					
					Object.DataExchange.Load = True;
					Object.Write();
					
					IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		CommonUse.UnlockInfobase();
		
	Except
		
		CommonUse.UnlockInfobase();
		
		SetInfobasePrefix(PreviousInfobasePrefix);
		
		WriteLogEvent(EventLogMessageTextObjectReprefixation(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SetNewPrefixAndProcessDataWithStandardCodeFormat(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									Val ProcessAllData = False,
									ProcessedObjectsCounter)
	
	ValidatePrefixInstallationPossibility();
	
	NewFullPrefix = StringFunctionsClientServer.SupplementString(NewPrefix, 2);
	
	StandardPrefix = True;
	
	If PreviousInfobasePrefix = Undefined Then
		
		OnInfobasePrefixDefinition(PreviousInfobasePrefix);
		
		SupplementStringWithZerosFromLeft(PreviousInfobasePrefix, 2);
		
	EndIf;
	
	Try
		
		SetInfobasePrefix(NewPrefix);
		
		CommonUse.LockInfobase(False);
		
		// Prefixation by infobase prefix
		For Each ObjectDescription In OnlyInfobasePrefixUsingMetadata() Do
			
			SetNewPrefix(
							2,
							ObjectDescription.ObjectName,
							FromDate,
							ObjectDescription.IsDocument,
							PreviousInfobasePrefix,
							ProcessAllData,
							NewFullPrefix,
							ProcessedObjectsCounter);
			
		EndDo;
		
		// Prefixation by infobase and company prefix
		For Each ObjectDescription In InfobasePrefixAndCompanyPrefixUsingMetadata() Do
			
			SetNewPrefix(
							4,
							ObjectDescription.ObjectName,
							FromDate,
							ObjectDescription.IsDocument,
							PreviousInfobasePrefix,
							ProcessAllData,
							NewFullPrefix,
							ProcessedObjectsCounter);
			
		EndDo;
		
		CommonUse.UnlockInfobase();
		
	Except
		
		CommonUse.UnlockInfobase();
		
		SetInfobasePrefix(PreviousInfobasePrefix);
		
		WriteLogEvent(EventLogMessageTextObjectReprefixation(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// For internal use
//
Procedure SetInfobasePrefixAndCreateChangeObjects(
									Val NewPrefix,
									Val FromDate = Undefined,
									Val PreviousInfobasePrefix = Undefined,
									Val ProcessFinalObjects = False,
									ProcessedObjectsCounter
	) Export
	
	ValidatePrefixInstallationPossibility();
	
	FromDate = ?(FromDate = Date('00010101'), Undefined, FromDate);
	
	StandardPrefix = (PreviousInfobasePrefix = Undefined);
	
	ProcessAllData = False;
	
	If TransactionActive() Then
		
		Raise NStr("en = 'Infobase prefix cannot be updated in transaction.'");
		
	ElsIf Not Users.InfobaseUserWithFullAccess() Then
		
		Raise NStr("en = 'You do not have sufficient permissions to change infobase prefix.'");
		
	EndIf;
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		SetPrivilegedMode(True);
	EndIf;
	
	If PreviousInfobasePrefix = Undefined Then
		
		OnInfobasePrefixDefinition(PreviousInfobasePrefix);
		
		SupplementStringWithZerosFromLeft(PreviousInfobasePrefix, 2);
		
	EndIf;
	
	Try
		
		SetInfobasePrefix(NewPrefix);
		
		CommonUse.LockInfobase(False);
		
		// Prefixation by infobase prefix
		For Each ObjectDescription In OnlyInfobasePrefixUsingMetadata() Do
			
			Selection = DataSelection(
						ObjectDescription.ObjectName,
						FromDate,
						ObjectDescription.IsDocument,
						StandardPrefix,
						PreviousInfobasePrefix,
						ProcessAllData);
			
			If Selection.IsEmpty() Then
				Continue;
			EndIf;
			
			Objects = New ValueTable;
			Objects.Columns.Add("Code");
			Objects.Columns.Add("Date");
			Objects.Columns.Add("Period");
			Objects.Columns.Add("Object");
			
			Selection = Selection.Select();
			
			While Selection.Next() Do
				
				// {Filter: To nonstandard prefix object creation location}
				If Not ProcessAllData
					And Not StandardPrefix Then
					
					ObjectFullPrefix = FullPrefix(Selection.Code);
					
					If Not IsBlankString(ObjectFullPrefix)
						And Find(ObjectFullPrefix, PreviousInfobasePrefix) = 0 Then
						Continue; // Process only objects that are created in the current infobase
					EndIf;
					
				EndIf;
				
				TableRow = Objects.Add();
				TableRow.Code = ObjectNumericCode(Selection.Code);
				TableRow.Date = Selection.Date;
				TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
				TableRow.Object = Selection.Ref;
				
			EndDo;
			
			If Objects.Count() > 0 Then
				
				If ProcessFinalObjects Then
					
					Objects.Sort("Period Desc, Code Desc");
					
					Object = Objects[0]["Object"].GetObject();
					
					PreviousCode = Object[?(ObjectDescription.IsDocument, "Number", "Code")];
					
					If ObjectDescription.IsDocument Then
						
						Object.SetNewNumber();
						
						CodeFormat = Object.Number;
						
					Else
						
						Object.SetNewCode();
						
						CodeFormat = Object.Code;
						
					EndIf;
					
					If StandardPrefix Then
						
						NewCode = NewObjectCode(CodeFormat, PreviousCode, ObjectDescription.IsDocument, Object);
						
					Else
						
						// {Handler: OnNumberChange} Begin
						StandardProcessing = True;
						BaseCode = "";
						
						If ObjectDescription.IsDocument Then
							
							ObjectPrefixationOverridable.OnNumberChange(Object, PreviousCode, BaseCode, StandardProcessing);
							
						Else
							
							ObjectPrefixationOverridable.OnCodeChange(Object, PreviousCode, BaseCode, StandardProcessing);
							
						EndIf;
						
						If StandardProcessing = True Then
							
							NewCode = NewObjectCode(CodeFormat, PreviousCode, ObjectDescription.IsDocument, Object);
							
						Else
							
							NewCode = NewObjectCodeByBaseCode(CodeFormat, BaseCode, ObjectDescription.IsDocument, Object);
							
						EndIf;
						// {Handler: OnNumberChange} End
						
					EndIf;
					
					ObjectModified = (PreviousCode <> NewCode);
					
					If ObjectModified Then
						
						Object[?(ObjectDescription.IsDocument, "Number", "Code")] = NewCode;
						
						Object.DataExchange.Load = True;
						Object.Write();
						
						IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
						
					EndIf;
					
				Else // Create new objects
					
					Objects.Sort("Period Desc, Code Desc");
					
					MaximumCode = Objects[0]["Code"];
					
					Objects.Sort("Date Desc");
					
					MaximumDate = Objects[0]["Date"];
					
					Object = CreateObject(ObjectDescription);
					
					If ObjectDescription.IsDocument Then
						
						Object.Date = MaximumDate + 1;
						Object.SetNewNumber();
						
						CodeFormat = Object.Number;
						
					Else
						
						Object.SetNewCode();
						
						CodeFormat = Object.Code;
						
					EndIf;
					
					NewCode = NewObjectCode(CodeFormat, MaximumCode + 1, ObjectDescription.IsDocument, Object);
					
					Object[?(ObjectDescription.IsDocument, "Number", "Code")] = NewCode;
					
					Object.DataExchange.Load = True;
					Object.Write();
					
					IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		// Prefixation by infobase and company prefix
		For Each ObjectDescription In InfobasePrefixAndCompanyPrefixUsingMetadata() Do
			
			Selection = DataSelection(
						ObjectDescription.ObjectName,
						FromDate,
						ObjectDescription.IsDocument,
						StandardPrefix,
						PreviousInfobasePrefix,
						ProcessAllData,
						True);
			
			If Selection.IsEmpty() Then
				Continue;
			EndIf;
			
			CompanyWithoutPrefix = "{CompanyWithoutPrefix}";
			
			Objects = New ValueTable;
			Objects.Columns.Add("Code");
			Objects.Columns.Add("Date");
			Objects.Columns.Add("Period");
			Objects.Columns.Add("Object");
			
			Grouping = New Map;
			Grouping.Insert(CompanyWithoutPrefix, Objects);
			
			Selection = Selection.Select();
			
			While Selection.Next() Do
				
				// {Filter: To nonstandard prefix object creation location}
				If Not ProcessAllData
					And Not StandardPrefix Then
					
					ObjectFullPrefix = FullPrefix(Selection.Code);
					
					If Not IsBlankString(ObjectFullPrefix)
						And Find(ObjectFullPrefix, PreviousInfobasePrefix) = 0 Then
						Continue; // Process only objects that are created in the current infobase
					EndIf;
					
				EndIf;
				
				If Selection.CompanyPrefixIsSpecified Then
					
					If Grouping[Selection.Company] = Undefined Then
						
						Objects = New ValueTable;
						Objects.Columns.Add("Code");
						Objects.Columns.Add("Date");
						Objects.Columns.Add("Period");
						Objects.Columns.Add("Object");
						
						TableRow = Objects.Add();
						TableRow.Code = ObjectNumericCode(Selection.Code);
						TableRow.Date = Selection.Date;
						TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
						TableRow.Object = Selection.Ref;
						
						Grouping.Insert(Selection.Company, Objects);
						
					Else
						
						TableRow = Grouping[Selection.Company].Add();
						TableRow.Code = ObjectNumericCode(Selection.Code);
						TableRow.Date = Selection.Date;
						TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
						TableRow.Object = Selection.Ref;
						
					EndIf;
					
				Else
					
					TableRow = Grouping[CompanyWithoutPrefix].Add();
					TableRow.Code = ObjectNumericCode(Selection.Code);
					TableRow.Date = Selection.Date;
					TableRow.Period = PeriodDate(Selection.Date, ObjectDescription.NumberPeriodicity);
					TableRow.Object = Selection.Ref;
					
				EndIf;
				
			EndDo;
			
			For Each GroupItem In Grouping Do
				
				Objects = GroupItem.Value;
				Company = GroupItem.Key;
				
				If Objects.Count() > 0 Then
					
					If ProcessFinalObjects Then
						
						Objects.Sort("Period Desc, Code Desc");
						
						Object = Objects[0]["Object"].GetObject();
						
						PreviousCode = Object[?(ObjectDescription.IsDocument, "Number", "Code")];
						
						If ObjectDescription.IsDocument Then
							
							Object.SetNewNumber();
							
							CodeFormat = Object.Number;
							
						Else
							
							Object.SetNewCode();
							
							CodeFormat = Object.Code;
							
						EndIf;
						
						If StandardPrefix Then
							
							NewCode = NewObjectCode(CodeFormat, PreviousCode, ObjectDescription.IsDocument, Object);
							
						Else
							
							// {Handler: OnNumberChange} Begin
							StandardProcessing = True;
							BaseCode = "";
							
							If ObjectDescription.IsDocument Then
								
								ObjectPrefixationOverridable.OnNumberChange(Object, PreviousCode, BaseCode, StandardProcessing);
								
							Else
								
								ObjectPrefixationOverridable.OnCodeChange(Object, PreviousCode, BaseCode, StandardProcessing);
								
							EndIf;
							
							If StandardProcessing = True Then
								
								NewCode = NewObjectCode(CodeFormat, PreviousCode, ObjectDescription.IsDocument, Object);
								
							Else
								
								NewCode = NewObjectCodeByBaseCode(CodeFormat, BaseCode, ObjectDescription.IsDocument, Object);
								
							EndIf;
							// {Handler: OnNumberChange} End
							
						EndIf;
						
						ObjectModified = (PreviousCode <> NewCode);
						
						If ObjectModified Then
							
							Object[?(ObjectDescription.IsDocument, "Number", "Code")] = NewCode;
							
							Object.DataExchange.Load = True;
							Object.Write();
							
							IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
							
						EndIf;
						
					Else
						
						Objects.Sort("Period Desc, Code Desc");
						
						MaximumCode = Objects[0]["Code"];
						
						Objects.Sort("Date Desc");
						
						MaximumDate = Objects[0]["Date"];
						
						Object = CreateObject(ObjectDescription);
						
						Object.Company = ?(Company = CompanyWithoutPrefix, Undefined, Company);
						
						If ObjectDescription.IsDocument Then
							
							Object.Date = MaximumDate + 1;
							
							Object.SetNewNumber();
							
							CodeFormat = Object.Number;
							
						Else
							
							Object.SetNewCode();
							
							CodeFormat = Object.Code;
							
						EndIf;
						
						NewCode = NewObjectCode(CodeFormat, MaximumCode + 1, ObjectDescription.IsDocument, Object);
						
						Object[?(ObjectDescription.IsDocument, "Number", "Code")] = NewCode;
						
						Object.DataExchange.Load = True;
						Object.Write();
						
						IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		CommonUse.UnlockInfobase();
		
	Except
		
		CommonUse.UnlockInfobase();
		
		SetInfobasePrefix(PreviousInfobasePrefix);
		
		WriteLogEvent(EventLogMessageTextObjectReprefixation(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Function DataSelection(
					Val ObjectName,
					Val FromDate,
					Val IsDocument,
					Val StandardPrefix,
					Val PreviousPrefix,
					Val ProcessAllData,
					Val ChooseCompany = False)
	
	Query = New Query;
	
	If ProcessAllData Then
		
		If IsDocument And FromDate <> Undefined Then
			
			QueryText =
			"SELECT
			|	[CompanySelection]
			|	[CompanyPrefixIsSpecified]
			|	[DateSelection]
			|	Table.[Code] AS Code,
			|	Table.Ref AS Ref
			|FROM
			|	[ObjectName] AS Table
			|WHERE
			|	Table.Date >= &Date
			|
			|ORDER BY
			|	Table.Date";
			
			Query.SetParameter("Date", BegOfDay(FromDate));
			
		Else
			
			QueryText =
			"SELECT
			|	[CompanySelection]
			|	[CompanyPrefixIsSpecified]
			|	[DateSelection]
			|	Table.[Code] AS Code,
			|	Table.Ref AS Ref
			|FROM
			|	[ObjectName] AS Table";
			
		EndIf;
		
	Else
		
		If StandardPrefix Then
			
			If IsDocument And FromDate <> Undefined Then
				
				QueryText =
				"SELECT
				|	[CompanySelection]
				|	[CompanyPrefixIsSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table
				|WHERE
				|	Table.Date >= &Date
				|	AND Table.[Code] LIKE &Prefix
				|
				|ORDER BY
				|	Table.Date";
				
				Query.SetParameter("Date", BegOfDay(FromDate));
				
			Else
				
				QueryText =
				"SELECT
				|	[CompanySelection]
				|	[CompanyPrefixIsSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table
				|WHERE
				|	Table.[Code] LIKE &Prefix";
				
			EndIf;
			
			// Process objects that are created only in the current infobase
			Prefix = "%[Prefix]-%";
			Prefix = StrReplace(Prefix, "[Prefix]", PreviousPrefix);
			Query.SetParameter("Prefix", Prefix);
			
		Else
			
			If IsDocument And FromDate <> Undefined Then
				
				QueryText =
				"SELECT
				|	[CompanySelection]
				|	[CompanyPrefixIsSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table
				|WHERE
				|	Table.Date >= &Date
				|
				|ORDER BY
				|	Table.Date";
				
				Query.SetParameter("Date", BegOfDay(FromDate));
				
			Else
				
				QueryText =
				"SELECT
				|	[CompanySelection]
				|	[CompanyPrefixIsSpecified]
				|	[DateSelection]
				|	Table.[Code] AS Code,
				|	Table.Ref AS Ref
				|FROM
				|	[ObjectName] AS Table";
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	QueryText = StrReplace(QueryText, "[ObjectName]", ObjectName);
	QueryText = StrReplace(QueryText, "[Code]", ?(IsDocument, "Number", "Code"));
	If ChooseCompany Then
		CompanyFieldName = ObjectPrefixationEvents.AttributeNameCompany(ObjectName);
	EndIf;
	QueryText = StrReplace(QueryText, "[CompanySelection]", 
		?(ChooseCompany, "Table." + CompanyFieldName + " AS Company,", ""));
	QueryText = StrReplace(QueryText, "[CompanyPrefixIsSpecified]",
		?(ChooseCompany,
		"CASE WHEN Table." + CompanyFieldName + ".Prefix = """" THEN False ELSE True END AS CompanyPrefixIsSpecified,",
		"False AS CompanyPrefixIsSpecified,"));
	QueryText = StrReplace(QueryText, "[DateSelection]", ?(IsDocument, "Table.Date AS Date,", "Undefined AS Date,"));
	
	Query.Text = QueryText;
	
	Return Query.Execute();
EndFunction

Function NewObjectCode(Val NewCodeFormat, Val Code, Val IsDocument, Object)
	
	If TypeOf(Code) = Type("String") Then
		
		NumericCode = ObjectNumericCode(Code);
		
	ElsIf TypeOf(Code) = Type("Number") Then
		
		NumericCode = Code;
		
	EndIf;
	
	NewFullPrefix = FullPrefix(NewCodeFormat);
	
	CodeLength = StrLen(NewCodeFormat);
	
	CodeString = Format(NumericCode, "NZ=0; NG=0");
	
	LeadingZerosNumber = CodeLength - StrLen(NewFullPrefix) - StrLen(CodeString);
	
	If LeadingZerosNumber < 0 Then
		
		MessageString = NStr("en = 'Unable to perform the %1 transformation on the %2 object.
							|Insufficient length %1. Minimum length of the %1 object should not be less than %3 characters.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
					?(IsDocument, NStr("en = 'numbers'"), NStr("en = 'code'")),
					String(Object),
					String(StrLen(NewFullPrefix) + StrLen(CodeString)));
		Raise MessageString;
	EndIf;
	
	CodeLengthWithLeadingZeros = CodeLength - StrLen(NewFullPrefix);
	
	If NumericCode = 0 Then
		
		CodeWithLeadingZeros = Left("00000000000000000000000000000000000000000000000000", CodeLengthWithLeadingZeros);
		
	Else
		
		FormatString = "ND=%1; NLZ=; NG=0";
		FormatString = StringFunctionsClientServer.SubstituteParametersInString(FormatString, String(CodeLengthWithLeadingZeros));
		CodeWithLeadingZeros = Format(NumericCode, FormatString);
		
	EndIf;
	
	Return NewFullPrefix + CodeWithLeadingZeros;
EndFunction

Function NewObjectCodeByBaseCode(Val NewCodeFormat, Val BaseCode, Val IsDocument, Object)
	
	NewFullPrefix = FullPrefix(NewCodeFormat);
	
	CodeLength = StrLen(NewCodeFormat);
	
	BaseCode = DeleteLeadingZeros(BaseCode);
	
	LeadingZerosNumber = CodeLength - StrLen(NewFullPrefix) - StrLen(BaseCode);
	
	If LeadingZerosNumber < 0 Then
		
		MessageString = NStr("en = 'Unable to perform the %1 transformation on the %2 object.
							|Insufficient length %1. Minimum length of the %1 object should not be less than %3 characters.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
					?(IsDocument, NStr("en = 'numbers'"), NStr("en = 'code'")),
					String(Object),
					String(StrLen(NewFullPrefix) + StrLen(BaseCode)));
		Raise MessageString;
	EndIf;
	
	ZeroLine = Left("00000000000000000000000000000000000000000000000000", LeadingZerosNumber);
	
	Return NewFullPrefix + ZeroLine + BaseCode;
EndFunction

Function ObjectNumericCode(Val Code)
	
	Result = "";
	
	While StrLen(Code) > 0 Do
		
		Char = Right(Code, 1);
		
		If Find("0123456789", Char) > 0 Then
			Result = Char + Result;
		Else
			Break;
		EndIf;
		
		Code = Left(Code, StrLen(Code) - 1);
		
	EndDo;
	
	Return ?(IsBlankString(Result), 0, Number(Result));
EndFunction

Function FullPrefix(Val Code)
	
	While StrLen(Code) > 0 Do
		
		Char = Right(Code, 1);
		
		If Find("0123456789", Char) = 0 Then
			Break;
		EndIf;
		
		Code = Left(Code, StrLen(Code) - 1);
		
	EndDo;
	
	Return Code;
EndFunction

Function EventSubscriptionsByHandlerName(Val HandlerName)
	
	Result = New Array;
	
	UpperHandlerName = Upper(HandlerName);
	
	For Each MetadataObject In Metadata.EventSubscriptions Do
		
		If Upper(MetadataObject.Handler) = UpperHandlerName Then
			
			Result.Add(MetadataObject);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function DeleteLeadingZeros(Val Code)
	
	While StrLen(Code) > 0 Do
		
		If Left(Code, 1) <> "0" Then
			Break;
		EndIf;
		
		Code = Right(Code, StrLen(Code) - 1);
		
	EndDo;
	
	Return ?(IsBlankString(Code), "0", Code);
EndFunction

Procedure CompleteMetadataTable(Result, Val HandlerName)
	
	DataSeparationEnabled = CommonUseCached.DataSeparationEnabled();
	
	For Each Subscription In EventSubscriptionsByHandlerName(HandlerName) Do
		
		For Each SourceType In Subscription.Source.Types() Do
			
			SourceMetadata = Metadata.FindByType(SourceType);
			
			ObjectName = SourceMetadata.FullName();
			
			If Result.Find(ObjectName, "ObjectName") <> Undefined Then
				
				Continue;
				
			ElsIf DataSeparationEnabled Then
					
				If Not CommonUseCached.IsSeparatedMetadataObject(ObjectName, CommonUseCached.AuxiliaryDataSeparator())
					And Not CommonUseCached.IsSeparatedMetadataObject(ObjectName, CommonUseCached.MainDataSeparator())Then
					
					Continue;
					
				EndIf;
				
			EndIf;
			
			Catalog                    = False;
			ChartOfCharacteristicTypes = False;
			Document                   = False;
			BusinessProcess            = False;
			Task                       = False;
			
			If CommonUse.IsCatalog(SourceMetadata) Then
				
				Catalog = True;
				
			ElsIf CommonUse.IsDocument(SourceMetadata) Then
				
				Document = True;
				
			ElsIf CommonUse.IsChartOfCharacteristicTypes(SourceMetadata) Then
				
				ChartOfCharacteristicTypes = True;
				
			ElsIf CommonUse.IsBusinessProcess(SourceMetadata) Then
				
				BusinessProcess = True;
				
			ElsIf CommonUse.IsTask(SourceMetadata) Then
				
				Task = True;
				
			Else
				Continue;
			EndIf;
			
			IsCatalog = Catalog Or ChartOfCharacteristicTypes;
			IsDocument = Document Or BusinessProcess Or Task;
			
			ObjectDescription = Result.Add();
			ObjectDescription.Name = SourceMetadata.Name;
			ObjectDescription.ObjectName = ObjectName;
			
			ObjectDescription.Catalog                    = Catalog;
			ObjectDescription.ChartOfCharacteristicTypes = ChartOfCharacteristicTypes;
			ObjectDescription.Document                   = Document;
			ObjectDescription.BusinessProcess            = BusinessProcess;
			ObjectDescription.Task                       = Task;
			
			ObjectDescription.IsCatalog = IsCatalog;
			ObjectDescription.IsDocument = IsDocument;
			
			ObjectDescription.NumberPeriodicity = ObjectNumberPeriodicity(SourceMetadata, Document, BusinessProcess);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure IncreaseProcessedObjectsCounter(ProcessedObjectsCounter)
	
	ProcessedObjectsCounter = ProcessedObjectsCounter + 1;
	
EndProcedure

Procedure SupplementStringWithZerosFromLeft(String, StringLength)
	
	String = StringFunctionsClientServer.SupplementString(String, StringLength, "0", "Left");
	
EndProcedure

//

Function InfobasePrefixUsingMetadata()
	
	Result = New ValueTable;
	Result.Columns.Add("Name");
	Result.Columns.Add("ObjectName");
	Result.Columns.Add("IsCatalog");
	Result.Columns.Add("IsDocument");
	Result.Columns.Add("Catalog");
	Result.Columns.Add("ChartOfCharacteristicTypes");
	Result.Columns.Add("Document");
	Result.Columns.Add("BusinessProcess");
	Result.Columns.Add("Task");
	Result.Columns.Add("NumberPeriodicity");
	
	CompleteMetadataTable(Result, "ObjectPrefixationEvents.SetInfobasePrefix");
	CompleteMetadataTable(Result, "ObjectPrefixationEvents.SetInfobaseAndCompanyPrefix");
	
	Return Result;
EndFunction

Function InfobasePrefixAndCompanyPrefixUsingMetadata()
	
	Result = New ValueTable;
	Result.Columns.Add("Name");
	Result.Columns.Add("ObjectName");
	Result.Columns.Add("IsCatalog");
	Result.Columns.Add("IsDocument");
	Result.Columns.Add("Catalog");
	Result.Columns.Add("ChartOfCharacteristicTypes");
	Result.Columns.Add("Document");
	Result.Columns.Add("BusinessProcess");
	Result.Columns.Add("Task");
	Result.Columns.Add("NumberPeriodicity");
	
	CompleteMetadataTable(Result, "ObjectPrefixationEvents.SetInfobaseAndCompanyPrefix");
	
	Return Result;
EndFunction

Function OnlyInfobasePrefixUsingMetadata()
	
	Result = New ValueTable;
	Result.Columns.Add("Name");
	Result.Columns.Add("ObjectName");
	Result.Columns.Add("IsCatalog");
	Result.Columns.Add("IsDocument");
	Result.Columns.Add("Catalog");
	Result.Columns.Add("ChartOfCharacteristicTypes");
	Result.Columns.Add("Document");
	Result.Columns.Add("BusinessProcess");
	Result.Columns.Add("Task");
	Result.Columns.Add("NumberPeriodicity");
	
	CompleteMetadataTable(Result, "ObjectPrefixationEvents.SetInfobasePrefix");
	
	Return Result;
EndFunction

Function CreateObject(ObjectDescription)
	
	If ObjectDescription.Catalog Then
		
		Return Catalogs[ObjectDescription.Name].CreateItem();
		
	ElsIf ObjectDescription.Document Then
		
		Return Documents[ObjectDescription.Name].CreateDocument();
		
	ElsIf ObjectDescription.ChartOfCharacteristicTypes Then
		
		Return ChartsOfCharacteristicTypes[ObjectDescription.Name].CreateItem();
		
	ElsIf ObjectDescription.BusinessProcess Then
		
		Return BusinessProcesses[ObjectDescription.Name].CreateBusinessProcess();
		
	ElsIf ObjectDescription.Task Then
		
		Return Tasks[ObjectDescription.Name].CreateTask();
		
	EndIf;
	
	Return Undefined;
EndFunction

Function ObjectNumberPeriodicity(Object, Val Document, Val BusinessProcess)
	
	Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical;
	
	If Document Then
		
		Result = Object.NumberPeriodicity;
		
	ElsIf BusinessProcess Then
		
		If Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Year Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Day Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Quarter Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Month Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month;
			
		ElsIf Object.NumberPeriodicity = Metadata.ObjectProperties.BusinessProcessNumberPeriodicity.Nonperiodical Then
			
			Result = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

Function PeriodDate(Val Date, Val Periodicity)
	
	If Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year Then
		
		Return BegOfYear(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter Then
		
		Return BegOfQuarter(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month Then
		
		Return BegOfMonth(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day Then
		
		Return BegOfDay(Date);
		
	ElsIf Periodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Nonperiodical Then
		
		Return Date('00010101');
		
	EndIf;
	
	Return Date('00010101');
EndFunction

Procedure SetNewPrefix(
						Val PrefixLength,
						Val ObjectName,
						Val FromDate,
						Val IsDocument,
						Val PreviousInfobasePrefix,
						Val ProcessAllData,
						Val NewFullPrefix,
						ProcessedObjectsCounter)
	
	Selection = DataSelection(
			ObjectName,
			FromDate,
			IsDocument,
			True,
			PreviousInfobasePrefix,
			ProcessAllData);
	
	If Selection.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Selection.Select();
	
	While Selection.Next() Do
		
		If PrefixLength = 2 Then
			
			If Mid(Selection.Code, 3, 1) <> "-" Then
				Continue; // Nonstandard code format
			EndIf;
			
			NewCode = NewFullPrefix + Mid(Selection.Code, 3);
			
		Else // PrefixLength = 4
			
			If Mid(Selection.Code, 5, 1) <> "-" Then
				Continue; // Nonstandard code format
			EndIf;
			
			NewCode = Left(Selection.Code, 2) + NewFullPrefix + Mid(Selection.Code, 5);
			
		EndIf;
		
		ObjectModified = (Selection.Code <> NewCode);
		
		If ObjectModified Then
			
			Object = Selection.Ref.GetObject();
			
			Object[?(IsDocument, "Number", "Code")] = NewCode;
			
			Object.DataExchange.Load = True;
			Object.Write();
			
			IncreaseProcessedObjectsCounter(ProcessedObjectsCounter);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ValidatePrefixInstallationPossibility()
	
	FunctionalOptionUsed = Undefined;
	OnFunctionalOptionDeterminationInfobasePrefix(FunctionalOptionUsed);
	If Not FunctionalOptionUsed Then
		
		Raise NStr("en='Object reprefixation is unavailable.'");
		
	EndIf;
	
EndProcedure

Function EventLogMessageTextObjectReprefixation()
	
	Return NStr("en = 'Object prefixation.Infobase prefix change'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// Returns the flat that there is the CompanyPrefixes functional option in the configuration.
//
// Parameters:
//  FunctionalOptionUsed - Boolean - flat that there is the CompanyPrefixes functional option 
//                                   in the configuration.
//
Procedure OnFunctionalOptionDeterminationCompanyPrefixes(FunctionalOptionUsed) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		FunctionalOptionUsed = True;
	Else
		FunctionalOptionUsed = False;
	EndIf;
	
EndProcedure

// Returns the flat that there is the InfobasePrefix functional option in the configuration.
//
// Parameters:
//  FunctionalOptionUsed - Boolean - flat that there is the InfobasePrefix functional option 
//                                   in the configuration.
//
Procedure OnFunctionalOptionDeterminationInfobasePrefix(FunctionalOptionUsed) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		FunctionalOptionUsed = True;
	Else
		FunctionalOptionUsed = False;
	EndIf;
	
EndProcedure

// Returns the infobase prefix
//
Procedure OnInfobasePrefixDefinition(InfobasePrefix) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		DataExchangeServerModule = CommonUse.CommonModule("DataExchangeServer");
		InfobasePrefix = DataExchangeServerModule.InfobasePrefix();
	Else
		InfobasePrefix = "";
	EndIf;
	
EndProcedure

// Returns company prefix
//
// Parameters:
//  Company       - CatalogRef.Companies - company for which to get a prefix.
//  CompanyPrefix - String               - company prefix.
//
Procedure OnCompanyPrefixIdentification(Val Company, CompanyPrefix) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
		FunctionalOptionName = "CompanyPrefixes";
		CompanyPrefix = GetFunctionalOption(FunctionalOptionName, New Structure("Company", Company));
	Else
		CompanyPrefix = "";
	EndIf;
	
EndProcedure

// Sets up the infobase prefix
//
Procedure SetInfobasePrefix(Val Prefix) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		DataExchangeServerModule = CommonUse.CommonModule("DataExchangeServer");
		DataExchangeServerModule.SetInfobasePrefix(Prefix);
	EndIf;
	
EndProcedure

#EndRegion
