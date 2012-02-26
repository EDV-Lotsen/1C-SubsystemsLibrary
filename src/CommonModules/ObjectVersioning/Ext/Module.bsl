

// Writes object version into information register
// Parameters
// Ref        - CatalogRef / DocumentRef - IB object ref
// ObjectVersionsNumber - Number - number of object versions
// DataStorage - ValueStorage - storage with IB object (serialized into Fast InfoSet)
//
Procedure WriteObjectVersion(Val Ref,
								Val ObjectVersionsNumber,
								Val DataStorage) Export
	
	SetPrivilegedMode(True);
	
	RecordManagerObjectVersions 				= InformationRegisters.ObjectVersions.CreateRecordManager();
	RecordManagerObjectVersions.Object          = Ref;
	RecordManagerObjectVersions.VersionDate     = CurrentDate();
	RecordManagerObjectVersions.ObjectVersion   = DataStorage;
	RecordManagerObjectVersions.VersionNo   	= Number(ObjectVersionsNumber) + 1;
	RecordManagerObjectVersions.VersionAuthor   = Users.AuthorizedUser();
	
	RecordManagerObjectVersions.Write();
	
EndProcedure

// Returns number of object versions passed by ref
// Parameters:
//   Object         - CatalogRef/DocumentRef - ref to IB object
// Value to return:
//   Number         - number of versions of object Object in the information register ObjectVersions
//
Function GetObjectVersionsCount(Ref) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT
	             |	COUNT(ObjectVersions.VersionNo) AS Quantity
	             |FROM
	             |	InformationRegister.ObjectVersions AS ObjectVersions
	             |WHERE
	             |	ObjectVersions.Object = &Ref";
	Query.SetParameter("Ref", Ref);
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Return Number(Selection.Quantity);
	
EndFunction

// Deletes object stored versions by ref Ref from the register ObjectVersions
//
Procedure DeleteStoredVersionsByObject(Ref) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.ObjectVersions.CreateRecordSet();
	RecordSet.Filter.Object.Use = True;
	RecordSet.Filter.Object.Value = Ref;
	RecordSet.Write();
	
EndProcedure

// Executed on configuration update.
// 1. Clears versioning settings by objects, for which versioning is not applied
// 2. Sets versioning settings by default
//
Procedure UpdateObjectVersioningSettings() Export
	
	VersioningObjects = GetVersioningObjects();
	
	RecordsSelection = InformationRegisters.ObjectVersioningSettings.Select();
	
	While RecordsSelection.Next() Do
		If VersioningObjects.Find(RecordsSelection.ObjectType) = Undefined Then
			RecordManager = RecordsSelection.GetRecordManager();
			RecordManager.Delete();
		EndIf;
	EndDo;
	
	// composite type of string and ref to the catalog Item.
	ArrayOfTypes = New Array;
	ArrayOfTypes.Add(Type("String"));
	
	VersioningObjectsVT = New ValueTable;
	VersioningObjectsVT.Columns.Add("ObjectType", 
				New TypeDescription(ArrayOfTypes, , Metadata.InformationRegisters.ObjectVersioningSettings.Dimensions.ObjectType.Type.StringQualifiers) );
	For Each ObjectType In VersioningObjects Do
		VersioningObjectsVT.Add();
	EndDo;
	VersioningObjectsVT.LoadColumn(VersioningObjects, "ObjectType");
	
	Query = New Query;
	Query.Text = "SELECT
	             |	VersioningObjects.ObjectType
	             |INTO VersioningObjectsTable
	             |FROM
	             |	&VersioningObjects AS VersioningObjects
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	VersioningObjectsTable.ObjectType
	             |FROM
	             |	VersioningObjectsTable AS VersioningObjectsTable
	             |		LEFT JOIN InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	             |		ON (ObjectVersioningSettings.ObjectType = VersioningObjectsTable.ObjectType)
	             |WHERE
	             |	ObjectVersioningSettings.Variant IS NULL ";
			
	Query.Parameters.Insert("VersioningObjects", VersioningObjectsVT);
	VersioningObjectsWithoutSettings = Query.Execute().Unload().UnloadColumn("ObjectType");
	
	RecordSetSettings = InformationRegisters.ObjectVersioningSettings.CreateRecordSet();
	RecordSetSettings.Read();
	For Each VersioningObject In VersioningObjectsWithoutSettings Do
		NewRecord = RecordSetSettings.Add();
		NewRecord.ObjectType = VersioningObject;
		NewRecord.Variant = GetVersioningSettingByDefault(VersioningObject);
		NewRecord.Use = ? (NewRecord.Variant = Enums.ObjectVersioningRules.DoNotVersion, False, True);
	EndDo;
	
	RecordSetSettings.Write(True);
	
EndProcedure

// Gets infobase objects, that can be used with versioning subsystem
// Value to return:
//   Array, array item - string, identifying metadata object in format
//                       Catalog.<Catalog name> or Document.<Document name>
//
Function GetVersioningObjects()
	
	Result = New Array;
	
	For Each MetadataItem In Metadata.Catalogs Do
		If Metadata.CommonCommands.ChangesHistory.CommandParameterType.ContainsType(
					Type("CatalogRef."+MetadataItem.Name)) Then
			Result.Add(MetadataItem.FullName());
		EndIf;
	EndDo;
	
	For Each MetadataItem In Metadata.Documents Do
		If Metadata.CommonCommands.ChangesHistory.CommandParameterType.ContainsType(
					Type("DocumentRef."+MetadataItem.Name)) Then
			Result.Add(MetadataItem.FullName());
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetVersioningSettingByDefault(FullName)
	
	DecomposedPath = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(FullName, ".");
	
	If	DecomposedPath[0] = "Documents" Then
		If Metadata.FindByFullName(FullName).Posting = Metadata.ObjectProperties.Posting.Allow Then
			Return Enums.ObjectVersioningRules.VersionOnPosting;
		Else
			Return Enums.ObjectVersioningRules.DoVersioning;
		EndIf
	EndIf;
	
	Return Enums.ObjectVersioningRules.DoNotVersion;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Block of functions for work with settings of values

// Writes object versioning setting into information register
//
Procedure WriteVersioningSettingByObject(
                                  Object,
                                  VersioningRule) Export
	
	VariantMB = InformationRegisters.ObjectVersioningSettings.CreateRecordManager();
	VariantMB.ObjectType = Object;
	VariantMB.Variant = VersioningRule;
	VariantMB.Write();
	
EndProcedure

// Performs actions, required to connect versioning subsystem, with the form
//
Procedure OnCreateAtServer(Form) Export
	
	If IsBlankString(InfobaseUsers.CurrentUser().Name) OR IsInRole(Metadata.Roles.FullAccess) Then
		FormNameArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Form.FormName, ".");
		FullMetadataName = FormNameArray[0] + "." + FormNameArray[1];
	Else
		FullMetadataName = Undefined;
	EndIf;
	
	Form.SetFormFunctionalOptionParameters(New Structure("ConfigurationObjectType", FullMetadataName));
	
EndProcedure
