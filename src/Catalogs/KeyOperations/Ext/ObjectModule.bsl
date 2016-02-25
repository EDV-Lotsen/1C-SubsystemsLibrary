#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then


Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CheckPriority(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
EndProcedure

Procedure CheckPriority(Cancel)
	
	If AdditionalProperties.Property(PerformanceMonitorClientServer.DontCheckPriority()) Or Priority = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Priority", Priority);
	Query.SetParameter("Ref", Ref);
	Query.Text = 
	"SELECT TOP 1
	|	KeyOperations.Ref AS Ref,
	|	KeyOperations.Description AS Description
	|FROM
	|	Catalog.KeyOperations AS KeyOperations
	|WHERE
	|	KeyOperations.Priority = &Priority
	|	AND KeyOperations.Ref <> &Ref";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		MessageText = NStr("en = 'Key operation priority %1 is not unique (%2 has the same priority).'");
		MessageText = StrReplace(MessageText, "%1", String(Priority));
		MessageText = StrReplace(MessageText, "%2", Selection.Description);
		PerformanceMonitorClientServer.WriteToEventLog(
			"Catalog.KeyOperations.ObjectModule.BeforeWrite",
			EventLogLevel.Error,
			MessageText);
		CommonUseClientServer.MessageToUser(MessageText);
		Cancel = True;
	EndIf;
	
EndProcedure
#EndIf