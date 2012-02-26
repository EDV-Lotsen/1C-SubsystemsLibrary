

Procedure ItemOrderSetupBeforeWrite(Source, Cancellation) Export
	
	// If Cancellation has been assigned in handler - do not change order
	If Cancellation Then
		Return;
	EndIf;
	
	// Check, if object has additional ordering attribute
	Information = ItemOrderSetup.GetMetadataSummaryForOrdering(Source.Ref);
	If Not ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Return;
	EndIf;
	
	// Calculate new value for the item order
	If Source.AdditionalOrderingAttribute = 0 Then
		Source.AdditionalOrderingAttribute = GetAddOrderingAttributeNewValue(Information, Source);
	EndIf;
	
EndProcedure

Procedure ItemOrderSetupOnCopy(Source, CopiedObject) Export
	
	Information = ItemOrderSetup.GetMetadataSummaryForOrdering(Source.Ref);
	If ObjectHasAdditionalOrderingAttribute(Source, Information) Then
		Source.AdditionalOrderingAttribute = 0;
	EndIf;
	
EndProcedure

// Check, if object has AdditionalOrderingAttribute
Function ObjectHasAdditionalOrderingAttribute(Object, Information)
	
	If Not Information.HaveParent Then
		// Catalog is not hierarchical, so attribute is there
		Return True;
		
	ElsIf Object.IsFolder And Not Information.ForGroups Then
		// This is a group, but for group ordering is not assigned
		Return False;
		
	ElsIf Not Object.IsFolder And Not Information.ForItems Then
		// This is an item, but for items ordering is not assigned
		Return False;
		
	Else
		Return True;
		
	EndIf;
	
EndFunction

// Get new value of addit. ordering attribute for the object
Function GetAddOrderingAttributeNewValue(Information, Object)
	
	Query = New Query;
	Query.Text =
		"SELECT TOP 1
		|	Table.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
		|FROM
		|	" + Information.FullName + " AS Table";
	
	StrConditions = "";
	If Information.HaveParent Then
		StrConditions = StrConditions + ?(StrConditions = "", "", " And ") + "(Table.Parent = &Parent)";
		Query.SetParameter("Parent", Object.Parent);
	EndIf;
	If Information.HaveOwner Then
		StrConditions = StrConditions + ?(StrConditions = "", "", " And ") + "(Table.Owner = &Owner)";
		Query.SetParameter("Owner", Object.Owner);
	EndIf;
	
	If StrConditions <> "" Then
		Query.Text = Query.Text + "
		|WHERE
		|	" + StrConditions;
	EndIf;


	Query.Text = Query.Text + "
	|
	|ORDER BY
	|	AdditionalOrderingAttribute DESC
	|";
	
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Return ?(Not ValueIsFilled(Selection.AdditionalOrderingAttribute), 1, Selection.AdditionalOrderingAttribute + 1);
	
EndFunction

 