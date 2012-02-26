
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	//////////////////////////////////////////////////////////////////////////////
	// Support of the separate setup of the addit. attributes and the addit. information
	//
	
	Var FirstPartOfName, SecondPartOfName;
	
	If Object.Predefined Then
		Items.Description.ReadOnly = True;
	EndIf;
	
	If Object.Ref.Predefined And Object.Ref.Parent = Catalogs.AdditionalDataAndAttributesSettings.EmptyRef() Then
		RefOfPedefined = Object.Ref;
	Else
		RefOfPedefined = Object.Ref.Parent;
	EndIf;
	
	If RefOfPedefined = Catalogs.AdditionalDataAndAttributesSettings.EmptyRef() Then
		Raise NStr("en = 'Properties owner is not found!'");
	EndIf;
	
	Catalogs.AdditionalDataAndAttributesSettings.GetNameParts(RefOfPedefined, FirstPartOfName, SecondPartOfName);
	UseAdditAttributes = Catalogs.AdditionalDataAndAttributesSettings.UsedAdditionalAttributes(FirstPartOfName, SecondPartOfName);
	UseAdditInfo = Catalogs.AdditionalDataAndAttributesSettings.UsedAdditionalData(FirstPartOfName, SecondPartOfName);
	
	If NOT UseAdditAttributes And NOT UseAdditInfo Then
		Cancellation = True;
		Raise NStr("en = 'Use of properties is not determined!'");
	EndIf;
	
	If NOT UseAdditAttributes Then
		Items.TableAttributes.Visible = False;
		Items.TableInfo.TitleLocation = FormItemTitleLocation.None;
	ElsIf NOT UseAdditInfo Then
		Items.TableInfo.Visible = False;
		Items.TableAttributes.TitleLocation = FormItemTitleLocation.None;
	EndIf;
	
	If UseAdditAttributes Then
		For Each AdditionalAttribute In Object.AdditionalAttributes Do
			If NOT AdditionalAttribute.Property.IsAdditionalData Then
				TableAttributes.Add().Property = AdditionalAttribute.Property;
			EndIf;
		EndDo;
	EndIf;
	
	If UseAdditInfo Then
		For Each Additional_Info In Object.AdditionalData Do
			If Additional_Info.Property.IsAdditionalData Then
				TableInfo.Add().Property = Additional_Info.Property;
			EndIf;
		EndDo;
	EndIf;
	
//
//////////////////////////////////////////////////////////////////////////////
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancellation, CurrentObject)
	
	CurrentObject.AdditionalAttributes.Clear();
	CurrentObject.AdditionalData.Clear();
	
	If UseAdditAttributes Then
		For Each AdditionalAttribute In TableAttributes Do
			CurrentObject.AdditionalAttributes.Add().Property = AdditionalAttribute.Property;
		EndDo;
	EndIf;
	
	If UseAdditInfo Then
		For each Additional_Info In TableInfo Do
			CurrentObject.AdditionalData.Add().Property = Additional_Info.Property;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("PropertiesSetChanged", Object.Ref);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	/////////////////////////////////////////////////////////
	// On writing the property it is required to move property to
	// the respective group and refresh the comment field,
	// if required
	
	If EventName = "RecordedAdditionalProperty" Then
		CheckTablesContentAfterWriteProperty(Parameter.IsAdditionalData, Source);
		
	ElsIf EventName = "FillOfPropertiesToSet" Then
		
		ArrayOfBeingAdded = New Array;
		
		If Parameter.IsAdditionalData Then
			Table = TableInfo;
		Else
			Table = TableAttributes
		EndIf;
		
		For Each BeingAdded In Parameter.ArrayOfBeingAdded Do
			Filter = New Structure("Property", BeingAdded);
			If Table.FindRows(Filter).Count() = 0 Then
				ArrayOfBeingAdded.Add(BeingAdded);
			EndIf;
		EndDo;
		
		If ArrayOfBeingAdded.Count() > 0 Then
			AddProperties(ArrayOfBeingAdded);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures - handlers of the from tabular section commands

&AtClient
Procedure TableAttributesBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	Cancellation = True;
EndProcedure

&AtClient
Procedure TableInfoBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	Cancellation = True;
EndProcedure

&AtClient
Procedure TabAttributesBeforeDelete(Item, Cancellation)
	
	TabPropertiesBeforeDelete(Item, TableAttributes);
	
EndProcedure

&AtClient
Procedure TableInfoBeforeDelete(Item, Cancellation)
	
	TabPropertiesBeforeDelete(Item, TableInfo);
	
EndProcedure

&AtClient
Procedure TabPropertiesBeforeDelete(Item, TableOfProperties)
	
	ArrayOfPropertiesBeingDeleted = New Array;
	
	For Each SelRow In Item.SelectedRows Do
		Property = Item.RowData(SelRow).Property;
		ArrayOfPropertiesBeingDeleted.Add(Property);
		Rows = TableOfProperties.FindRows(New Structure("Property", Property));
		TableOfProperties.Delete(Rows[0]);
	EndDo;
	
	If ArrayOfPropertiesBeingDeleted.Count() > 0 Then
		NotifyOfSetChange("Delete", ArrayOfPropertiesBeingDeleted);
	EndIf;
	
EndProcedure

&AtClient
Procedure TableInfoSelection(Item, RowSelected, Field, StandardProcessing)
	
	TableSelection(Item, RowSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure TableAttributesSelection(Item, RowSelected, Field, StandardProcessing)
	
	TableSelection(Item, RowSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure FillAdditAttributes(Command)
	CallFillForm(False);
EndProcedure

&AtClient
Procedure FillOfAdditInformation(Command)
	CallFillForm(True);
EndProcedure

&AtClient
Procedure CallFillForm(IsAdditionalData)
	
	ParametersStructrure = New Structure;
	ParametersStructrure.Insert("IsAdditionalData", IsAdditionalData);
	
	ArrSelected = New Array;
	
	If IsAdditionalData Then
		For Each ItemStr In TableInfo Do
			ArrSelected.Add(ItemStr.Property);
		EndDo;
	Else
		For Each ItemStr In TableAttributes Do
			ArrSelected.Add(ItemStr.Property);
		EndDo;
	EndIf;
	ParametersStructrure.Insert("ArrSelected", ArrSelected);
	
	OpenForm("Catalog.AdditionalDataAndAttributesSettings.Form.FillOfProperties", ParametersStructrure, ThisForm, Uuid);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure NotifyOfSetChange(Operation, PropertiesArray)
	
	Notify("ChangedSetOfSelected", 
				New Structure("Operation,PropertiesArray",
								Operation,
								PropertiesArray),
				ThisForm);
	
EndProcedure

&AtClient
Procedure CheckTablesContentAfterWriteProperty(IsAdditionalData, AdditPropertyRef)
	
	// Define, from which to which table it might be needed to transfer an addit. property
	If IsAdditionalData Then
		Table1 = TableInfo;
		Table2 = TableAttributes;
	Else
		Table1 = TableAttributes;
		Table2 = TableInfo;
	EndIf;
	
	// Check if property enters the table, from which info should be transfered
	Property = AdditPropertyRef;
	Rows = Table2.FindRows(New Structure("Property", Property));
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	// Delete from one table
	IndexOf = Table2.IndexOf(Rows[0]);
	Table2.Delete(IndexOf);
	
	// Insert to another
	newStr = Table1.Add();
	newStr.Property = Property;
	
EndProcedure

&AtClient
Procedure AddProperties(masAdd)
	
	arrP = New Array;
	For Each Str In TableAttributes Do
		arrP.Add(Str.Property);
	EndDo;
	
	arrC = New Array;
	For Each Str In TableInfo Do
		arrC.Add(Str.Property);
	EndDo;
	
	CommonArrayOfProperties = New Array;
	
	If AddSelectedProperties(masAdd, arrP, arrC) Then
		Modified = True;
		
		For Each Property In arrP Do
			newStr = TableAttributes.Add();
			newStr.Property = Property;
			CommonArrayOfProperties.Add(Property);
		EndDo;
		
		For Each Property In arrC Do
			newStr = TableInfo.Add();
			newStr.Property = Property;
			CommonArrayOfProperties.Add(Property);
		EndDo;
		
		NotifyOfSetChange("Insert", CommonArrayOfProperties);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function AddSelectedProperties(arrRefs, arrP, arrC)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalDataAndAttributes.Ref AS Property
	|INTO Temporary
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
	|WHERE
	|	(AdditionalDataAndAttributes.Ref IN (&arrP)
	|			OR AdditionalDataAndAttributes.Ref IN (&arrC))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalDataAndAttributes.Ref,
	|	AdditionalDataAndAttributes.IsAdditionalData
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS AdditionalDataAndAttributes
	|		LEFT JOIN Temporary AS Temporary
	|		ON AdditionalDataAndAttributes.Ref = Temporary.Property
	|WHERE
	|	AdditionalDataAndAttributes.Ref IN HIERARCHY(&arrRefs)
	|	AND (NOT AdditionalDataAndAttributes.IsFolder)
	|	AND Temporary.Property IS NULL 
	|	AND (NOT AdditionalDataAndAttributes.DeletionMark)
	|
	|ORDER BY
	|	AdditionalDataAndAttributes.Description";
	
	Query.SetParameter("arrRefs", arrRefs);
	Query.SetParameter("arrP", arrP);
	Query.SetParameter("arrC", arrC);
	
	Selection = Query.Execute().Choose();
	
	arrP.Clear();
	arrC.Clear();
	
	If Selection.Count() = 0 Then
		Return False;
	EndIf;
	
	While Selection.Next() Do
		
		If Selection.IsAdditionalData Then
			arrC.Add(Selection.Ref);
		Else
			arrP.Add(Selection.Ref);
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

&AtClient
Procedure TableSelection(Item, RowSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("OpensFromSetProperties", True);
	OpenParameters.Insert("Key", Item.RowData(RowSelected).Property);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalDataAndAttributes.Form.ItemForm", OpenParameters);
	
EndProcedure
