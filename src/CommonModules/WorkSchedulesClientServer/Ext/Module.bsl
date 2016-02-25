////////////////////////////////////////////////////////////////////////////////
// Work schedules subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// The procedure shifts the edited collection row
// in such a way so as to preserve the order of the collection rows
// 
// Parameters
// RowCollection  - row array, form data collection, value table
// OrderField     - collection item field name that is used to order
// CurrentRow     - the edited collection row
//
Procedure RestoreCollectionRowOrderAfterEditing(RowCollection, OrderField, CurrentRow) Export
	
	If RowCollection.Count() < 2 Then
		Return;
	EndIf;
	
	If TypeOf(CurrentRow[OrderField]) <> Type("Date") 
		And Not ValueIsFilled(CurrentRow[OrderField]) Then
		Return;
	EndIf;
	
	SourceIndex = RowCollection.IndexOf(CurrentRow);
	IndexResult = SourceIndex;
	
	// select the direction in which to shift
	Heading = 0;
	If SourceIndex = 0 Then
		// down
		Heading = 1;
	EndIf;
	If SourceIndex = RowCollection.Count() - 1 Then
		// up
		Heading = -1;
	EndIf;
	
	If Heading = 0 Then
		If RowCollection[SourceIndex][OrderField] > RowCollection[IndexResult + 1][OrderField] Then
			// down
			Heading = 1;
		EndIf;
		If RowCollection[SourceIndex][OrderField] < RowCollection[IndexResult - 1][OrderField] Then
			// up
			Heading = -1;
		EndIf;
	EndIf;
	
	If Heading = 0 Then
		Return;
	EndIf;
	
	If Heading = 1 Then
		// shift till the value in the current row is greater than in the following one
		While IndexResult < RowCollection.Count() - 1 
			And RowCollection[SourceIndex][OrderField] > RowCollection[IndexResult + 1][OrderField] Do
			IndexResult = IndexResult + 1;
		EndDo;
	Else
		// shift till the value in the current row is less than in the previous one
		While IndexResult > 0 
			And RowCollection[SourceIndex][OrderField] < RowCollection[IndexResult - 1][OrderField] Do
			IndexResult = IndexResult - 1;
		EndDo;
	EndIf;
	
	RowCollection.Move(SourceIndex, IndexResult - SourceIndex);
	
EndProcedure

// Regenerates a fixed map by inserting the specified value into it
//
Procedure InsertIntoFixedMap(FixedMap, Key, Value) Export
	
	Map = New Map(FixedMap);
	Map.Insert(Key, Value);
	FixedMap = New FixedMap(Map);
	
EndProcedure

// Uses the specified key to remove the fixed value map
//
Procedure DeleteFromFixedMap(FixedMap, Key) Export
	
	Map = New Map(FixedMap);
	Map.Delete(Key);
	FixedMap = New FixedMap(Map);
	
EndProcedure

#EndRegion
