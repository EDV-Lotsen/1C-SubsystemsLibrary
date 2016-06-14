
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
 If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	ObjectAttributeCollection = ObjectAttributes.GetItems();
	
	MetadataObject = Parameters.Ref.Metadata();
	For Each AttributeDetails In MetadataObject.Attributes Do
		Attribute = ObjectAttributeCollection.Add();
		FillPropertyValues(Attribute, AttributeDetails);
		Attribute.Check = Parameters.Filter.Find(AttributeDetails.Name) <> Undefined;
		If IsBlankString(Attribute.Synonym) Then 
			Attribute.Synonym = Attribute.Name;
		EndIf;
	EndDo;
	
	For Each TablePartDetails In MetadataObject.TabularSections Do
		TabularSection = ObjectAttributeCollection.Add();
		FillPropertyValues(TabularSection, TablePartDetails);
		For Each AttributeDetails In TablePartDetails.Attributes Do
			Attribute = TabularSection.GetItems().Add();
			FillPropertyValues(Attribute, AttributeDetails);
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SelectOrClearMarks(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SelectOrClearMarks(False);
EndProcedure

&AtClient
Procedure ObjectAttributesCheckOnChange(Item)
	Check = Items.ObjectAttributes.CurrentData.Check;
	For Each SelectedRow In Items.ObjectAttributes.SelectedRows Do 
		Attribute = Items.ObjectAttributes.RowData(SelectedRow);
		Attribute.Check = Check;
		For Each SubordinateAttribute In Attribute.GetItems() Do
			SubordinateAttribute.Check = Check;
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure SelectOrClearMarks(Check)
	For Each Attribute In ObjectAttributes.GetItems() Do 
		Attribute.Check = Check;
		For Each SubordinateAttribute In Attribute.GetItems() Do
			SubordinateAttribute.Check = Check;
		EndDo;
	EndDo;
EndProcedure


&AtClient
Procedure Select(Command)
	Result = New Structure;
	Result.Insert("SelectedAttributes", SelectedAttributes(ObjectAttributes.GetItems()));
	Result.Insert("SelectedItemPresentation", SelectedAttributePresentation());

	Close(Result);
EndProcedure

&AtClient
Function SelectedAttributes(AttributeCollection)
	Result = New Array;
	
	For Each Attribute In AttributeCollection Do
		SubordinateAttributes = Attribute.GetItems();
		If SubordinateAttributes.Count() > 0 Then
			SelectedItemList = SelectedAttributes(SubordinateAttributes);
			For Each SubordinateAttribute In SelectedItemList Do
				Result.Add(Attribute.Name + "." + SubordinateAttribute);
			EndDo;
		ElsIf Attribute.Check Then
			Result.Add(Attribute.Name);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Function SelectedAttributePresentation()
	Return StringFunctionsClientServer.StringFromSubstringArray(SelectedAttributeSynonyms(ObjectAttributes.GetItems()), ", ");
EndFunction

&AtClient
Function SelectedAttributeSynonyms(AttributeCollection)
	Result = New Array;
	
	For Each Attribute In AttributeCollection Do
		SubordinateAttributes = Attribute.GetItems();
		If SubordinateAttributes.Count() > 0 Then
			SelectedItemList = SelectedAttributes(SubordinateAttributes);
			For Each SubordinateAttribute In SelectedItemList Do
				Result.Add(Attribute.Synonym + "." + SubordinateAttribute);
			EndDo;
		ElsIf Attribute.Check Then
			Result.Add(Attribute.Synonym);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction





