

////////////////////////////////////////////////////////////////////////////////
// Block of service functions
//

// Fills report
//
&AtServer
Function OutputReport()
	
	FormAttributeToValue("Report").GenerateReport(ReportTable, VersionsList);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Block of event handlers
//

// Handler of event "OnCreateAtServer" of form
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If ValueIsFilled(Parameters.Ref) 
	   And Parameters.Property("VersionsList") Then
		Report.ObjectReference = Parameters.Ref;
		
		VersionsList = Parameters.VersionsList;
		
		If VersionsList.Count() > 1 Then
			StringOfVersionsNumber = "";
			
			VersionsList.SortByValue();
			
			For Each VersionsListItem In VersionsList Do
				StringOfVersionsNumber = StringOfVersionsNumber + String(VersionsListItem) + ", ";
			EndDo;
			
			StringOfVersionsNumber = Left(StringOfVersionsNumber, StrLen(StringOfVersionsNumber) - 2);
			
			Title = StringFunctionsClientServer.SubstitureParametersInString(
			                 NStr("en = 'Report by changes of the version of object %1 ## %2'"),
			                 Parameters.Ref,
			                 StringOfVersionsNumber);
		Else
			Title = StringFunctionsClientServer.SubstitureParametersInString(
			                 NStr("en = 'Object version %1 # %2'"),
			                 Parameters.Ref,
			                 String(VersionsList[0]));
		EndIf;
		
		OutputReport();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	If Not ValueIsFilled(Report.ObjectReference)
	   And VersionsList.Count() = 0 Then
		Cancellation = True;
		DoMessageBox(NStr("en = 'Interactive use prohibited'"));
		Return;
	EndIf;
	
EndProcedure
