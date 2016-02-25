////////////////////////////////////////////////////////////////////////////////
// Data import/export subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL EVENT HANDLERS

Procedure ExportInfobaseUserSettings(Container) Export
	
	ExportUserPlatformSettings(Container);
	WriteFavoritesURLs(Container);
	
EndProcedure

Procedure OnSubstituteURL(Container, ReferenceMap) Export
	
	SubstituteURLsInFavoritesFile(Container, ReferenceMap);
	
EndProcedure

Procedure ImportInfobaseUserSettings(Container) Export
	
	ImportUserSettingsAdjustedForModifiedFavorites(Container);
	
EndProcedure

// Export settings

Procedure ExportUserPlatformSettings(Container)
	
	ExportUserSettings(Container, "CommonSettingsStorage");
	ExportUserSettings(Container, "SystemSettingsStorage", False);
	ExportUserSettings(Container, "ReportsUserSettingsStorage");
	ExportUserSettings(Container, "ReportVariantsStorage");
	ExportUserSettings(Container, "FormDataSettingsStorage");
	
	If CTLAndSLIntegration.IsPlatform83WithoutCompatibilityMode() Then
		ExportUserSettings(Container, "DynamicListsUserSettingsStorage");
	EndIf;
	
EndProcedure

Procedure ExportUserSettings(Container, Val SettingsStorageName, Val SkipCheck = True)
	
	If SkipCheck Then 
		If Metadata[SettingsStorageName] <> Undefined Then 
			Return;
		EndIf;
	EndIf;
	
	FileName = Container.CreateFile(DataExportImportInternal.UserSettings(), SettingsStorageName);
	
	RecordStream = New XMLWriter();
	RecordStream.OpenFile(FileName);
	
	SettingsStorage = Eval(SettingsStorageName);
	
	SettingsTable  = DetermineSettingsTable();
	ItemCount      = 0;
	TotalItemCount = 0;
	
	SettingsSelection = SettingsStorage.Select();
	While SettingsSelection.Next() Do 
		
		Array = New Array;
		
		ItemCount = ItemCount + 1;
		Try
			Settings = SettingsSelection.Settings;
			TestRecord = New XMLWriter;
			TestRecord.SetString();
			XDTOSerializer.WriteXML(TestRecord, Settings);
			SettingsSubstitution = Undefined;
		Except
			SettingsSubstitution = New ValueStorage(Settings);
		EndTry;
		TestRecord.Close();
		
		If ItemCount >= ExportedValueTableMaximumSize() Then 
			
			TotalItemCount = TotalItemCount + ItemCount;
			DataExportImportInternal.WriteObjectToStream(New Structure("Storage, Table", SettingsStorageName, SettingsTable), RecordStream);
			ItemCount = 1;
			SettingsTable.Clear();
			
		EndIf;
		
		NewRow = SettingsTable.Add();
		FillPropertyValues(NewRow, SettingsSelection);
		
		If SettingsSubstitution <> Undefined Then 
			NewRow.Settings = SettingsSubstitution;
		EndIf;
		
	EndDo;
	
	TotalItemCount = TotalItemCount + ItemCount;
	DataExportImportInternal.WriteObjectToStream(New Structure("Storage, Table", SettingsStorageName, SettingsTable), RecordStream);
	Container.SetObjectAndRecordCount(FileName, TotalItemCount);
	
	RecordStream.Close();
	
	ItemCount = 1;
	SettingsTable.Clear();
	
EndProcedure

Function DetermineSettingsTable()
	
	Table = New ValueTable;
	
	Table.Columns.Add("ObjectKey",    New TypeDescription("String"));
	Table.Columns.Add("SettingsKey",  New TypeDescription("String"));
	Table.Columns.Add("Settings");
	Table.Columns.Add("User",         New TypeDescription("String"));
	Table.Columns.Add("Presentation", New TypeDescription("String"));
	
	Return Table;
	
EndFunction

Function ExportedValueTableMaximumSize()
	
	Return 10000;
	
EndFunction

Procedure WriteFavoritesURLs(Container)
	
	FileName = Container.GetFileFromDirectory(DataExportImportInternal.UserSettings(), "SystemSettingsStorage");
	If FileName = Undefined Then 
		Return;
	EndIf;
	
	URLMap = New Map;
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(FileName);
	ReaderStream.MoveToContent();
	
	While ReaderStream.NodeType <> XMLNodeType.StartElement Do
		
		SettingsTable = DataExportImportInternal.ReadObjectFromStream(ReaderStream).Table;
		
		For Each Settings In SettingsTable Do 
			
			If TypeOf(Settings.Settings) = Type("ValueStorage") Then 
				Settings = Settings.Settings.Get();
			Else
				Settings = Settings.Settings;
			EndIf;
			
			SettingsDescription = New SettingsDescription;
			SettingsDescription.Presentation = Settings.Presentation;
			
			If TypeOf(Settings) = Type("UserWorkFavorites") Then 
				
				WriteFavoritesURLsToMap(URLMap, Settings, Settings.User);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	FileName = Container.CreateArbitraryFile("xml", "1cFresh\History");
	DataExportImportInternal.WriteObjectToFile(URLMap, FileName);
	Container.SetObjectAndRecordCount(FileName, URLMap.Count());
	
EndProcedure

Procedure WriteFavoritesURLsToMap(Val URLMap, Val Settings, Val User)
	
	If Settings.Count() = 0 Then 
		Return;
	EndIf;
	
	RefArray = New Array;
	
	For Each FavoritesItem In Settings Do 
		RefArray.Add(FavoritesItem.URL);
	EndDo;
	
	URLMap.Insert(User, RefArray);
	
EndProcedure

// On URL substitution

// Substitutes URLs.
// 
// Parameters:
//  CommonURLMap - Map, Key: Metadata object, Value - ValueTable.
Procedure SubstituteURLsInFavoritesFile(Container, Val CommonURLMap) Export
	
	PathToFile = Container.GetArbitraryFile("1cFresh\History");
	
	Map = DataExportImportInternal.ReadObjectFromFile(PathToFile);
	
	SubstitutedMap = New Map;
	
	ColumnName = DataExportImportInternal.SourceURLColumnName(Container);
	
	For Each CurrentMap In Map Do 
		
		SubstitutedArray = New Array;
		User = CurrentMap.Key;
		
		For Each URL In CurrentMap.Value Do 
			
			URLSubstitution(URL, CommonURLMap, ColumnName);
			
			SubstitutedArray.Add(URL);
			
		EndDo;
		
		SubstitutedMap.Insert(User, SubstitutedArray);
		
	EndDo;
	
	DataExportImportInternal.WriteObjectToFile(SubstitutedMap, PathToFile);
	
EndProcedure

Procedure URLSubstitution(Val URL, Val CommonURLMap, Val ColumnName)
	
	MetadataFullName = MetadataFullNameFromURL(URL);
	If MetadataFullName = Undefined Then 
		Return;
	EndIf;
	
	IDString = GetIDString(URL);
	If IDString = Undefined Then 
		Return;
	EndIf;
	
	NormalizedID = GetUUIDByString(IDString);
	If NormalizedID = Undefined Then 
		Return;
	EndIf;
	
	URLTable = CommonURLMap.Get(MetadataFullName);
	If URLTable = Undefined Then 
		Return;
	EndIf;
	
	Filter = New Structure(ColumnName, NormalizedID);
	RowArray = URLTable.FindRows(Filter);
	If RowArray.Count() = 0 Then 
		Return;
	EndIf;
	
	For Each TableRow In RowArray Do 
		
		URLID = TableRow.Ref.UUID();
		NormalizedString = GetStringByID(URLID);
		If NormalizedString = Undefined Then 
			Continue;
		EndIf;
		
		URL = StrReplace(URL, IDString, NormalizedString);
		
	EndDo;
	
EndProcedure

Function MetadataFullNameFromURL(Val URL)
	
	TypeBeginning = "e1cib/data/";
	StartPosition = Find(URL, TypeBeginning);
	If StartPosition = 0 Then 
		Return Undefined;
	EndIf;
	
	StringSlice = Mid(URL, StartPosition + StrLen(TypeBeginning));
	Separator = "?";
	SeparatorPosition = Find(StringSlice, Separator);
	If SeparatorPosition = 0 Then 
		Return Undefined;
	EndIf;
																												  
	BeginningPosition = 1;
	Return Mid(StringSlice, BeginningPosition, SeparatorPosition - BeginningPosition)
	
EndFunction

Function GetIDString(Val URL)
	
	URLParameterName = "ref=";
	ParameterPosition = Find(URL, URLParameterName);
	If ParameterPosition = 0 Then 
		Return Undefined;
	EndIf;
	
	StringSlice = Mid(URL, ParameterPosition + StrLen(URLParameterName), 32);
	
	If StrLen(StringSlice) <> 32 Then 
		Return Undefined;
	EndIf;
	
	Return StringSlice;
	
EndFunction

Function GetUUIDByString(Val NormalizedURL)
	
	FirstPart    = Mid(NormalizedURL, 25, 8);
	SecondPart    = Mid(NormalizedURL, 21, 4);
	ThirdPart    = Mid(NormalizedURL, 17, 4);
	FourthPart = Mid(NormalizedURL, 1,  4);
	FifthPart     = Mid(NormalizedURL, 5,  12);
	
	ConcatenatedString = FirstPart + "-" + SecondPart + "-" + ThirdPart + "-" + FourthPart + "-" + FifthPart;
	
	If Not CTLAndSLIntegration.IsUUID(ConcatenatedString) Then 
		Return Undefined;
	EndIf;
	
	Return ConcatenatedString;
	
EndFunction

Function GetStringByID(Val URLID)
	
	URLID = String(URLID);
	
	Return Mid(URLID, 20, 4)
		+ Mid(URLID, 25)
		+ Mid(URLID, 15, 4)
		+ Mid(URLID, 10, 4)
		+ Mid(URLID, 1, 8);
	
EndFunction

// Data import

// Reads settings.
//
Procedure ImportUserSettingsAdjustedForModifiedFavorites(Container) Export
	
	PathToFile = Container.GetArbitraryFile("1cFresh\History");
	URLMap = DataExportImportInternal.ReadObjectFromFile(PathToFile);
	
	SettingsFiles = Container.GetFilesFromDirectory(DataExportImportInternal.UserSettings());
	
	For Each SettingsFile In SettingsFiles Do 
		
		ImportUserSettings(Container, SettingsFile, URLMap);
		
	EndDo;
	
EndProcedure

Procedure ImportUserSettings(Val Context, Val PathToFile, Val URLMap)
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(PathToFile);
	ReaderStream.MoveToContent();
	
	While ReaderStream.NodeType <> XMLNodeType.StartElement Do
		
		SavedSettings = DataExportImportInternal.ReadObjectFromStream(ReaderStream);
		StorageManager = Eval(SavedSettings.Storage);
		SettingsTable = SavedSettings.Table;
		
		ImportSettingsFromTable(StorageManager, SettingsTable, URLMap);
		
	EndDo;
	
EndProcedure

Procedure ImportSettingsFromTable(Val StorageManager, Val SettingsTable, Val URLMap)
	
	For Each Settings In SettingsTable Do 
		
		If TypeOf(Settings.Settings) = Type("ValueStorage") Then 
			Settings = Settings.Settings.Get();
		Else
			Settings = Settings.Settings;
		EndIf;
		
		SettingsDescription = New SettingsDescription;
		SettingsDescription.Presentation = Settings.Presentation;
		
		If TypeOf(Settings) = Type("UserWorkFavorites") Then 
			
			SubstituteURLs(Settings.User, Settings, URLMap);
			
		EndIf;
		
		StorageManager.Save(Settings.ObjectKey, Settings.SettingsKey, Settings, SettingsDescription, Settings.User);
		
	EndDo;
	
EndProcedure

Procedure SubstituteURLs(Val User, Val Settings, Val URLMap)
	
	RefArray = URLMap.Get(User);
	If RefArray = Undefined Then 
		Return;
	EndIf;
	
	For Iteration = 0 To RefArray.Count() - 1 Do 
		
		Settings[Iteration].URL = RefArray[Iteration];
		
	EndDo;
	
EndProcedure







