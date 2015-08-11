

// Procedure updates information in settings table.
//
Procedure FillTree()

	SettingsItems = SettingsTree.GetItems();
	SettingsItems.Clear();

	Query = New Query;
	Query.SetParameter("User", User);
	Query.Text=
	"SELECT
	|	Settings.Parent,
	|	Settings.Ref,
	|	Settings.IsFolder AS IsFolder,
	|	(NOT Settings.IsFolder) AS PictureNo,
	|	SettingsValue.Value,
	|	Constants.FunctionalOptionMultipleCompanies
	|FROM
	|	ChartOfCharacteristicTypes.UsersSettings AS Settings
	|		LEFT JOIN InformationRegister.UsersSettings AS SettingsValue
	|		ON (SettingsValue.Options = Settings.Ref)
	|			And (SettingsValue.User = &User),
	|	Constants AS Constants
	|WHERE
	|	Settings.DeletionMark = FALSE
	|	And CASE
	|			WHEN Settings.Ref = VALUE(ChartOfCharacteristicTypes.UsersSettings.MainCompany)
	|					And (NOT Constants.FunctionalOptionMultipleCompanies)
	|				THEN FALSE
	|			ELSE TRUE
	|		END
	|
	|ORDER BY
	|	IsFolder HIERARCHY,
	|	Settings.Description";
	
	Selection = Query.Execute().Select();
	
	AddedGroupsArray = New Array;
	
	While Selection.Next() Do
		
		If Selection.IsFolder Then
			GroupRow 				= SettingsItems;
			SettingRow 				= GroupRow.Add();
			SettingRow.Options 		= Selection.Ref;
			SettingRow.IsFolder 	= Selection.IsFolder;
			SettingRow.PictureNo 	= Selection.PictureNo;
			GroupRowItems 			= SettingRow.GetItems();
		Else
			SettingRow 				= GroupRowItems.Add();
			SettingRow.Options 		= Selection.Ref;
			SettingRow.Value  		= Selection.Ref.ValueType.AdjustValue(Selection.Value);
			SettingRow.IsFolder 	= Selection.IsFolder;
			SettingRow.PictureNo 	= Selection.PictureNo;
        EndIf;
		
	EndDo;

EndProcedure // FillTree()

// Procedure writes settings values into the information register.
//
Procedure UpdateSettings()

	RecordSet = InformationRegisters.UsersSettings.CreateRecordSet();

	RecordSet.Filter.User.Use 		= True;
	RecordSet.Filter.User.Value     = User;
	
	GroupSettings = SettingsTree.GetItems();
	For Each SettingsGroup In GroupSettings Do
		
		SettingsItems = SettingsGroup.GetItems();
		
		For Each SettingsRow In SettingsItems Do
			
			Record = RecordSet.Add();

			Record.User 	= User;
			Record.Options  = SettingsRow.Options;
			Record.Value   	= SettingsRow.Options.ValueType.AdjustValue(SettingsRow.Value);

		EndDo;
		
	EndDo;
	
	RecordSet.Write();

EndProcedure // UpdateSettings()

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.Property("User") Then
		
		User = Parameters.User;
		
		If ValueIsFilled(User) Then
			
			FillTree();	
			
		EndIf;
		                        
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure OnClose()
	
	UpdateSettings();
	
EndProcedure // OnClose()
   
&AtClient
Procedure SettingsTreeBeforeRowChange(Item, Cancellation)
	
	If Item.CurrentData = Undefined OR Item.CurrentData.IsFolder Then
		
		Cancellation = True;
		Return;
		
	EndIf;
	
EndProcedure

