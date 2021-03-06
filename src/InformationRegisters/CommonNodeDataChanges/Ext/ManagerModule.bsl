﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

Function SelectChanges(Val Node, Val MessageNo) Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Selection of data changes in an active transaction is not allowed.'");
	EndIf;
	
	Result = New Array;
	
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Node", Node);
		DataLock.Lock();
		
		QueryText =
		"SELECT
		|	CommonNodeDataChanges.Node AS Node,
		|	CommonNodeDataChanges.MessageNo AS MessageNo
		|FROM
		|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
		|WHERE
		|	CommonNodeDataChanges.Node = &Node";
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Result.Add(Selection.Node);
			
			If Selection.MessageNo = 0 Then
				
				RecordStructure = New Structure;
				RecordStructure.Insert("Node", Node);
				RecordStructure.Insert("MessageNo", MessageNo);
				AddRecord(RecordStructure);
				
			EndIf;
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
EndFunction

Procedure RecordChanges(Val Node) Export
	
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Node", Node);
		DataLock.Lock();
		
		RecordStructure = New Structure;
		RecordStructure.Insert("Node", Node);
		RecordStructure.Insert("MessageNo", 0);
		AddRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteChangeRecords(Val Node, Val MessageNo = Undefined) Export
	
	If TransactionActive() Then
		Raise NStr("en = 'Deletion of data change registration in an active transaction is not allowed.'");
	EndIf;
	
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.CommonNodeDataChanges");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Node", Node);
		DataLock.Lock();
		
		If MessageNo = Undefined Then
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
			|WHERE
			|	CommonNodeDataChanges.Node = &Node";
			
		Else
			
			QueryText =
			"SELECT
			|	1 AS Field1
			|FROM
			|	InformationRegister.CommonNodeDataChanges AS CommonNodeDataChanges
			|WHERE
			|	CommonNodeDataChanges.Node = &Node
			|	AND CommonNodeDataChanges.MessageNo <= &MessageNo
			|	AND CommonNodeDataChanges.MessageNo <> 0";
			
		EndIf;
		
		Query = New Query;
		Query.SetParameter("Node", Node);
		Query.SetParameter("MessageNo", MessageNo);
		Query.Text = QueryText;
		
		If Not Query.Execute().IsEmpty() Then
			
			RecordStructure = New Structure;
			RecordStructure.Insert("Node", Node);
			DeleteRecord(RecordStructure);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure)
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "CommonNodeDataChanges");
	
EndProcedure

// Deletes a record set from the register by the passed structure values.
Procedure DeleteRecord(RecordStructure)
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "CommonNodeDataChanges");
	
EndProcedure

#EndRegion

#EndIf