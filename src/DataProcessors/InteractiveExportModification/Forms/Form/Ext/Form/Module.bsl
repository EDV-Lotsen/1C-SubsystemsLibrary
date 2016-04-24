
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If NOT Parameters.Property("OpenByScenario") Then
		Raise NStr("en='The data processor cannot be opened manually.'");
	EndIf;
	
	ThisDataProcessor = ThisObject();
	If IsBlankString(Parameters.ObjectAddress) Then
		ThisObject( ThisDataProcessor.InitializeThisObject(Parameters.ObjectSettings) );
	Else
		ThisObject( ThisDataProcessor.InitializeThisObject(Parameters.ObjectAddress) );
	EndIf;
	
	If Not ValueIsFilled(Object.InfobaseNode) Then
		Text = NStr("en='Data exchange settings item not found.'");
		DataExchangeServer.ReportError(Text, Cancel);
		Return;
	EndIf;
	
	Title = Title + " (" + Object.InfobaseNode + ")";
	BaseFormName = ThisDataProcessor.BaseFormName();
	
	CurrentSettingsItemPresentation = "";
	Items.FilterSettings.Visible = AccessRight("SaveUserData", Metadata);
	
	ResetTableCountLabel();
	UpdateTotalCountLabel();
EndProcedure

&AtClient
Procedure OnClose()
	StopCountCalculation();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

////////////////////////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS OF AdditionalRegistration FORM TABLE
//

&AtClient
Procedure AdditionalRegistrationChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Field <> Items.AdditionalRegistrationFilterString Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	CurrentData = Items.AdditionalRegistration.CurrentData;
	
	NameOfFormToOpen = BaseFormName + "Form.PeriodAndFilterEditing";
	FormParameters = New Structure;
	FormParameters.Insert("Title",             CurrentData.Presentation);
	FormParameters.Insert("ChoiceAction",      Items.AdditionalRegistration.CurrentRow);
	FormParameters.Insert("SelectPeriod",      CurrentData.SelectPeriod);
	FormParameters.Insert("SettingsComposer",  SettingsComposerByTableName(CurrentData.FullMetadataName, CurrentData.Presentation, CurrentData.Filter));
	FormParameters.Insert("DataPeriod",        CurrentData.Period);
	
	FormParameters.Insert("FromStorageAddress", UUID);
	
	OpenForm(NameOfFormToOpen, FormParameters, Items.AdditionalRegistration);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	Cancel = True;
	If Clone Then
		Return;
	EndIf;
	
	OpenForm(BaseFormName + "Form.NodeContentObjectKindSelection",
		New Structure("InfobaseNode", Object.InfobaseNode),
		Items.AdditionalRegistration);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeDelete(Item, Cancel)
	Selected = Items.AdditionalRegistration.SelectedRows;
	Count = Selected.Count();
	If Count>1 Then
		PresentationText = NStr("en='the selected rows'");
	ElsIf Count=1 Then
		PresentationText = Items.AdditionalRegistration.CurrentData.Presentation;
	Else
		Return;
	EndIf;
	
	// The AdditionalRegistrationBeforeDeleteEnd procedure is called from 
  // the user confirmation dialog
	Cancel = True;
	
	QuestionText = NStr("en='Delete %1 from additional data?'");    
	QuestionText = StrReplace(QuestionText, "%1", PresentationText);
	
	QuestionTitle = NStr("en='Confirmation'");
	
	Notification = New NotifyDescription("AdditionalRegistrationBeforeDeleteEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("SelectedRows", Selected);
	
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

&AtClient
Procedure AdditionalRegistrationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	StandardProcessing = False;
	
	SelectedValueType  = TypeOf(SelectedValue);
	If SelectedValueType = Type("Array") Then
		// Adding new row
		Items.AdditionalRegistration.CurrentRow = AddingRowToAdditionalContentServer(SelectedValue);
		
	ElsIf SelectedValueType = Type("Structure") Then
		If SelectedValue.ChoiceAction = 3 Then
			// Restoring settings
			SettingsItemPresentation = SelectedValue.SettingsItemPresentation;
			If Not IsBlankString(CurrentSettingsItemPresentation) And SettingsItemPresentation<>CurrentSettingsItemPresentation Then
				QuestionText  = NStr("en='Restore settings %1?'");
				QuestionText  = StrReplace(QuestionText, "%1", SettingsItemPresentation);
				TitleText = NStr("en='Confirmation'");
				
				Notification = New NotifyDescription("AdditionalRegistrationChoiceProcessingEnd", ThisObject, New Structure);
				Notification.AdditionalParameters.Insert("SettingsItemPresentation", SettingsItemPresentation);
				
				ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , TitleText);
			Else
				CurrentSettingsItemPresentation = SettingsItemPresentation;
			EndIf;
		Else
			// Editing filter condition, negative line number
			Items.AdditionalRegistration.CurrentRow = FilterStringEditingAdditionalContentServer(SelectedValue);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalRegistrationAfterDeleteLine(Item)
	UpdateTotalCountLabel();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConfirmSelection(Command)
	NotifyChoice( ChoiseResultServer() );
EndProcedure

&AtClient
Procedure ShowCommonParameterText(Command)
	OpenForm(BaseFormName +  "Form.CommonSynchronizationParameters",
		New Structure("InfobaseNode", Object.InfobaseNode));
EndProcedure

&AtClient
Procedure ExportContent(Command)
	OpenForm(BaseFormName + "Form.ExportContent",
		New Structure("ObjectAddress", AdditionalExportObjectAddress() ));
EndProcedure

&AtClient
Procedure UpdateCount(Command)
	RunCountCalculationAnimation();
	If UpdateCountServer() Then
		StopCountCalculationAnimation();
	Else
		AttachIdleHandler("Attachable_WaitCountCalculation", 3, True);
	EndIf;
EndProcedure

&AtClient
Procedure FilterSettings(Command)
	
	// Selecting from a list
	VariantList = ReadSettingsVariantListServer();
	
	Text = NStr("en='Save current settings...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	Notification = New NotifyDescription("FilterSettingsVariantSelectionEnd", ThisObject);
	
	ShowChooseFromMenu(Notification, VariantList, Items.FilterSettings);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure FilterSettingsVariantSelectionEnd(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingsItemPresentation = SelectedItem.Value;
	If TypeOf(SettingsItemPresentation)=Type("String") Then
		TitleText = NStr("en='Confirmation'");
		QuestionText   = NStr("en='Restore ""%1"" settings?'");
		QuestionText   = StrReplace(QuestionText, "%1", SettingsItemPresentation);
		
		Notification = New NotifyDescription("FilterSettingsCompletion", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("SettingsItemPresentation", SettingsItemPresentation);
		
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , TitleText);
		
	ElsIf SettingsItemPresentation=1 Then
		// Form that displays all settings
		OpenForm(BaseFormName + "Form.EditSettingsContent",
			New Structure("CloseOnChoice, ChoiceAction, Object, CurrentSettingsItemPresentation", 
				True, 3, 
				Object, CurrentSettingsItemPresentation
			), Items.AdditionalRegistration);
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterSettingsCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetSettingsServer(AdditionalParameters.SettingsItemPresentation);
EndProcedure

&AtClient
Procedure AdditionalRegistrationChoiceProcessingEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetSettingsServer(AdditionalParameters.SettingsItemPresentation);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeDeleteEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeletionTable = Object.AdditionalRegistration;
	For Each RowID In AdditionalParameters.SelectedRows Do
		RowToDelete = DeletionTable.FindByID(RowID);
		If RowToDelete<>Undefined Then
			DeletionTable.Delete(RowToDelete);
		EndIf;
	EndDo;
	
	UpdateTotalCountLabel();
EndProcedure

&AtServer
Function ChoiseResultServer()
	ObjectResult = New Structure("InfobaseNode, ExportVariant, AllDocumentsFilterComposer, AllDocumentsFilterPeriod");
	FillPropertyValues(ObjectResult, Object);
	
	ObjectResult.Insert("AdditionalRegistration", 
		TableIntoStrucrureArray( FormAttributeToValue("Object.AdditionalRegistration")) );
	
	Return New Structure("ChoiceAction, ObjectAddress", 
		Parameters.ChoiceAction, PutToTempStorage(ObjectResult, UUID)
	);
EndFunction

&AtServer
Function TableIntoStrucrureArray(Val ValueTable)
	Result = New Array;
	
	ColumnNames = "";
	For Each Column In ValueTable.Columns Do
		ColumnNames = ColumnNames + "," + Column.Name;
	EndDo;
	ColumnNames = Mid(ColumnNames, 2);
	
	For Each Row In ValueTable Do
		RowStructure = New Structure(ColumnNames);
		FillPropertyValues(RowStructure, Row);
		Result.Add(RowStructure);
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure Attachable_WaitCountCalculation()
	If LoadCountValues() Then
		StopCountCalculationAnimation();
	Else
		AttachIdleHandler("Attachable_WaitCountCalculation", 3, True);
	EndIf;
EndProcedure

&AtServer
Function ThisObject(NewObject=Undefined)
	If NewObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function AddingRowToAdditionalContentServer(ChoiseArray)
	
	If ChoiseArray.Count()=1 Then
		Row = AddToAdditionalExportContent(ChoiseArray[0]);
	Else
		Row = Undefined;
		For Each ChoiceItem In ChoiseArray Do
			TestRow = AddToAdditionalExportContent(ChoiceItem);
			If Row=Undefined Then
				Row = TestRow;
			EndIf;
		EndDo;
	EndIf;
	
	Return Row;
EndFunction

&AtServer 
Function FilterStringEditingAdditionalContentServer(ChoiceStructure)
	
	CurrentData = Object.AdditionalRegistration.FindByID(-ChoiceStructure.ChoiceAction);
	If CurrentData=Undefined Then
		Return Undefined
	EndIf;
	
	CurrentData.Period       = ChoiceStructure.DataPeriod;
	CurrentData.Filter       = ChoiceStructure.SettingsComposer.Settings.Filter;
	CurrentData.FilterString = FilterPresentation(CurrentData.Period, CurrentData.Filter);
	CurrentData.Count   = NStr("en='Not calculated'");
	
	UpdateTotalCountLabel();
	
	Return ChoiceStructure.ChoiceAction;
EndFunction

&AtServer
Function AddToAdditionalExportContent(Item)
	
	ExistingRows = Object.AdditionalRegistration.FindRows( 
		New Structure("FullMetadataName", Item.FullMetadataName));
	If ExistingRows.Count()>0 Then
		Row = ExistingRows[0];
	Else
		Row = Object.AdditionalRegistration.Add();
		FillPropertyValues(Row, Item,,"Presentation");
		
		Row.Presentation = Item.ListPresentation;
		Row.FilterString  = FilterPresentation(Row.Period, Row.Filter);
		Object.AdditionalRegistration.Sort("Presentation");
		
		Row.Count = NStr("en='Not calculated'");
		UpdateTotalCountLabel();
	EndIf;
	
	Return Row.GetID();
EndFunction

&AtServer
Function FilterPresentation(Period, Filter)
	Return ThisObject().FilterPresentation(Period, Filter);
EndFunction

&AtServer
Function SettingsComposerByTableName(TableName, Presentation, Filter)
	Return ThisObject().SettingsComposerByTableName(TableName, Presentation, Filter, UUID);
EndFunction

&AtClient
Procedure RunCountCalculationAnimation()
	Items.CountCalculationPicture.Visible = True;
EndProcedure

&AtClient
Procedure StopCountCalculationAnimation()
	Items.CountCalculationPicture.Visible = False;
EndProcedure

&AtServer
Procedure StopCountCalculationAnimationServer()
	Items.CountCalculationPicture.Visible = False;
EndProcedure

&AtServer
Procedure StopCountCalculation()
	
	DataExchangeServer.CancelBackgroundJob(BackgroundJobID);
	If Not IsBlankString(BackgroundJobResultAddress) Then
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	
	BackgroundJobResultAddress = "";
	BackgroundJobID            = Undefined;
	
EndProcedure

&AtServer
Function UpdateCountServer()
	
	StopCountCalculation();
	
 // Initializing new background generation. The progress is monitored from
 // the idle handler.
	BackgroundJobResultAddress = PutToTempStorage(Undefined, ThisObject.UUID);
	BackgroundJobID = ThisObject().ValueTreeBackgroundGeneration(BackgroundJobResultAddress);
	If DataExchangeServer.BackgroundJobCompleted(BackgroundJobID) Then
		Return LoadCountValues();
	EndIf;
	
	Return False;
EndFunction

&AtServer
Function LoadCountValues()
	
	If Not DataExchangeServer.BackgroundJobCompleted(BackgroundJobID) Then
		Return False;
	EndIf;
	
	CountTree = Undefined;
	If Not IsBlankString(BackgroundJobResultAddress) Then
		CountTree = GetFromTempStorage(BackgroundJobResultAddress);
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	If TypeOf(CountTree)<>Type("ValueTree") Then
		CountTree = New ValueTree;
	EndIf;
	
	If CountTree.Rows.Count()=0 Then
		UpdateTotalCountLabel(Undefined);
		Return True;
	EndIf;
	
	ThisDataProcessor = ThisObject();
	
	CountRows = CountTree.Rows;
	For Each Row In Object.AdditionalRegistration Do
		
		CountToExport = 0;
		CountTotal    = 0;
		StringContent = ThisDataProcessor.EnlargedMetadataGroupContent(Row.FullMetadataName);
		For Each TableName In StringContent Do
			DataRow = CountRows.Find(TableName, "FullMetadataName", False);
			If DataRow <> Undefined Then
				CountToExport = CountToExport + DataRow.CountToExport;
				CountTotal    = CountTotal     + DataRow.TotalCount;
			EndIf;
		EndDo;
		
		Row.Count = Format(CountToExport, "NZ=") + " / " + Format(CountTotal, "NZ=");
	EndDo;
	
	// Totals
	DataRow = CountRows.Find(Undefined, "FullMetadataName", False);
	UpdateTotalCountLabel(?(DataRow=Undefined, Undefined, DataRow.CountToExport));
	
	Return True;
EndFunction

&AtServer
Procedure UpdateTotalCountLabel(Count=Undefined) 
	
	StopCountCalculation();
	
	If Count=Undefined Then
		CountText = NStr("en='<not calculated>'");
	Else
		CountText = NStr("en='%1 object(s)'");
		CountText = StrReplace(CountText, "%1", Format(Count, "NZ="));
	EndIf;
	
	Items.UpdateCount.Title  = CountText;
EndProcedure

&AtServer
Procedure ResetTableCountLabel()
	CountsText = NStr("en='Not calculated'");
	For Each Row In Object.AdditionalRegistration Do
		Row.Count = CountsText;
	EndDo;
	StopCountCalculationAnimationServer();
EndProcedure

&AtServer
Function ReadSettingsVariantListServer()
	VariantFilter = New Array;
	VariantFilter.Add(Object.ExportVariant);
	
	Return ThisObject().ReadSettingsListPresentations(Object.InfobaseNode, VariantFilter);
EndFunction

&AtServer
Procedure SetSettingsServer(SettingsItemPresentation)
	
	ConstantData = New Structure("InfobaseNode, ExportVariant, AllDocumentsFilterComposer, AllDocumentsFilterPeriod");
	FillPropertyValues(ConstantData, Object);
	
	ThisDataProcessor = ThisObject();
	ThisDataProcessor.RestoreCurrentAttributesFromSettings(SettingsItemPresentation);
	ThisObject(ThisDataProcessor);
	
	FillPropertyValues(Object, ConstantData);
	ExportAdditionSettingsPresentation = SettingsItemPresentation;
	
	ResetTableCountLabel();
	UpdateTotalCountLabel();
EndProcedure

&AtServer
Function AdditionalExportObjectAddress()
	Return ThisObject().SaveThisObject(UUID);
EndFunction

#EndRegion
