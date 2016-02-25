//////////////////////////////////////////////////////////////////////////////// 
// HELPER PROCEDURES AND FUNCTIONS
//

&AtClient
Procedure ChooseSetting()

	If Items.SettingsList.CurrentRow <> Undefined Then 

		Close(New SettingsChoice(Items.SettingsList.CurrentData.Value));

	Else

		Close();

	EndIf;

EndProcedure

&AtServer
Procedure FillSettingsList()

	SettingsList = New ValueList;

	For Each Element In StandardSettings Do

		SettingsList.Add(Element.Value, Element.Presentation);

	EndDo;

	Query = New Query;
	Query.Text = "SELECT
	               |	ReportVariants.Code AS Code,
	               |	ReportVariants.Description AS Description
	               |FROM
	               |	Catalog.ReportVariants AS ReportVariants
	               |WHERE
	               |	ReportVariants.ObjectKey = &ObjectKey";

	Query.Parameters.Insert("ObjectKey", ObjectKey);

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();

	While Selection.Next() Do

		SettingsList.Add(Selection.Code, Selection.Description);

	EndDo;

	SettingsList.SortByPresentation();

EndProcedure

&AtServer
Procedure DeleteSetting(Key)

	ItemToDelete = Catalogs.ReportVariants.FindByCode(Key);

	If ItemToDelete <> Catalogs.ReportVariants.EmptyRef() Then

		ItemToDelete.GetObject().Delete();
		FillSettingsList();

	EndIf;

EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtClient
Procedure LoadExecute()

	ChooseSetting();

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	ObjectKey = Parameters.ObjectKey;
	CurrentSettingsKey = Parameters.CurrentSettingsKey;
	StandardSettings = Parameters.StandardSettings;

	FillSettingsList();

	Element = SettingsList.FindByValue(CurrentSettingsKey);
	If Element <> Undefined Then

		Items.SettingsList.CurrentRow = Element.GetID();

	EndIf;

EndProcedure

&AtClient
Procedure SettingsListBeforeRowChange(Element, Cancel)

	Cancel = True;

EndProcedure

&AtClient
Procedure SettingsListBeforeDelete(Element, Cancel)

	Cancel = True;

	If Items.SettingsList.CurrentRow <> Undefined Then

		If StandardSettings.FindByValue(SettingsList.FindByID(Items.SettingsList.CurrentRow).Value) <> Undefined Then

			ShowMessageBox(, NStr("en = 'The standard variant cannot be deleted.'"),Undefined);

		Else

			Notification = New NotifyDescription(
				"SettingsListBeforeDeleteQueryCompletion",
				ThisObject);

			ShowQueryBox(Notification,
				NStr("en = 'Do you wand to delete '")  + SettingsList.FindByID(Items.SettingsList.CurrentRow).Presentation +  "?",
				QuestionDialogMode.YesNo);

		EndIf;

	EndIf;

EndProcedure

&AtClient
Procedure  SettingsListBeforeDeleteQueryCompletion(Result,  Parameters)  Export
	If  Result =  DialogReturnCode.Yes  Then
		DeleteSetting(
			SettingsList.FindByID(
				Items.SettingsList.CurrentRow).Value);
	EndIf;
EndProcedure
&AtClient
Procedure SettingsListChoice(Element, SelectedRow, Field, StandardProcessing)

	StandardProcessing = False;
	ChooseSetting();

EndProcedure

&AtClient
Procedure SettingsListBeforeAddRow(Element, Cancel, Clone)

	Cancel = True;

EndProcedure
