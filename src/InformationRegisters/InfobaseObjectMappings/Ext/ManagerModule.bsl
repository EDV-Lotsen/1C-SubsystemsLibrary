#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "InfobaseObjectMappings", Import);
	
EndProcedure

// Deletes a record set from the register by the passed structure values.
Procedure DeleteRecord(RecordStructure, Import = False) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "InfobaseObjectMappings", Import);
	
EndProcedure

Function ObjectIsInRegister(Object, InfobaseNode) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.InfobaseObjectMappings AS InfobaseObjectMappings
	|WHERE
	|	  InfobaseObjectMappings.InfobaseNode = &InfobaseNode
	|	AND InfobaseObjectMappings.SourceUUID = &SourceUUID
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("SourceUUID",   Object);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure DeleteObsoleteExportByRefModeRecords(InfobaseNode) Export
	
	QueryText = "
	|////////////////////////////////////////////////////////// {InfobaseObjectMapsByRef}
	|SELECT
	|	InfobaseObjectMappings.InfobaseNode,
	|	InfobaseObjectMappings.SourceUUID,
	|	InfobaseObjectMappings.TargetUUID,
	|	InfobaseObjectMappings.TargetType,
	|	InfobaseObjectMappings.SourceType
	|INTO InfobaseObjectMapsByRef
	|FROM
	|	InformationRegister.InfobaseObjectMappings AS InfobaseObjectMappings
	|WHERE
	|	  InfobaseObjectMappings.InfobaseNode = &InfobaseNode
	|	AND InfobaseObjectMappings.ObjectExportedByRef
	|;
	|
	|//////////////////////////////////////////////////////////{}
	|SELECT DISTINCT
	|	InfobaseObjectMapsByRef.InfobaseNode,
	|	InfobaseObjectMapsByRef.SourceUUID,
	|	InfobaseObjectMapsByRef.TargetUUID,
	|	InfobaseObjectMapsByRef.TargetType,
	|	InfobaseObjectMapsByRef.SourceType
	|FROM
	|	InfobaseObjectMapsByRef AS InfobaseObjectMapsByRef
	|LEFT JOIN InformationRegister.InfobaseObjectMappings AS InfobaseObjectMappings
	|ON   InfobaseObjectMappings.SourceUUID = InfobaseObjectMapsByRef.SourceUUID
	|	AND InfobaseObjectMappings.ObjectExportedByRef = False
	|	AND InfobaseObjectMappings.InfobaseNode = &InfobaseNode
	|WHERE
	|	Not InfobaseObjectMappings.InfobaseNode IS NULL
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			RecordStructure = New Structure("InfobaseNode, SourceUUID, TargetUUID, TargetType, SourceType");
			
			FillPropertyValues(RecordStructure, Selection);
			
			DeleteRecord(RecordStructure, True);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure AddObjectToAllowedObjectFilter (Val Object, Val Recipient) Export
	
	If Not ObjectIsInRegister(Object, Recipient) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Recipient);
		RecordStructure.Insert("SourceUUID", Object);
		RecordStructure.Insert("ObjectExportedByRef", True);
		
		AddRecord(RecordStructure, True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf