
////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds the record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "CommonInfoBaseNodeSettings");
	
EndProcedure

// Updates the record in the register by the passed structure values.
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "CommonInfoBaseNodeSettings");
	
EndProcedure

Procedure SetInitialDataExportFlag(InfoBaseNode) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfoBaseNode", InfoBaseNode);
	RecordStructure.Insert("InitialDataExport", True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure ClearInitialDataExportFlag(InfoBaseNode, ReceivedNo) Export
	
	If ReceivedNo <> 0 Then // first message was accepted in the correspondent base and the flag can be cleared
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfoBaseNode", InfoBaseNode);
		RecordStructure.Insert("InitialDataExport", False);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function InitialDataExportFlagIsSet(InfoBaseNode) Export
	
	QueryText =
	"SELECT
	|	1 AS Field1
	|FROM
	|	InformationRegister.CommonInfoBaseNodeSettings AS CommonInfoBaseNodeSettings
	|WHERE
	|	CommonInfoBaseNodeSettings.InfoBaseNode = &InfoBaseNode
	|	AND CommonInfoBaseNodeSettings.InitialDataExport";
	
	Query = New Query;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Procedure CommitMappingInfoAdjustmentUnconditionally(InfoBaseNode) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfoBaseNode", InfoBaseNode);
	RecordStructure.Insert("ExecuteMappingInfoAdjustment", False);
	
	AddRecord(RecordStructure);
	
EndProcedure

Procedure CommitMappingInfoAdjustment(InfoBaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.CommonInfoBaseNodeSettings AS CommonInfoBaseNodeSettings
	|WHERE
	|	CommonInfoBaseNodeSettings.InfoBaseNode = &InfoBaseNode
	|	AND CommonInfoBaseNodeSettings.ExecuteMappingInfoAdjustment
	|	AND CommonInfoBaseNodeSettings.SentNo <= &SentNo
	|	AND CommonInfoBaseNodeSettings.SentNo <> 0
	|";
	
	Query = New Query;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	Query.SetParameter("SentNo", SentNo);
	Query.Text = QueryText;
	
	If Not Query.Execute().IsEmpty() Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfoBaseNode", InfoBaseNode);
		RecordStructure.Insert("ExecuteMappingInfoAdjustment", False);
		
		AddRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Procedure SetMappingDataAdjustmentRequiredForAllInfoBaseNodes() Export
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	For Each Item In ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Metadata.ExchangePlans[ExchangePlanName].DistributedInfoBase Then
			Continue;
		EndIf;
		
		NodeArray = DataExchangeCached.GetExchangePlanNodeArray(ExchangePlanName);
		
		For Each Node In NodeArray Do
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfoBaseNode", Node);
			RecordStructure.Insert("ExecuteMappingInfoAdjustment", True);
			
			AddRecord(RecordStructure);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function MustAdjustMappingInfo(InfoBaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.CommonInfoBaseNodeSettings AS CommonInfoBaseNodeSettings
	|WHERE
	|	  CommonInfoBaseNodeSettings.InfoBaseNode = &InfoBaseNode
	|	AND CommonInfoBaseNodeSettings.ExecuteMappingInfoAdjustment
	|";
	
	Query = New Query;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	Query.Text = QueryText;
	
	Result = Not Query.Execute().IsEmpty();
	
	If Result Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfoBaseNode", InfoBaseNode);
		RecordStructure.Insert("ExecuteMappingInfoAdjustment", True);
		RecordStructure.Insert("SentNo", SentNo);
		
		AddRecord(RecordStructure);
		
	EndIf;
	
	Return Result;
EndFunction
