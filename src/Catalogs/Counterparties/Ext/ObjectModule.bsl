////////////////////////////////////////////////////////////////////////////////
// OBJECT EVENT HANDLERS

////////////////////////////////////////////////////////////////////////////////
// The "Fill Checking" event handler
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	// If this is a folder,
	If IsFolder Then
		// further checks do not make sence
		Return;
	EndIf;

	// Checking the PriceKind attribute ourself
	If PriceKind.IsEmpty() Then

		// Informing a user that the information is not consistent
		Message = New UserMessage();
		Message.Text = NStr("en = 'The prices kind should be set for the contractor!'");
		Message.Field  = "PriceKind";
		Message.SetData(ThisObject);
		Message.Message();

		// Removing the attribute from the list of automatically checking
		CheckedAttributes.Delete(CheckedAttributes.Find("PriceKind"));
		// Notifying the platform that further work does not make sence
		Cancel = True;

	EndIf;

	// If the field "Street" is filled
	If Not IsBlankString(Street) Then

		// Then the Country, City, and House fields must be filled.
		CheckedAttributes.Add("Country");
		CheckedAttributes.Add("City");
		CheckedAttributes.Add("House");

	EndIf;

EndProcedure
