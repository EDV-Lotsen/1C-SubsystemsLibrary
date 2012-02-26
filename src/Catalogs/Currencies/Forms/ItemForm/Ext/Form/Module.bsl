
////////////////////////////////////////////////////////////////////////////////
// Section of the event handlers
//

// Handler of event "OnCreateAtServer" of form
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.Property("CurrencyCode") Then
		Object.Code = Parameters.CurrencyCode;
	EndIf;
	
	If Parameters.Property("BriefDescription") Then
		Object.Description = Parameters.BriefDescription;
	EndIf;
	
	If Parameters.Property("Details") Then
		Object.Details = Parameters.Details;
	EndIf;
	
	If Parameters.Property("IsLoading") Then
		Object.DownloadRatesPeriodically = Parameters.IsLoading;
	EndIf;
	
	If Object.DownloadRatesPeriodically Then
		Object.SubordinateRateFrom = Catalogs.Currencies.EmptyRef();
	EndIf;
	
	If ValueIsFilled(Object.SubordinateRateFrom) Then
		DependentCurrencyRate = True;
	EndIf;
	
	ReadWritingParameters();
	
	// Handler of subsystem "Additional reports and data processors"
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
EndProcedure

// Handler of form event "OnOpen"
//
&AtClient
Procedure OnOpen(Cancellation)
	
	SetItemsPropertiesOfDependentCurrencyGroup();
	SetHandwritingParametersDeclensions();
	
EndProcedure

// Handler of event "OnChange" of form item DownloadRatesPeriodicallyFromRBKSite
//
&AtClient
Procedure DownloadRatesPeriodicallyFromRBKSiteOnChange(Item)
	
	If Object.DownloadRatesPeriodically Then
		DependentCurrencyRate = False;
		Object.SubordinateRateFrom = NULL;
		Object.SubordinateExchangeRateFactor = 0;
	EndIf;
	
	SetItemsPropertiesOfDependentCurrencyGroup();
	
EndProcedure

// Handler of event "OnChange" of form item DownloadRatesPeriodicallyFromRBKSite
//
&AtClient
Procedure DependentCurrencyRateOnChange(Item)
	
	SetItemsPropertiesOfDependentCurrencyGroup();
	
EndProcedure

// Handler of event "StartChoice" item of form SubordinateRateFrom
//
&AtClient
Procedure SubordinateRateFromStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	PrepareChoiceDataOfSubordinateCurrency(ChoiceData, Object.Ref);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancellation, WriteParameters)
	
	If DependentCurrencyRate Then
		If Not ValueIsFilled(Object.SubordinateRateFrom) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'It is required to indicate the main currency'"), ,
				"Object.SubordinateRateFrom", ,
				Cancellation);
		EndIf;
		
		If Not ValueIsFilled(Object.SubordinateExchangeRateFactor) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'It is required to set the factor of subordinate currency rate'"), ,
				"Object.SubordinateExchangeRateFactor", ,
				Cancellation);
		EndIf;
			
	EndIf;
	
	// Initialize attributes of the currency load and dependence
	If NOT DependentCurrencyRate Then
		Object.SubordinateRateFrom = NULL;
		Object.SubordinateExchangeRateFactor = 0;
	EndIf;
	
EndProcedure

// Handler of event BeforeWriteAtServer
//
&AtServer
Procedure BeforeWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	
	CurrentObject.WritingParameters = InWordsField1 + ", "
											+ InWordsField2  + ", "
											+ InWordsField3  + ", "
											+ Lower(Left(InWordsField4, 1)) + ", "
											+ InWordsField5  + ", "
											+ InWordsField6  + ", "
											+ InWordsField7  + ", "
											+ Lower(Left(InWordsField8, 1)) + ", "
											+ FractionLength;
	
EndProcedure

// Handler of event "OnChange" of form item InWordsField4
//
&AtClient
Procedure InWordsField4OnChange(Item)
	SetHandwritingParametersDeclensions();
EndProcedure

// Handler of event "OnChange" of form item InWordsField8
//
&AtClient
Procedure InWordsField8OnChange(Item)
	SetHandwritingParametersDeclensions();
EndProcedure

&AtClient
Procedure FractionLengthAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure FractionLengthTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField4AutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField4TextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8AutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8TextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SECTION OF SERVICE FUNCTIONS AND PROCEDURES
//

// Procedure reads parameters of writing in words and fills the corresponding dialog fields.
//
&AtServer
Procedure ReadWritingParameters()
	
	StringOfParameters = StrReplace(Object.WritingParameters, ",", Chars.LF);
	
	InWordsField1 = TrimAll(StrGetLine(StringOfParameters, 1));
	InWordsField2 = TrimAll(StrGetLine(StringOfParameters, 2));
	InWordsField3 = TrimAll(StrGetLine(StringOfParameters, 3));
	
	Gender = TrimAll(StrGetLine(StringOfParameters, 4));
	
	If	  Lower(Gender) = "m" Then
		InWordsField4 = "Masculine";
	ElsIf Lower(Gender) = "f" Then
		InWordsField4 = "Feminine";
	ElsIf Lower(Gender) = "n" Then
		InWordsField4 = "Neuter";
	EndIf;
	
	InWordsField5 = TrimAll(StrGetLine(StringOfParameters, 5));
	InWordsField6 = TrimAll(StrGetLine(StringOfParameters, 6));
	InWordsField7 = TrimAll(StrGetLine(StringOfParameters, 7));
	
	Gender = TrimAll(StrGetLine(StringOfParameters, 8));
	
	If	  Lower(Gender = "m") Then
		InWordsField8 = "Masculine";
	ElsIf Lower(Gender = "f") Then
		InWordsField8 = "Feminine";
	ElsIf Lower(Gender = "n") Then
		InWordsField8 = "Neuter";
	EndIf;
	
	FractionLength     = TrimAll(StrGetLine(StringOfParameters, 9));
	
EndProcedure

// Procedure adjusts visibility of the form items, that are involved
// in defining of the parameters of dependence from basic currency (ref to basic
// currency and ratio).
//
&AtClient
Procedure SetItemsPropertiesOfDependentCurrencyGroup()
	
	If Object.DownloadRatesPeriodically Then
		Items.GroupDependentCurrencyRate.Enabled = False;
		DependentCourseParametersFalg = False;
	Else
		Items.GroupDependentCurrencyRate.Enabled = True;
		DependentCourseParametersFalg = ? (DependentCurrencyRate, True, False);
	EndIf;
	
	Items.SubordinateRateFrom.AutoMarkIncomplete 	= DependentCourseParametersFalg;
	Items.SubordinateExchangeRateFactor.AutoMarkIncomplete 	= DependentCourseParametersFalg;
	Items.SubordinateRateFrom.Enabled 				= DependentCourseParametersFalg;
	Items.SubordinateExchangeRateFactor.Enabled 			= DependentCourseParametersFalg;
	If Not DependentCourseParametersFalg Then
		Items.SubordinateRateFrom.MarkIncomplete 	= DependentCourseParametersFalg;
		Items.SubordinateExchangeRateFactor.MarkIncomplete 	= DependentCourseParametersFalg;
	EndIf
	
EndProcedure

// Procedure adjusts declension of the form item titles
//
//
&AtClient
Procedure SetHandwritingParametersDeclensions()
	
	If	  InWordsField4 = "Female" Then
		Items.InWordsField1.Title = "one";
		Items.InWordsField2.Title = "two";
	ElsIf InWordsField4 = "Male" Then
		Items.InWordsField1.Title = "one";
		Items.InWordsField2.Title = "two";
	Else
		Items.InWordsField1.Title = "one";
		Items.InWordsField2.Title = "two";
	EndIf;
	
	If	  InWordsField8 = "Female" Then
		Items.InWordsField5.Title = "one";
		Items.InWordsField6.Title = "two";
	ElsIf InWordsField8 = "Male" Then
		Items.InWordsField5.Title = "one";
		Items.InWordsField6.Title = "two";
	Else
		Items.InWordsField5.Title = "one";
		Items.InWordsField6.Title = "two";
	EndIf;
	
EndProcedure

// Prepares choice list for the subordinate currency so,
// that subordinate currency would not be included in the list
//
&AtServerNoContext
Procedure PrepareChoiceDataOfSubordinateCurrency(ChoiceData, Ref)
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	
	Query.Text = "SELECT Ref, Details
	               |FROM
	               |	Catalog.Currencies
	               |WHERE
	               |	Ref <> &Ref
	               |And
	               |	SubordinateRateFrom  = Value(Catalog.Currencies.EmptyRef)
	               |ORDER BY Details";
	
	Query.Parameters.Insert("Ref", Ref);
	
	Selection = Query.Execute().Choose();
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.Details);
	EndDo;
	
EndProcedure

// Input control auxiliary functions

&AtClient
Function AutoCompleteByChoiceList(Item, Text, StandardProcessing)
	
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
Function TextEditEndByListChoice(Item, Text, StandardProcessing)
	
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
