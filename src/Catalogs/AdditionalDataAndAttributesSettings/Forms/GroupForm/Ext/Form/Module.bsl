
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Var FirstPartOfName, SecondPartOfName;
	
	ReadOnly = True;
	
	Catalogs.AdditionalDataAndAttributesSettings.GetNameParts(Object.Ref, FirstPartOfName, SecondPartOfName);
	
	If NOT Catalogs.AdditionalDataAndAttributesSettings.UsedAdditionalAttributes(FirstPartOfName, SecondPartOfName) Then
		Items.AdditionalAttributes.Visible = False;
	EndIf;
	
	If NOT Catalogs.AdditionalDataAndAttributesSettings.UsedAdditionalData(FirstPartOfName, SecondPartOfName) Then
		Items.AdditionalData.Visible = False;
	EndIf;
	
EndProcedure
