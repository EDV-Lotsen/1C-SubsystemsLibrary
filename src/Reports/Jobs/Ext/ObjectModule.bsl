#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	DueDate = DataCompositionSchema.DataSets[0].Fields.Find("DueDate");
	DueDate.Appearance.SetParameterValue("Format", ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D"));
	
EndProcedure

#EndRegion

#EndIf