Procedure LoadProcessing(ObjectKey, SettingsKey, Setting, SettingDetails, User)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	ReportVariants.ReportVariant,
	             |	ReportVariants.Description
	             |FROM
	             |	Catalog.ReportVariants AS ReportVariants
	             |WHERE
	             |	ReportVariants.ObjectKey = &ObjectKey
	             |	AND ReportVariants.Code = &Code";
				   
	Query.Parameters.Insert("ObjectKey", ObjectKey);
	Query.Parameters.Insert("Code", SettingsKey);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		Setting = Selection.ReportVariant.Get();
		
		If SettingDetails <> Undefined Then
			
			SettingDetails.Presentation = Selection.Description;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SaveProcessing(ObjectKey, SettingsKey, Setting, SettingDetails, User)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	ReportVariants.Ref
	             |FROM
	             |	Catalog.ReportVariants AS ReportVariants
	             |WHERE
	             |	ReportVariants.ObjectKey = &ObjectKey
	             |	AND ReportVariants.Code = &Code";
				   
	Query.Parameters.Insert("ObjectKey", ObjectKey);
	Query.Parameters.Insert("Code", SettingsKey);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		SettingObject = Selection.Ref.GetObject();
		SettingObject.ReportVariant = New ValueStorage(Setting, New Deflation());
		
		If SettingDetails <> Undefined Then
			
			SettingObject.Name = SettingDetails.Presentation;
			
		EndIf;
		
		SettingObject.Write();
		
	EndIf;
	
EndProcedure

Procedure GetDescriptionProcessing(ObjectKey, SettingsKey, SettingDetails, User)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	ReportVariants.Description AS Description
	             |FROM
	             |	Catalog.ReportVariants AS ReportVariants
	             |WHERE
	             |	ReportVariants.ObjectKey = &ObjectKey
	             |	AND ReportVariants.Code = &Code";
				   
	Query.Parameters.Insert("ObjectKey", ObjectKey);
	Query.Parameters.Insert("Code", SettingsKey);
	
	SettingDetails.ObjectKey = ObjectKey;
	SettingDetails.SettingsKey = SettingsKey;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		SettingDetails.Presentation = Selection.Description;
		
	EndIf;
	
EndProcedure

Procedure SetDescriptionProcessing(ObjectKey, SettingsKey, SettingDetails, User)
	
	Var SettingObject;
	
	SettingDetails.ObjectKey = ObjectKey;
	SettingDetails.SettingsKey = SettingsKey;
	
	If SettingsKey <> Undefined Then
		
		Query = New Query;
		Query.Text = "SELECT
		               |	ReportVariants.Ref
		               |FROM
		               |	Catalog.ReportVariants AS ReportVariants
		               |WHERE
		               |	ReportVariants.ObjectKey = &ObjectKey
		               |	AND ReportVariants.Code = &Code";
					   
		Query.Parameters.Insert("ObjectKey", ObjectKey);
		Query.Parameters.Insert("Code", SettingsKey);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			Selection.Next();
			SettingObject = Selection.Ref.GetObject();
			
		EndIf;
		
	Else
		
		SettingObject = Catalogs.ReportVariants.CreateItem();
		SettingObject.ObjectKey = SettingDetails.ObjectKey;
		SettingObject.SetNewCode();
		SettingDetails.SettingsKey = SettingObject.Code;
		
	EndIf;
	
	If SettingObject <> Undefined Then
		
		SettingObject.Name = SettingDetails.Presentation;
		SettingObject.Write();
		
	EndIf;
	
EndProcedure

