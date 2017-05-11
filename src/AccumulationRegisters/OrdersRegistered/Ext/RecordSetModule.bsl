﻿
////////////////////////////////////////////////////////////////////////////////
// Orders Registered: Recordset module
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
// RECORDSET EVENTS HANDLERS

Procedure BeforeWrite(Cancel, Replacing)
	
	// Skip checking for loaded datasets or overwritten data
	If DataExchange.Load Or Not _DemoDocumentPosting.WriteChangesOnly(AdditionalProperties) Then
		Return;
	EndIf;
	
	// Lock register, preventing other transactions to read data from register before changing
	LockForUpdate = True;

	// Save current state of register records before write of recordset
	_DemoDocumentPosting.CheckRecordsetChangesBeforeWrite(Filter.Recorder.Value, AdditionalProperties, Cancel);	
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	// Skip checking for loaded datasets or overwritten data
	If DataExchange.Load Or Not _DemoDocumentPosting.WriteChangesOnly(AdditionalProperties) Then
		Return;
	EndIf;
	
	// Save difference between old and new list of register records
	_DemoDocumentPosting.CheckRecordsetChangesOnWrite(Filter.Recorder.Value, AdditionalProperties, Cancel);	

EndProcedure
