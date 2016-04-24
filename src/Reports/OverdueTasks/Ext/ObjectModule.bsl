#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	DateFormat = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	DueDate = DataCompositionSchema.DataSets[0].Fields.Find("DueDate");
	DueDate.Appearance.SetParameterValue("Format", DateFormat);
	
	CompletionDate = DataCompositionSchema.DataSets[0].Fields.Find("CompletionDate");
	CompletionDate.Appearance.SetParameterValue("Format", DateFormat);
	
EndProcedure

#EndRegion

#EndIf