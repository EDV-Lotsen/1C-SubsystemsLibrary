#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

Procedure ExecuteObjectMapping(Parameters, TempStorageAddress) Export
	
	PutToTempStorage(ObjectMappingResult(Parameters), TempStorageAddress);
	
EndProcedure

Function ObjectMappingResult(Parameters) Export
	
	ObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	DataExchangeServer.ImportObjectContext(Parameters.ObjectContext, ObjectMapping);
	
	Cancel = False;
	
	// Applying the table of unapproved mapping items to the database
	If Parameters.FormAttributes.UnapprovedRecordTableApplyOnly Then
		
		ObjectMapping.ApplyUnapprovedRecordTable(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Errors occurred during object mapping.'");
		EndIf;
		
		Return Undefined;
	EndIf;
	
	// Applying automatic object mapping result obtained by the user
	If Parameters.FormAttributes.ApplyAutomaticMappingResult Then
		
		// Adding rows to the table of unapproved mapping items
		For Each TableRow In Parameters.AutomaticallyMappedObjectTable Do
			
			FillPropertyValues(ObjectMapping.UnapprovedMappingTable.Add(), TableRow);
			
		EndDo;
		
	EndIf;
	
	// Applying the table of unapproved mapping items to the database
	If Parameters.FormAttributes.ApplyUnapprovedRecordTable Then
		
		ObjectMapping.ApplyUnapprovedRecordTable(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Errors occurred during object mapping.'");
		EndIf;
		
	EndIf;
	
	// Generating mapping table
	ObjectMapping.ExecuteObjectMapping(Cancel);
	
	If Cancel Then
		Raise NStr("en = 'Errors occurred during object mapping.'");
	EndIf;
	
	Result = New Structure;
	Result.Insert("ObjectCountInSource", ObjectMapping.ObjectCountInSource());
	Result.Insert("ObjectCountInTarget", ObjectMapping.ObjectCountInTarget());
	Result.Insert("MappedObjectCount",   ObjectMapping.MappedObjectCount());
	Result.Insert("UnmappedObjectCount", ObjectMapping.UnmappedObjectCount());
	Result.Insert("MappedObjectPercent", ObjectMapping.MappedObjectPercent());
	Result.Insert("MappingTable",        ObjectMapping.MappingTable());
	
	Result.Insert("ObjectContext", DataExchangeServer.GetObjectContext(ObjectMapping));
	
	Return Result;
EndFunction


Procedure ExecuteAutomaticObjectMapping(Parameters, TempStorageAddress) Export
	
	PutToTempStorage(AutomaticObjectMappingResult(Parameters), TempStorageAddress);
	
EndProcedure

Function AutomaticObjectMappingResult(Parameters) Export
	
	ObjectMapping = DataProcessors.InfobaseObjectMapping.Create();
	DataExchangeServer.ImportObjectContext(Parameters.ObjectContext, ObjectMapping);
	
	// Defining the UsedFieldList property
	ObjectMapping.UsedFieldList.Clear();
	CommonUseClientServer.FillPropertyCollection(Parameters.FormAttributes.UsedFieldList, ObjectMapping.UsedFieldList);
	
	// Defining the TableFieldList property
	ObjectMapping.TableFieldList.Clear();
	CommonUseClientServer.FillPropertyCollection(Parameters.FormAttributes.TableFieldList, ObjectMapping.TableFieldList);
	
	// Loading the table of unapproved mapping items
	ObjectMapping.UnapprovedMappingTable.Load(Parameters.UnapprovedMappingTable);
	
	Cancel = False;
	
	// Automatic object mapping
	ObjectMapping.ExecuteAutomaticObjectMapping(Cancel, Parameters.FormAttributes.MappingFieldList);
	
	If Cancel Then
		Raise NStr("en = 'Errors occurred during automatic object mapping.'");
	EndIf;
	
	Result = New Structure;
	Result.Insert("EmptyResult", ObjectMapping.AutomaticallyMappedObjectTable.Count() = 0);
	Result.Insert("ObjectContext", DataExchangeServer.GetObjectContext(ObjectMapping));
	
	Return Result;
EndFunction

#EndIf
