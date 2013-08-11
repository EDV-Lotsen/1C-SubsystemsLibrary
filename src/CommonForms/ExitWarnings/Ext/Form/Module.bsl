////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
		
	InitFormItems(Parameters.Warnings);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

// Click on the hyperlink handler.
//
&AtClient
Procedure HyperlinkOnClick(Item)
	For Each QuestionString In ItemsAndParametersMapArray Do
		If Item.Name = QuestionString.Value.Name Then 
			Form = Undefined;
			If QuestionString.Value.Property("Form", Form) Then 
				FormParameters = Undefined;
				If QuestionString.Value.Property("FormParameters", FormParameters) Then 
				EndIf;
				OpenFormModal(Form, FormParameters);
			EndIf;	
			Break;
		EndIf;	
	EndDo;	
EndProcedure

// Initializes an array of future tasks that should be executed on close.
//
&AtClient 
Procedure ChangeFutureTaskArray(Item)
	ItemName 		= Item.Name;
	FoundItem 	= Items.Find(ItemName);
	
	If FoundItem = Undefined Then 
		Return;
	EndIf;	
	
	ItemValue = ThisForm[ItemName];
	If TypeOf(ItemValue) <> Type("Boolean") Then
		Return;
	EndIf;	
		

	ArrayID = TaskIDByName(ItemName);
	If ArrayID = Undefined Then 
		Return;
	EndIf;
	ArrayItem = TaskArrayToExecuteOnClose.FindByID(ArrayID);
	Using = Undefined;
	If ArrayItem.Value.Property("Using", Using) Then 
		If TypeOf(Using) = Type("Boolean") Then 
			ArrayItem.Value.Using = ItemValue;
		EndIf;
	EndIf;	
EndProcedure	


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExitApplication(Command)
	
	ExecuteTasksOnClose();
	Close(False);
	
EndProcedure

&AtClient
Procedure DontExit(Command)
	
	Close(True);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Creates form items by questions to a user.
//
// Parameters:
//	Questions - value list of questions.
//
&AtServer
Procedure InitFormItems(Warnings)
	For Each CurrentWarning In Warnings Do 
		// Skipping current structure reading if there are texts for a check box and for a structure at the same time.
		CheckBoxText 		= "";
		HyperlinkText 	= "";
		If CurrentWarning.Property("CheckBoxText", CheckBoxText) 
			And CurrentWarning.Property("HyperlinkText", HyperlinkText) Then 
			Continue;
		EndIf;	
		
		// Creating a hyperlink on the form.
		If CurrentWarning.Property("HyperlinkText", HyperlinkText) Then
			If Not IsBlankString(HyperlinkText) Then 
				CreateHyperlinkOnForm(CurrentWarning);
			EndIf;	
		EndIf;	
		
		// Creating a check box on the form.
		If CurrentWarning.Property("CheckBoxText", CheckBoxText) Then
			If Not IsBlankString(CheckBoxText) Then 
				CreateCheckBoxOnForm(CurrentWarning);
			EndIf;	
		EndIf;
	EndDo;	
	
	// Creating the final question on the form.
	CreateFinalQuestion();
EndProcedure

// Generates a group on the form and returns it.
// This group is a child group for "MainGroup".
//
&AtServer
Function GenerateFormItemGroup()
	GroupName 		= FindLabelNameOnForm("GroupOnForm");
	GroupType 		= Type("FormGroup");
	GroupParent 	= Items.MainGroup;
	
	Group 					= Items.Add(GroupName, GroupType, GroupParent);
	Group.Kind				= FormGroupType.UsualGroup;
	Group.Representation	= UsualGroupRepresentation.None;
	Group.ShowTitle 		= False;
	Group.HorizontalStretch = True;
	
	Return Group; 
EndFunction

// Creates a hyperlink on the form with an information text.
//
// Parameters:
//	QuestionStructure - structure of a passed question.
//
&AtServer
Procedure CreateHyperlinkOnForm(QuestionStructure)
	Group = GenerateFormItemGroup();
	
	InformationText = "";
	If QuestionStructure.Property("InformationText", InformationText) Then
		If Not IsBlankString(InformationText) Then 
			LabelName 		= FindLabelNameOnForm("QuestionLabel");
			LabelType		= Type("FormDecoration");
			LabelParent	= Group;
			
			InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
			InformationTextItem.Title = InformationText;
		EndIf;	
	EndIf;
	
	HyperlinkText = "";
	If QuestionStructure.Property("HyperlinkText", HyperlinkText) Then 
		If Not IsBlankString(HyperlinkText) Then
			HyperlinkName		= FindLabelNameOnForm("QuestionLabel");
			HyperlinkType		= Type("FormDecoration");
			HyperlinkParent	= Group;

			HyperlinkItem = Items.Add(HyperlinkName, HyperlinkType, HyperlinkParent);
			HyperlinkItem.Href 	= True;
			HyperlinkItem.Title 	= HyperlinkText;
			HyperlinkItem.SetAction("Click", "HyperlinkOnClick");
			
			HyperlinkForm 	= Undefined;
			HyperlinkAction = Undefined;
			If QuestionStructure.Property("ActionOnHyperlinkClick", HyperlinkAction) Then
				DataProcessorStructure = QuestionStructure.ActionOnClickHyperlink;
				If DataProcessorStructure.Property("Form", HyperlinkForm) Then 
					ArrayStructure = New Structure;
					ArrayStructure.Insert("Name", 	HyperlinkName);
					ArrayStructure.Insert("Form", 	HyperlinkForm);
					
					FormParameters = Undefined;
					If DataProcessorStructure.Property("FormParameters", FormParameters) Then
						If TypeOf(FormParameters) = Type("Structure") Then 
							FormParameters.Insert("ExitApplication", True);
						ElsIf FormParameters = Undefined Then 
							FormParameters = New Structure;
							FormParameters.Insert("ExitApplication", True);
						EndIf;	
						ArrayStructure.Insert("FormParameters", FormParameters);
					EndIf;	
					
					ItemsAndParametersMapArray.Add(ArrayStructure);
				EndIf;	
			EndIf;
		EndIf;
	EndIf;	
EndProcedure	

// Creates a check box with information text on the form.
//
// Parameters:
//	QuestionStructure - structure of a passed question.
//
&AtServer
Procedure CreateCheckBoxOnForm(QuestionStructure)
	DefaultValue = True;
	Group 				= GenerateFormItemGroup();
	
	InformationText = "";
	If QuestionStructure.Property("InformationText", InformationText) Then	
		If Not IsBlankString(InformationText) Then 
			LabelName 		= FindLabelNameOnForm("QuestionLabel");
			LabelType		= Type("FormDecoration");
			LabelParent	= Group;
			
			InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
			InformationTextItem.Title = InformationText;
		EndIf;	
	EndIf;
	
	CheckBoxText = "";
	If QuestionStructure.Property("CheckBoxText", CheckBoxText) Then	
		If Not IsBlankString(CheckBoxText) Then 
			// Adding the attribute on the form.
			CheckBoxName 		= FindLabelNameOnForm("QuestionLabel");
			CheckBoxType		= Type("FormField");
			CheckBoxParent	= Group;
			
			TypeArray = New Array;
			TypeArray.Add(Type("Boolean"));
			Details = New TypeDescription(TypeArray);
			
			AttributesToAdd = New Array;
			NewAttribute 	= New FormAttribute(CheckBoxName, Details, , CheckBoxName, False);
			AttributesToAdd.Add(NewAttribute);
			ChangeAttributes(AttributesToAdd);
			ThisForm[CheckBoxName] = DefaultValue;
			
			NewFormField 						= Items.Add(CheckBoxName, CheckBoxType, CheckBoxParent);
			NewFormField.DataPath			= CheckBoxName;
			NewFormField.Title 			= CheckBoxText;
			NewFormField.Kind					= FormFieldType.CheckBoxField;
			NewFormField.TitleLocation	= FormItemTitleLocation.Right;
			
			// Initialization of an item in the array.
			ItemForm 		= Undefined;
			ActionStructure 	= Undefined;
			If QuestionStructure.Property("ActionIfMarked", ActionStructure) Then 
				If ActionStructure.Property("Form", ItemForm) Then 
					NewFormField.SetAction("OnChange", "ChangeFutureTaskArray");
					
					ArrayStructure = New Structure;
					ArrayStructure.Insert("Name", 			CheckBoxName);
					ArrayStructure.Insert("Form", 			ItemForm);
					ArrayStructure.Insert("Using", 	DefaultValue);
					
					FormParameters = Undefined;
					If ActionStructure.Property("FormParameters", FormParameters) Then
						ArrayStructure.Insert("FormParameters", FormParameters);
					EndIf;	
					
					TaskArrayToExecuteOnClose.Add(ArrayStructure);
				EndIf;
			EndIf;	
		EndIf;	
	EndIf;	
EndProcedure	

&AtServer
Procedure CreateFinalQuestion()
	Group 				= GenerateFormItemGroup();
	FinalQuestion = NStr("en = 'Are you sure you want to exit the application?'");
	
	LabelName 		= FindLabelNameOnForm("QuestionLabel");
	LabelType		= Type("FormDecoration");
	LabelParent	= Group;
	
	InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
	InformationTextItem.Title = FinalQuestion;
EndProcedure	

// Finds a label name on the form by the title.
// 
// Parameters:
// ItemTitle - title.
//
&AtServer
Function FindLabelNameOnForm(ItemTitle)
	Index = 0;
	SearchFlag = True;
	
	While SearchFlag Do 
		RowIndex = String(Format(Index, "NZ=-"));
		RowIndex = StrReplace(RowIndex, "-", "");
		Name = ItemTitle + RowIndex;
		
		FoundItem = Items.Find(Name);
		If FoundItem = Undefined Then 
			Return Name;	
		EndIf;	
		
		Index = Index + 1;
	EndDo;	
EndFunction	

&AtClient
Function TaskIDByName(ItemName)
	For Each ArrayItem In TaskArrayToExecuteOnClose Do
		Description = "";
		If ArrayItem.Value.Property("Name", Description) Then 
			If Not IsBlankString(Description) And Description = ItemName Then
				Return ArrayItem.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Executes necessary tasks.
//
&AtClient
Procedure ExecuteTasksOnClose()
	For Each ArrayItem In TaskArrayToExecuteOnClose Do
		Using = Undefined;
		If ArrayItem.Value.Property("Using", Using) Then 
			If TypeOf(Using) = Type("Boolean") Then 
				If Using = True Then 
					Form = Undefined;
					If ArrayItem.Value.Property("Form", Form) Then 
						FormParameters = Undefined;
						If ArrayItem.Value.Property("FormParameters", FormParameters) Then 
							OpenFormModal(Form, FormParameters); 
						EndIf;	
					EndIf;	
				EndIf;	
			EndIf;	
		EndIf;	
	EndDo;	
EndProcedure	

