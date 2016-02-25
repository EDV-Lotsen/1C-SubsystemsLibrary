#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region InternalProceduresAndFunctions

// Creates a message exchange session record and returns the session ID.
//
Function NewSession() Export
	
	Session = New UUID;
	
	RecordStructure = New Structure("Session, StartDate", Session, CurrentUniversalDate());
	
	AddRecord(RecordStructure);
	
	Return Session;
EndFunction

// Gets a session status: Running, Done, or Error.
//
Function SessionStatus(Val Session) Export
	
	Result = New Map;
	Result.Insert(0, "Running");
	Result.Insert(1, "Done");
	Result.Insert(2, "Error");
	
	QueryText =
	"SELECT
	|	CASE
	|		WHEN SystemMessageExchangeSessions.CompletedWithError
	|			THEN 2
	|		WHEN SystemMessageExchangeSessions.CompletedSuccessfully
	|			THEN 1
	|		ELSE 0
	|	END AS Result
	|FROM
	|	InformationRegister.SystemMessageExchangeSessions AS SystemMessageExchangeSessions
	|WHERE
	|	SystemMessageExchangeSessions.Session = &Session";
	
	Query = New Query;
	Query.SetParameter("Session", Session);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		MessageString = NStr("en = 'Message exchange system session with ID %1 not found.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Session));
		Raise MessageString;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Result[Selection.Result];
EndFunction

// Sets the CompletedSuccessfully flag value to True for a session that is
// passed to the procedure.
//
Procedure CommitSuccessfulSession(Val Session) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session",               Session);
	RecordStructure.Insert("CompletedSuccessfully", True);
	RecordStructure.Insert("CompletedWithError",    False);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

// Sets the CompletedWithError flag value to True for a session that is
// passed to the procedure.
//
Procedure CommitUnsuccessfulSession(Val Session) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session",               Session);
	RecordStructure.Insert("CompletedSuccessfully", False);
	RecordStructure.Insert("CompletedWithError",    True);
	
	UpdateRecord(RecordStructure);
	
EndProcedure

// Saves session data and sets the CompletedSuccessfully flag value to True.
//
Procedure SaveSessionData(Val Session, Data) Export
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Session", Session);
	RecordStructure.Insert("Data", Data);
	RecordStructure.Insert("CompletedSuccessfully", True);
	RecordStructure.Insert("CompletedWithError", False);
	UpdateRecord(RecordStructure);
	
EndProcedure

// Reads session data and deletes the session record from the infobase.
//
Function GetSessionData(Val Session) Export
	
	BeginTransaction();
	Try
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.SystemMessageExchangeSessions");
		LockItem.SetValue("Session", Session);
		DataLock.Lock();
		
		QueryText =
		"SELECT
		|	SystemMessageExchangeSessions.Data AS Data
		|FROM
		|	InformationRegister.SystemMessageExchangeSessions AS SystemMessageExchangeSessions
		|WHERE
		|	SystemMessageExchangeSessions.Session = &Session";
		
		Query = New Query;
		Query.SetParameter("Session", Session);
		Query.Text = QueryText;
		
		QueryResult = Query.Execute();
		
		If QueryResult.IsEmpty() Then
			MessageString = NStr("en = 'Message exchange system session with ID %1 not found.'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(Session));
			Raise MessageString;
		EndIf;
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		Result = Selection.Data;
		
		DeleteRecord(Session);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Result;
EndFunction

// Auxiliary procedures and functions

Procedure AddRecord(RecordStructure)
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "SystemMessageExchangeSessions");
	
EndProcedure

Procedure UpdateRecord(RecordStructure)
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "SystemMessageExchangeSessions");
	
EndProcedure

Procedure DeleteRecord(Val Session)
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(New Structure("Session", Session), "SystemMessageExchangeSessions");
	
EndProcedure

#EndRegion

#EndIf