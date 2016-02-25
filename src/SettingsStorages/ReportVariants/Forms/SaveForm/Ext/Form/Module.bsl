//////////////////////////////////////////////////////////////////////////////// 
// AUXILIARY PROCEDURES AND FUNCTIONS
//

&AtServer
Function FindSettingByName(SavingSettingName)

	Query = New Query;
	Query.Text = "SELECT
	               |	ReportVariants.Code AS Code
	               |FROM
	               |	Catalog.ReportVariants AS ReportVariants
	               |WHERE
	               |	ReportVariants.ObjectKey = &ObjectKey
	               |	AND ReportVariants.Description = &Description";

	Query.Parameters.Insert("ObjectKey", ObjectKey);
	Query.Parameters.Insert("Description", SavingSettingName);
	QueryResult = Query.Execute();

	If QueryResult.IsEmpty() Then

		Return Undefined;

	Else

		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.Code;

	EndIf;

EndFunction

&AtServer
Function CreateNewSetup(SettingName)

	Element = Catalogs.ReportVariants.CreateItem();
	Element.ObjectKey = ObjectKey;
	Element.Description = SettingName;
	Element.Write();
	Return Element.Code;

EndFunction

&AtClient
Procedure ChooseSavingSetting()

	SavedSettingCode = FindSettingByName(SavingSettingName);

	// Already was a setting with this name.
	If SavedSettingCode <> Undefined Then

		// Ask the user whether to replace the setting.
		QuestionText = NStr("en = 'Replace variant ""%1""?'");
		QuestionText = StrReplace(QuestionText, "%1", SavingSettingName);
		Notification =  New NotifyDescription(

			"SelectSettingToSaveQueryCompletion",
			ThisObject,
			SavedSettingCode);
		ShowQueryBox(Notification,  QuestionText,  QuestionDialogMode.YesNo);
		Return;
	Else

		// There is no setting with this name - creating a new
		SavedSettingCode = CreateNewSetup(SavingSettingName)

	EndIf;

	Close(New SettingsChoice(SavedSettingCode));

EndProcedure

&AtClient

Procedure  SelectSettingToSaveQueryCompletion(Result,  SavedSettingCode)  Export
	If  Result =  DialogReturnCode.Yes  Then
		Close(New  SettingsChoice(SavedSettingCode));
	EndIf;
EndProcedure

&AtServer
Procedure DeleteSetting(Ref)

	Ref.GetObject().Delete();

EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	Var CurrentSettingsKey;
	
	Initialization = True;

	ObjectKey = Parameters.ObjectKey;
	CurrentSettingsKey = Parameters.CurrentSettingsKey;

	SettingsList.Parameters.SetParameterValue("ObjectKey", ObjectKey);

	Element = Catalogs.ReportVariants.FindByCode(CurrentSettingsKey);

	If Element <> Catalogs.ReportVariants.EmptyRef() Then

		Items.SettingsList.CurrentRow = Element;
		SavingSettingName = Element.Description;
		
	Else
		// A variant is not found. Creating a new variant name
		VariantIndex = 1;
		While True Do
			
			SavingSettingName = "Variety";
			
			If VariantIndex <> 1 Then
				
				SavingSettingName = SavingSettingName + " " + String(VariantIndex);
				
			EndIf;
			
			If Catalogs.ReportVariants.FindByDescription(SavingSettingName) = Catalogs.ReportVariants.EmptyRef() Then
				// No such variant name
				
				Break;
				
			EndIf;
			
			VariantIndex = VariantIndex + 1;
			
		EndDo;

	EndIf;

EndProcedure

&AtClient
Procedure SettingsListOnActivateRow(Element)

	If Not Initialization Then
		
		If Element.CurrentData <> Undefined Then

			SavingSettingName = Element.CurrentData.Description;

		Else

			SavingSettingName = "";

		EndIf;
		
	Else
		
		Initialization = False;
		
	EndIf;

EndProcedure

&AtClient
Procedure SaveExecute()

	ChooseSavingSetting();

EndProcedure

&AtClient
Procedure SettingsListChoice(Element, SelectedRow, Field, StandardProcessing)

	StandardProcessing = False;
	ChooseSavingSetting();

EndProcedure

&AtClient
Procedure SettingsListBeforeRowChange(Element, Cancel)

	Cancel = True;

EndProcedure

&AtClient
Procedure SettingsListBeforeDelete(Element, Cancel)

	Cancel = True;

	If Items.SettingsList.CurrentRow <> Undefined Then

		Notification = New  NotifyDescription(

			"SettingsListBeforeDeleteQueryCompletion",
			ThisObject);
		ShowQueryBox(Notification,
			NStr("en = 'Do you want to delete '") + Items.SettingsList.CurrentData.Description + "?",
			QuestionDialogMode.YesNo);
	EndIf;

EndProcedure

&AtClient
Procedure  SettingsListBeforeDeleteQueryCompletion(Result) Export
	If Result =  DialogReturnCode.Yes Then
		DeleteSetting(Items.SettingsList.CurrentRow);
		Items.SettingsList.Refresh();
	EndIf;
EndProcedure

&AtClient
Procedure SettingsListBeforeAddRow(Element, Cancel, Clone)

	Cancel = True;

EndProcedure



