#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes that are excluded from the scope of the batch object
// modification data processor
//
Function BatchProcessingEditableAttributes() Export
	
	Result = New Array;
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("CompletionDate");
	Result.Add("StartDate");
	Result.Add("AcceptForExecutionDate");
	Result.Add("Subject");
	Result.Add("AcceptedForExecution");
	Result.Add("DueDate");
	Return Result;
	
EndFunction

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	Fields.Add("Description");
	Fields.Add("Date");
	StandardProcessing = False;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	Description = ?(IsBlankString(Data.Description), NStr("en = 'No description'"), Data.Description);
	Date = Format(Data.Date, ?(GetFunctionalOption("UseDateAndTimeInTaskDeadlines"), "DLF=DT", "DLF=D"));
	PresentationPattern = NStr("en = '%1 of %2'");
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(PresentationPattern, Description, Date);
	StandardProcessing = False;
	
EndProcedure

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	If FormType = "ObjectForm" And Parameters.Property("Key") Then
		FormParameters = BusinessProcessesAndTasksServerCall.TaskExecutionForm(Parameters.Key);
		TaskFormName = "";
		Result = FormParameters.Property("FormName", TaskFormName);
		If Result Then
			SelectedForm = TaskFormName;
			StandardProcessing = False;
		EndIf; 
	EndIf;

EndProcedure

#EndRegion

