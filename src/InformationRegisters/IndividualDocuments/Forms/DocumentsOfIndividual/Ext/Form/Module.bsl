
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.Filter.Property("Individual") Then
		Individual = Parameters.Filter.Individual;
		
		PersonIdentity = InformationRegisters.IndividualDocuments.DocumentCertifyingPersonalityOfInd(Individual);
		
		IsIdentity = Not IsBlankString(PersonIdentity);
		
		Items.PersonIdentity.Height	= ?(IsIdentity, 2, 0);
		PersonIdentity 				= ?(IsIdentity, "Personal ID: ", "") + PersonIdentity;
		
		Query = New Query;
		Query.SetParameter("Individual",	Individual);
		Query.Text =
		"SELECT TOP 1
		|	IndividualDocuments.Presentation
		|FROM
		|	InformationRegister.IndividualDocuments AS IndividualDocuments
		|WHERE
		|	IndividualDocuments.Individual = &Individual";
		AreDocuments = Not Query.Execute().IsEmpty();
		
		If Not IsIdentity And AreDocuments Then
			Items.NoIdentity.Visible = True;
			TextOfMessage = NStr("en = 'For the individual %1 the ID document has not been set up.'");
			PersonIdentity = StringFunctionsClientServer.SubstitureParametersInString(TextOfMessage, Individual);
		EndIf;
		
		Items.PersonIdentity.Visible = Not IsBlankString(PersonIdentity);
	EndIf;
	
EndProcedure

