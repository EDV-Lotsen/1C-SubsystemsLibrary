
////////////////////////////////////////////////////////////////////////////////
// Business processes and tasks subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers

Procedure BusinessProcessPresentationFieldsGetProcessing(ObjectManager, Fields, StandardProcessing) Export
	
	Fields.Add("Description");
	Fields.Add("Date");
	StandardProcessing = False;

EndProcedure

Procedure BusinessProcessPresentationGetProcessing(ObjectManager, Data, Presentation, StandardProcessing) Export
	
	Description = ?(IsBlankString(Data.Description), NStr("en = 'No description'"), Data.Description);
#If Server Or ThickClientOrdinaryApplication Or ThickClientManagedApplication Or ExternalConnection Then
	Date = Format(Data.Date, ?(GetFunctionalOption("UseDateAndTimeInTaskDeadlines"), "DLF=DT", "DLF=D"));
	Presentation = Metadata.FindByType(TypeOf(ObjectManager)).Presentation();
#Else	
	Date = Format(Data.Date, "DLF=D");
	Presentation = NStr("en = 'Business process'");
#EndIf
	PresentationPattern = NStr("en = '%1 issued on %2 (%3)'");
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(PresentationPattern, Description, Date, Presentation);
	StandardProcessing = False;
	 
EndProcedure

#EndRegion
