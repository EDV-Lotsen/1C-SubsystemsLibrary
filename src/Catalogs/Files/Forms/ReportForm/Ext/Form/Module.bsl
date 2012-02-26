

&AtClient
Procedure ReportSelection(Item, Area, StandardProcessing)
	
	#If Not WebClient Then
		If Find(Area.Text, ":\") > 0 OR Find(Area.Text, ":/") > 0 Then // Path to a file
			FileOperationsClient.OpenExplorerWithFile(Area.Text);
		EndIf;
	#EndIf

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	Report = FileOperations.ImportFilesGenerateReport(Parameters.FilenamesWithErrorsArray);
	
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;	
EndProcedure
