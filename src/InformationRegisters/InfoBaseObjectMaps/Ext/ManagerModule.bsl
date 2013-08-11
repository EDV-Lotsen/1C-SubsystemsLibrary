////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds the record to the register by the passed structure values.
Procedure AddRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "InfoBaseObjectMaps", Import);
	
EndProcedure

// Deletes the record set from the register by the passed structure values.
Procedure DeleteRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "InfoBaseObjectMaps", Import);
	
EndProcedure

Function ObjectIsInRegister(Object, InfoBaseNode) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.InfoBaseObjectMaps AS InfoBaseObjectMaps
	|WHERE
	|	  InfoBaseObjectMaps.InfoBaseNode = &InfoBaseNode
	|	AND InfoBaseObjectMaps.SourceUUID = &SourceUUID
	|";
	
	Query = New Query;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	Query.SetParameter("SourceUUID",   Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure DeleteObsoleteUnloadByRefModeRecords(InfoBaseNode) Export
	
	QueryText = "
	|//////////////////////////////////////////////////////////{InfoBaseObjectMapsByRef}
	|SELECT
	|	InfoBaseObjectMaps.InfoBaseNode,
	|	InfoBaseObjectMaps.SourceUUID,
	|	InfoBaseObjectMaps.TargetUUID,
	|	InfoBaseObjectMaps.TargetType,
	|	InfoBaseObjectMaps.SourceType
	|INTO InfoBaseObjectMapsByRef
	|FROM
	|	InformationRegister.InfoBaseObjectMaps AS InfoBaseObjectMaps
	|WHERE
	|	  InfoBaseObjectMaps.InfoBaseNode = &InfoBaseNode
	|	AND InfoBaseObjectMaps.ObjectExportedByRef
	|;
	|
	|//////////////////////////////////////////////////////////{}
	|SELECT DISTINCT
	|	InfoBaseObjectMapsByRef.InfoBaseNode,
	|	InfoBaseObjectMapsByRef.SourceUUID,
	|	InfoBaseObjectMapsByRef.TargetUUID,
	|	InfoBaseObjectMapsByRef.TargetType,
	|	InfoBaseObjectMapsByRef.SourceType
	|FROM
	|	InfoBaseObjectMapsByRef AS InfoBaseObjectMapsByRef
	|LEFT JOIN InformationRegister.InfoBaseObjectMaps AS InfoBaseObjectMaps
	|ON InfoBaseObjectMaps.SourceUUID = InfoBaseObjectMapsByRef.SourceUUID
	|	AND InfoBaseObjectMaps.ObjectExportedByRef = False
	|	AND InfoBaseObjectMaps.InfoBaseNode = &InfoBaseNode
	|WHERE
	|	NOT InfoBaseObjectMaps.InfoBaseNode IS NULL
	|";
	
	Query = New Query;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Choose();
		
		While Selection.Next() Do
			
			RecordStructure = New Structure("InfoBaseNode, SourceUUID, TargetUUID, TargetType, SourceType");
			
			FillPropertyValues(RecordStructure, Selection);
			
			DeleteRecord(RecordStructure, True);
			
		EndDo;
		
	EndIf;
	
EndProcedure
