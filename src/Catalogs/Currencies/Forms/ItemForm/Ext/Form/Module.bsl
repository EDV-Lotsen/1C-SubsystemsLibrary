
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		If Parameters.Property("CurrencyCode") Then
			Object.Code = Parameters.CurrencyCode;
		EndIf;
		
		If Parameters.Property("ShortDescription") Then
			Object.Description = Parameters.ShortDescription;
		EndIf;
		
		If Parameters.Property("LongDescription") Then
			Object.LongDescription = Parameters.LongDescription;
		EndIf;
		
		If Parameters.Property("Importing") Then
			Object.RateSettingMethod = ?(Parameters.Importing, Enums.CurrencyRateSettingMethods.ImportFromInternet,
				Enums.CurrencyRateSettingMethods.ManualInput);
		EndIf;
		
		If Parameters.Property("InWordParametersInHomeLanguage") Then
			Object.InWordParametersInHomeLanguage = Parameters.InWordParametersInHomeLanguage;
		EndIf;
		
		FillFormByObject();
		
	EndIf;
	
	SetItemsEnabled(ThisObject);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillFormByObject();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.InWordParametersInHomeLanguage = InWordParametersInHomeLanguage(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Basic additional data page

&AtClient
Procedure MainCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	PrepareSubordinateCurrencyChoiceData(ChoiceData, Object.Ref);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Currency in word parameters page

&AtClient
Procedure AmountNumberOnChange(Item)
	
	SetAmountInWords(ThisObject);
	
EndProcedure

&AtClient
Procedure InWordsField4HomeLanguageOnChange(Item)
	SetSignatureCaseParameters(ThisObject);
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField4HomeLanguageAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField4HomeLanguageTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8HomeLanguageOnChange(Item)
	SetSignatureCaseParameters(ThisObject);
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField8HomeLanguageAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8HomeLanguageTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField1HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField2HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField3HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField5HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField6HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField7HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure FractionalPartLengthOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure FractionalPartLengthAutoComplete(Item, Text, ChoiceData, Waiting, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure FractionalPartLengthTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CurrencyRateOnChange(Item)
	SetItemsEnabled(ThisObject);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure FillFormByObject()
	
	LoadInWordParameters();
	
	SetSignatureCaseParameters(ThisObject);
	SetAmountInWords(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Function InWordParametersInHomeLanguage(Form)
	
	Return Form.InWordsField1HomeLanguage + ", "
			+ Form.InWordsField2HomeLanguage + ", "
			+ Form.InWordsField5HomeLanguage + ", "
			+ Form.InWordsField6HomeLanguage + ", "
			+ Form.FractionalPartLength;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetAmountInWords(Form)
	
	Form.AmountInWords = NumberInWords(Form.AmountNumber, , InWordParametersInHomeLanguage(Form));
	
EndProcedure

&AtServer
Procedure LoadInWordParameters()
	
	// Reads in word parameters and fills the appropriate dialog boxes.
	
	ParameterString = StrReplace(Object.InWordParametersInHomeLanguage, ",", Chars.LF);
	
	InWordsField1HomeLanguage = TrimAll(StrGetLine(ParameterString, 1));
	InWordsField2HomeLanguage = TrimAll(StrGetLine(ParameterString, 2));
	
	InWordsField5HomeLanguage = TrimAll(StrGetLine(ParameterString, 5));
	InWordsField6HomeLanguage = TrimAll(StrGetLine(ParameterString, 6));
	
	FractionalPartLength     = TrimAll(StrGetLine(ParameterString, 9));
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetSignatureCaseParameters(Form)
	
	// In word parameter title declension
	
	Items = Form.Items;
	
	If Form.InWordsField4HomeLanguage = "Female" Then
		Items.InWordsField1HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField2HomeLanguage.Title = NStr("en = 'Two'");
	ElsIf Form.InWordsField4HomeLanguage = "Male" Then
		Items.InWordsField1HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField2HomeLanguage.Title = NStr("en = 'Two'");
	Else
		Items.InWordsField1HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField2HomeLanguage.Title = NStr("en = 'Two'");
	EndIf;
	
	If Form.InWordsField8HomeLanguage = "Female" Then
		Items.InWordsField5HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField6HomeLanguage.Title = NStr("en = 'Two'");
	ElsIf Form.InWordsField8HomeLanguage = "Male" Then
		Items.InWordsField5HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField6HomeLanguage.Title = NStr("en = 'Two'");
	Else
		Items.InWordsField5HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField6HomeLanguage.Title = NStr("en = 'Two'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure PrepareSubordinateCurrencyChoiceData(ChoiceData, Ref)
	
	// Prepares a choice list of the subordinate currency in such a way
	// that the currency is not in the list
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	
	Query.Text = "SELECT Ref, LongDescription
	               |FROM
	               |	Catalog.Currencies
	               |WHERE
	               |	Ref <> &Ref
	               |AND
	               |	MainCurrency  = Value(Catalog.Currencies.EmptyRef)
	               |ORDER BY LongDescription";
	
	Query.Parameters.Insert("Ref", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.LongDescription);
	EndDo;
	
EndProcedure

&AtClient
Function AutoCompleteByChoiceList(Item, Text, StandardProcessing)
	
	// Input management secondary function
	
	For Each ChoiceItem In Item.ChoiceList Do
		If Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			StandardProcessing = False;
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Function TextEditEndByChoiceList(Item, Text, StandardProcessing)
	
	// Input management secondary function
	
	StandardProcessing = False;
	
	For Each ChoiceItem In Item.ChoiceList Do
		If Upper(Text) = Upper(ChoiceItem.Presentation) Then
			StandardProcessing = True;
		ElsIf Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			StandardProcessing = False;
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetItemsEnabled(Form)
	Items = Form.Items;
	Object = Form.Object;
	Items.OtherCurrencyMarginsGroup.Enabled = Object.RateSettingMethod = PredefinedValue("Enum.CurrencyRateSettingMethods.AnotherCurrencyMargin");
	Items.RateCalculationFormula.Enabled = Object.RateSettingMethod = PredefinedValue("Enum.CurrencyRateSettingMethods.CalculateByFormula");
EndProcedure
#EndRegion
