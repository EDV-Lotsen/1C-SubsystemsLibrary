////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns marked for deletion objects. Filter is possible.
//
Function GetMarkedForDeletion() Export
	
	SetPrivilegedMode(True);
	MarkedArray = FindMarkedForDeletion();
	SetPrivilegedMode(False);
	
	Result = New Array;
	For Each MarkedItem In MarkedArray Do
		If AccessRight("InteractiveDeleteMarked", MarkedItem.Metadata()) Then
			Result.Add(MarkedItem);
		EndIf
	EndDo;
	
	Return Result;
	
EndFunction

// Initializes a type table of objects to be deleted.
//
// Returns:
//	ValueTable - type table.
//
Function GetObjectsToDeleteTypeTable()
	
	ObjectsToDeleteTypes = New ValueTable;
	ObjectsToDeleteTypes.Columns.Add("Type", New TypeDescription("Type"));
	
	Return ObjectsToDeleteTypes;
	
EndFunction

// Updates the type table of objects to be deleted.
//
// Parameters:
//	Table - ValueTable - type table;
//	ObjectsToDelete - Array - array of objects to be deleted.
//
Procedure RefreshObjectsToDeleteTable(Table, Val ObjectsToDelete)
	
	For Each ObjectToDelete In ObjectsToDelete Do
		NewType = Table.Add();
		NewType.Type = TypeOf(ObjectToDelete);
	EndDo;
	
	Table.GroupBy("Type");
	
EndProcedure

// Returns a structure with State and Value fields by the passed parameters.
//
// Returns:
//	Structure - Operation state structure.
//
Function PackActionState(Val Value, Val State = True)
	
	Return New Structure("State, Value", State, Value);
	
EndFunction

// Gets the marked for deletion object array.
//
// Parameters:
//	MarkedForDeletionList - ValueTree - marked for deletion object tree;
//	DeletionMode - String - deletion mode .
// 
// Returns:
//	Array - marked for deletion object array.
//
Function GetMarkedForDeletionObjectArray(MarkedForDeletionList, DeletionMode)
	
	ToDelete = New Array;
	
	If DeletionMode = "Full" Then
		// In full mode getting the whole marked for deletion list
		ToDelete = GetMarkedForDeletion();
	Else
		// Filling array by marked for deletion item references
		MetadataRowCollection = MarkedForDeletionList.GetItems();
		For Each MetadataObjectRow In MetadataRowCollection Do
			RefRowCollection = MetadataObjectRow.GetItems();
			For Each RefRow In RefRowCollection Do
				If RefRow.Check Then
					ToDelete.Add(RefRow.Value);
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	Return ToDelete;

EndFunction	

// Executes object deletion action.
//
// Parameters:
//	DeletionParameters - Structure - required for deletion parameters.
//	StorageAddress - String - internal storage address.
//
Procedure DeleteMarkedObjects(DeletionParameters, StorageAddress) Export
	
	// Extracting parameters
	MarkedForDeletionList	= DeletionParameters.MarkedForDeletionList;
	DeletionMode				= DeletionParameters.DeletionMode;
	DeletedObjectTypes		= DeletionParameters.DeletedObjectTypes;
	
	ToDelete = GetMarkedForDeletionObjectArray(MarkedForDeletionList, DeletionMode);
	ToDeleteCount = ToDelete.Count();
	
	// Executing deletion
	Result = ExecuteDelete(ToDelete, DeletedObjectTypes);
	
	// Adding parameters 
	If TypeOf(Result.Value) = Type("Structure") Then 
		NotDeletedObjectCount = Result.Value.NotDeleted.Count();
	Else	
		NotDeletedObjectCount = 0;
	EndIf;	
	Result.Insert("NotDeletedObjectCount", NotDeletedObjectCount);
	Result.Insert("ToDeleteCount",			ToDeleteCount);
	Result.Insert("DeletedObjectTypes",			DeletedObjectTypes);
	
	PutToTempStorage(Result, StorageAddress);

EndProcedure

// Executes object deletion.
//
// Parameters:
//	ToDelete - Array - Marked for deletion item array.
//	DeletedObjectTypeArray - Array - deleted object type array. 
//
// Returns:
//	Structure - structure with a deletion result.
//
Function ExecuteDelete(Val ToDelete, DeletedObjectTypeArray) 
	
	If Not Users.InfoBaseUserWithFullAccess() Then
		Raise NStr("en = 'Insufficient rights to execute the action.'");
	EndIf;
	
	Try
		CommonUse.LockInfoBase();
	Except
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Failed to set exclusive access to the Infobase (%1)'"),
			BriefErrorDescription(ErrorInfo()));
		Return PackActionState(Message, False);
	EndTry;
	
	DeletedObjectTypes = GetObjectsToDeleteTypeTable();
	RefreshObjectsToDeleteTable(DeletedObjectTypes, ToDelete);
	
	Found = New ValueTable;
	NotDeleted = New Array;
	
	Found.Columns.Add("Ref");
	Found.Columns.Add("Data");
	Found.Columns.Add("Metadata");
	
	ObjectsToDelete = New Array;
	For Each ObjectRef In ToDelete Do
		ObjectsToDelete.Add(ObjectRef);
	EndDo;
	
	RefSearchExclusions = CommonUse.GetOverallRefSearchExceptionList();
	RegisterDimensions = New Map;
	ObjectMasterDimensions = New Map;
	RecordSets = New Map;

	While ObjectsToDelete.Count() > 0 Do
		FoundData = New ValueTable;
		
		// Trying of delete with reference integrity check.
		Try
			SetPrivilegedMode(True);
			DeleteObjects(ObjectsToDelete, True, FoundData);
			SetPrivilegedMode(False);
		Except
			ErrorMessage = DetailErrorDescription(ErrorInfo());
			SetExclusiveMode(False);
			Return PackActionState(ErrorMessage, False);
		EndTry;
		
		ObjectsToDeleteCount = ObjectsToDelete.Count();
		
		// Moving objects to delete in not deleted list
		// and adding them in found dependent object list
		// taking into account the reference search exception list.
		For Each TableRow In FoundData Do
			
			DependentObjectFullName = TableRow.Metadata.FullName();
			
			// Continue if the found dependent object is in exception list.
			If RefSearchExclusions.Find(DependentObjectFullName) <> Undefined Then
				Continue;
			EndIf;
			
			// If the dependent object that is found is a register record and the object being 
			// deleted is in the master register dimension (the Master flag is selected for 
			//the dimension), then execute the Continue operator. 
			
			MasterDimensions = ObjectMasterDimensions[DependentObjectFullName];
			If MasterDimensions = Undefined Then
				// Filling dimensions.
				MasterDimensions = New Map;
				ObjectMasterDimensions.Insert(DependentObjectFullName, MasterDimensions);
				
				If CommonUse.IsRegister(TableRow.Metadata) Then
					Dimensions = New Array;
					RegisterDimensions.Insert(DependentObjectFullName, Dimensions);
					If CommonUse.IsInformationRegister(TableRow.Metadata) Then
						For Each Dimension In TableRow.Metadata.Dimensions Do
							If Dimension.Master Then
								MasterDimensions.Insert(Dimension.Name, True);
							EndIf;
							Dimensions.Add(Dimension.Name);
						EndDo;
					Else
						For Each Dimension In TableRow.Metadata.Dimensions Do
							MasterDimensions.Insert(Dimension.Name, True);
							Dimensions.Add(Dimension.Name);
						EndDo;
					EndIf;
					RecordSet = CommonUse.ObjectManagerByFullName(
						DependentObjectFullName).CreateRecordSet();
					RecordSets.Insert(DependentObjectFullName, RecordSet);
				EndIf;
			EndIf;
			
			If MasterDimensions.Count() > 0 Then
				ObjectToDeleteInMasterDimensionsOnly = True;
				RegisterDimensions = RegisterDimensions[DependentObjectFullName];
				RecordSet = RecordSets[DependentObjectFullName];
				For Each Dimension In RegisterDimensions Do
					RecordSet.Filter[Dimension].Set(TableRow.Data[Dimension]);
				EndDo;
				RecordSet.Read();
				If RecordSet.Count() > 0 Then
					RecordTable = RecordSet.Unload();
					Record = RecordTable[0];
					For Each Column In RecordTable.Columns Do
						
						If Record[Column.Name] = TableRow.Ref
						 And MasterDimensions[Column.Name] = Undefined Then
							
							ObjectToDeleteInMasterDimensionsOnly = False;
							Break;
						EndIf;
					EndDo;
				EndIf;
				If ObjectToDeleteInMasterDimensionsOnly Then
					Continue;
				EndIf;
			EndIf;
			
			// Reduction of the ObjectsToDelete list.
			Index = ObjectsToDelete.Find(TableRow.Ref);
			If Index <> Undefined Then
				ObjectsToDelete.Delete(Index);
			EndIf;
			
			// Adding the NotDeleted list.
			If NotDeleted.Find(TableRow.Ref) = Undefined Then
				NotDeleted.Add(TableRow.Ref);
			EndIf;
			
			// Adding found dependent objects.
			NewRow = Found.Add();
			FillPropertyValues(NewRow, TableRow);
			
		EndDo;
		
		// It is possible to delete without check if the composition of objects that being deleted was non changed in this loop iteration.
		If ObjectsToDeleteCount = ObjectsToDelete.Count() Then
			Try
				// Deletion without reference integrity check.
				DeleteObjects(ObjectsToDelete, False);
			Except
				ErrorMessage = DetailErrorDescription(ErrorInfo());
				SetExclusiveMode(False);
				Return PackActionState(ErrorMessage, False);
			EndTry;
			
			// Terminating the loop because everything that possible was deleted.
			Break;
		EndIf;
	EndDo;
	
	For Each NotDeletedObject In NotDeleted Do
		FoundRows = DeletedObjectTypes.FindRows(New Structure("Type", TypeOf(NotDeletedObject)));
		If FoundRows.Count() > 0 Then
			DeletedObjectTypes.Delete(FoundRows[0]);
		EndIf;
	EndDo;
	
	DeletedObjectTypeArray = DeletedObjectTypes.UnloadColumn("Type");
	
	CommonUse.UnlockInfoBase();
	
	Return PackActionState(New Structure("Found, NotDeleted", Found, NotDeleted));
	
EndFunction