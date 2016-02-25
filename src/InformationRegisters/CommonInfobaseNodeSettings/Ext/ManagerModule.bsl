#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// You can modify records of this information register only using the record manager.
// This ensures the update of existing register records.
// You cannot add records to this register using record sets
// because all records that are not included in the record sets will be lost.

#Region InternalProceduresAndFunctions

Procedure SetInitialDataExportFlag(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert("InitialDataExport", True);
	RecordStructure.Insert("SentNoInitialDataExport",
		CommonUse.ObjectAttributeValue(InfobaseNode, "SentNo") + 1);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure ClearInitialDataExportFlag(Val InfobaseNode, Val ReceivedNo) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.CommonInfobaseNodeSettings");
		LockItem.SetValue("InfobaseNode", InfobaseNode);
		DataLock.Lock();
		
		QueryText = "
		|SELECT 1
		|FROM
		|	InformationRegister.CommonInfobaseNodeSettings AS CommonInfobaseNodeSettings
		|WHERE
		|	CommonInfobaseNodeSettings.InfobaseNode = &InfobaseNode
		|	AND CommonInfobaseNodeSettings.InitialDataExport
		|	AND CommonInfobaseNodeSettings.SentNoInitialDataExport <= &ReceivedNo
		|	AND CommonInfobaseNodeSettings.SentNoInitialDataExport <> 0
		|";
		
		Query = New Query;
		Query.SetParameter("InfobaseNode", InfobaseNode);
		Query.SetParameter("ReceivedNo", ReceivedNo);
		Query.Text = QueryText;
		
		If Not Query.Execute().IsEmpty() Then
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", InfobaseNode);
			RecordStructure.Insert("InitialDataExport", False);
			RecordStructure.Insert("SentNoInitialDataExport", 0);
			
			UpdateRecord(RecordStructure);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function InitialDataExportFlagIsSet(Val InfobaseNode) Export
	
	QueryText =
	"SELECT
	|	1 AS Field1
	|FROM
	|	InformationRegister.CommonInfobaseNodeSettings AS CommonInfobaseNodeSettings
	|WHERE
	|	CommonInfobaseNodeSettings.InfobaseNode = &InfobaseNode
	|	AND CommonInfobaseNodeSettings.InitialDataExport";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction
 

Procedure CommitMappingInfoAdjustmentUnconditionally(InfobaseNode) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", InfobaseNode);
	RecordStructure.Insert("ExecuteMappingInfoAdjustment", False);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure CommitMappingInfoAdjustment(InfobaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.CommonInfobaseNodeSettings AS CommonInfobaseNodeSettings
	|WHERE
	|	CommonInfobaseNodeSettings.InfobaseNode = &InfobaseNode
	|	AND CommonInfobaseNodeSettings.ExecuteMappingInfoAdjustment
	|	AND CommonInfobaseNodeSettings.SentNo <= &SentNo
	|	AND CommonInfobaseNodeSettings.SentNo <> 0
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.SetParameter("SentNo", SentNo);
	Query.Text = QueryText;
	
	If Not Query.Execute().IsEmpty() Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", InfobaseNode);
		RecordStructure.Insert("ExecuteMappingInfoAdjustment", False);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Procedure SetMappingDataAdjustmentRequiredForAllInfobaseNodes() Export
	
	ExchangePlanList = DataExchangeCached.SLExchangePlanList();
	
	For Each Item In ExchangePlanList Do
		
		ExchangePlanName = Item.Value;
		
		If Metadata.ExchangePlans[ExchangePlanName].DistributedInfobase Then
			Continue;
		EndIf;
		
		NodeArray = DataExchangeCached.GetExchangePlanNodeArray(ExchangePlanName);
		
		For Each Node In NodeArray Do
			
			RecordStructure = New Structure;
			RecordStructure.Insert("InfobaseNode", Node);
			RecordStructure.Insert("ExecuteMappingInfoAdjustment", True);
			
			UpdateRecord(RecordStructure);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function MustAdjustMappingInfo(InfobaseNode, SentNo) Export
	
	QueryText = "
	|SELECT 1
	|FROM
	|	InformationRegister.CommonInfobaseNodeSettings AS CommonInfobaseNodeSettings
	|WHERE
	|	  CommonInfobaseNodeSettings.InfobaseNode = &InfobaseNode
	|	AND CommonInfobaseNodeSettings.ExecuteMappingInfoAdjustment
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Result = Not Query.Execute().IsEmpty();
	
	If Result Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", InfobaseNode);
		RecordStructure.Insert("ExecuteMappingInfoAdjustment", True);
		RecordStructure.Insert("SentNo", SentNo);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
	Return Result;
EndFunction

Function UserForDataSynchronization(Val InfobaseNode) Export
	
	QueryText =
	"SELECT
	|	CommonInfobaseNodeSettings.UserForDataSynchronization AS UserForDataSynchronization
	|FROM
	|	InformationRegister.CommonInfobaseNodeSettings AS CommonInfobaseNodeSettings
	|WHERE
	|	CommonInfobaseNodeSettings.InfobaseNode = &InfobaseNode";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		
		Selection.Next();
		
		Return ?(ValueIsFilled(Selection.UserForDataSynchronization), Selection.UserForDataSynchronization, Undefined);
		
	EndIf;
	
	Return Undefined;
EndFunction


Procedure SetDataSendingFlag(Val Target) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	RecordStructure = New Structure;
	RecordStructure.Insert("InfobaseNode", Target);
	RecordStructure.Insert("ExecuteDataSending", True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

Procedure ClearDataSendingFlag(Val Target) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	If ExecuteDataSending(Target) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Target);
		RecordStructure.Insert("ExecuteDataSending", False);
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function ExecuteDataSending(Val Target) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return False;
	EndIf;
	
	QueryText =
	"SELECT
	|	CommonInfobaseNodeSettings.ExecuteDataSending AS ExecuteDataSending
	|FROM
	|	InformationRegister.CommonInfobaseNodeSettings AS CommonInfobaseNodeSettings
	|WHERE
	|	CommonInfobaseNodeSettings.InfobaseNode = &Target";
	
	Query = New Query;
	Query.SetParameter("Target", Target);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.ExecuteDataSending = True;
EndFunction


Procedure SetCorrespondentVersion(Val Correspondent, Val Version) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	If IsBlankString(Version) Then
		Version = "0.0.0.0";
	EndIf;
	
	If CorrespondentVersion(Correspondent) <> TrimAll(Version) Then
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode", Correspondent);
		RecordStructure.Insert("CorrespondentVersion", TrimAll(Version));
		
		UpdateRecord(RecordStructure);
		
	EndIf;
	
EndProcedure

Function CorrespondentVersion(Val Correspondent) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return "0.0.0.0";
	EndIf;
	
	QueryText =
	"SELECT
	|	CommonInfobaseNodeSettings.CorrespondentVersion AS CorrespondentVersion
	|FROM
	|	InformationRegister.CommonInfobaseNodeSettings AS CommonInfobaseNodeSettings
	|WHERE
	|	CommonInfobaseNodeSettings.InfobaseNode = &Correspondent";
	
	Query = New Query;
	Query.SetParameter("Correspondent", Correspondent);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return "0.0.0.0";
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Result = TrimAll(Selection.CorrespondentVersion);
	
	If IsBlankString(Result) Then
		Result = "0.0.0.0";
	EndIf;
	
	Return Result;
EndFunction


// Updates a register record based on the passed structure values.
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "CommonInfobaseNodeSettings");
	
EndProcedure

#EndRegion

#EndIf
