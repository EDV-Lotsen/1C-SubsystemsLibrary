

// Checks availablity of address classifier updates at web server
// for those objects which were loaded previously. Those objects
// have record in AddressClassifierUnitVersions register.
//
// Parameters:
//	No.
//
// Returns:
//  Array of structures, where each structure has following format:
//  	AddressClassifierUnitCode - String - address unit code
//  	Description       - String - description of address unit
//  	Abbreviation         	  - String - abbreviation of address unit
//  	PostalCode        - String - postal code of address unit
//  	UpdateIsAvailable - Boolean
//
Function CheckAddressClassifierUpdatesServer() Export
	
	Return AddressClassifierClientServer.CheckAddressClassifierUpdate();
	
EndFunction

// Returns version of address units, saved on last update
// If there is no record about address unit, 09/01/2008 date is returned
//
// Parameters:
//	No.
//
// Returns:
//  Array of maps where: 
//		Key - address unit code, 
//		value - version issue date
//
Function GetAddressClassifierUnitsVersions() Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	AddressClassifierUnitVersions.Unit,
	             |	AddressClassifierUnitVersions.VersionIssueDate
	             |FROM
	             |	InformationRegister.AddressClassifierUnitVersions AS AddressClassifierUnitVersions";
	
	QuerySelection = Query.Execute().Choose();
	
	Result = New Map;
	
	While QuerySelection.Next() Do
		Result.Insert(QuerySelection.Unit, QuerySelection.VersionIssueDate);
	EndDo;
	
	Return Result;
	
EndFunction

//////////////////////////////////////////////////////////////////////////////// 
// Block of export functions, implementing  loading and clearing of address data
// in AddressClassifier information register
//

// Procedure for loading data to the Address Classifier
//
// Parameters:
//  AddressClassifierUnitCode - String  - address unit code in 2-digits format
//  DataPathAtServer  - String  - path to directory at server, where the classifier
//								  files are stored
//  LoadFromWeb       - Boolean - if True, data is loaded from the web server
//
// Returns:
//	No.
//
Procedure LoadClassifierByAddressUnit(Val AddressClassifierUnitCode,
                                        DataPathAtServer,
                                        LoadFromWeb) Export
	
	AddressClassifierUnitCode = Left(AddressClassifierUnitCode, 2);
	
	AlternativeNames = New ValueTable;
	AlternativeNames.Columns.Add("Code");
	AlternativeNames.Columns.Add("Description");
	AlternativeNames.Columns.Add("Abbreviation");
	AlternativeNames.Columns.Add("PostalCode");
	
	AddressInfo = New ValueTable;
	AddressInfo.Columns.Add("Code");
	AddressInfo.Columns.Add("AddressClassifierUnitCodeInCode");
	AddressInfo.Columns.Add("Description");
	AddressInfo.Columns.Add("AlternativeNames");
	AddressInfo.Columns.Add("Abbreviation");
	AddressInfo.Columns.Add("PostalCode");
	AddressInfo.Columns.Add("AddressItemType");
	AddressInfo.Columns.Add("ProvinceCodeInCode");
	AddressInfo.Columns.Add("CityCodeInCode");
	AddressInfo.Columns.Add("DistrictCodeInCode");
	AddressInfo.Columns.Add("StreetCodeInCode");
	
	Postfix = ? (LoadFromWeb, AddressClassifierUnitCode, "");
	
	LoadAddressInfo(AddressClassifierUnitCode,
	                DataPathAtServer + "classf"+Postfix,
	                AddressInfo,
	                AlternativeNames);
	
	LoadAddressInfo(AddressClassifierUnitCode,
	                DataPathAtServer + "street"+Postfix,
	                AddressInfo,
	                AlternativeNames,
	                5);
	
	LoadAddressInfo(AddressClassifierUnitCode,
	                DataPathAtServer + "build"+Postfix,
	                AddressInfo,
	                AlternativeNames,
	                6);
	
	File = New File(DataPathAtServer+"altnames.dbf");
	
	If File.Exist() Then
		FillAlternativeNames(DataPathAtServer, AddressInfo, AlternativeNames);
	EndIf;
	
	WriteClassifier(AddressClassifierUnitCode, AddressInfo);
	
EndProcedure

// Clears address information for given address units.
// 
// Parameters:
//  AddressClassifierUnitsArray - Array of String - address unit codes in 2-digit format
//
// Returns:
//	No.
//
Procedure DeleteAddressInfo(Val AddressClassifierUnitsArray) Export
	
	For Each AddressClassifierUnitCode In AddressClassifierUnitsArray Do
		AddressInformationSet = InformationRegisters.AddressClassifier.CreateRecordSet();
		AddressInformationSet.Filter.AddressClassifierUnitCodeInCode.Use = True;
		AddressInformationSet.Filter.AddressClassifierUnitCodeInCode.Value = Number(AddressClassifierUnitCode);
		AddressInformationSet.Write();
		SetClassifierVersion(AddressClassifierUnitCode);
	EndDo;
	
EndProcedure

// Loads address units of first level by template
//
// Parameters:
//	No.
//
// Returns:
//	No.
//
Procedure LoadFirstLevelAddressClassifierUnits() Export
	
	AddressClassifierUnitsClassifierXML = InformationRegisters.AddressClassifier.GetTemplate("AddressClassifierUnits").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(AddressClassifierUnitsClassifierXML).Data;
	
	For Each Unit In ClassifierTable Do
		
		RecordManager = InformationRegisters.AddressClassifier.CreateRecordManager();
		
		RecordManager.Code               	  = Unit.Code;
		RecordManager.AddressItemType 		  = 1;
		RecordManager.Description        	  = Unit.Name;
		RecordManager.Abbreviation           		  = Unit.Abbreviation;
		RecordManager.PostalCode              = Unit.PCode;
		RecordManager.AddressClassifierUnitCodeInCode = Left(Unit.Code,2);
		
		RecordManager.Write();
		
	EndDo;
	
EndProcedure

// Gets the number of address units where address information is not empty
//
// Parameters:
//	No.
//
// Returns:
//	Number - number of filled address units.
//
Function FilledAddressClassifierUnitsCount() Export
	
	QueryText =  "SELECT
	             |	TRUE AS Field1
	             |FROM
	             |	InformationRegister.AddressClassifier AS AddressClassifier
	             |
	             |GROUP BY
	             |	AddressClassifier.AddressClassifierUnitCodeInCode
	             |
	             |HAVING
	             |	COUNT(AddressClassifier.AddressClassifierUnitCodeInCode) <> 1";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Return Query.Execute().Choose().Count();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Service functions which are used for loading the address classifier
//

// Loads address abbreviations to AddressAbbreviations register.
//
// Parameters:
//   DataPathAtServer - path to the directory where abbrbase.dbf file is located
//
// Returns:
//   Boolean - 	true  - information has been written successfully
//          	false - error on prepare / write information to register
//
Function LoadAddressAbbreviations(DataPathAtServer) Export
	
	AddressAbbreviationsFile = DataPathAtServer +  "abbrbase.dbf";
	
	TableAddressAbbreviations = New ValueTable;
	TableAddressAbbreviations.Columns.Add("Code");
	TableAddressAbbreviations.Columns.Add("Level");
	TableAddressAbbreviations.Columns.Add("Description");
	TableAddressAbbreviations.Columns.Add("Abbreviation");
	
	AddressAbbreviations = InformationRegisters.AddressAbbreviations;
	
	RecordSet = AddressAbbreviations.CreateRecordSet();
	RecordSet.Write();
	
	xb = New XBase(AddressAbbreviationsFile);
	xb.Encoding = XBaseEncoding.OEM;
	
	// Control of uniqueness of codes in classifier file
	Controlling = New Map;
	AreErrors = False;
	If xb.IsOpen() Then
		While Not xb.Eof() Do
			UniquenessCode = Number(xb.level)*10000 + Number(xb.code);
			If Controlling[UniquenessCode] = Undefined Then
				Controlling[UniquenessCode] = 0;
				NewRecord = RecordSet.Add();
				NewRecord.Code			= xb.code;
				NewRecord.Level       	= xb.level;
				NewRecord.Description  	= xb.title;
				NewRecord.Abbreviation  = xb.abbr;
			Else
				AreErrors = True;
			EndIf;
			xb.Next();
			
		EndDo;
		xb.CloseFile();
	Else
		Return False;
	EndIf;
	
	If AreErrors Then
		WriteLogEvent(NStr("en = 'Address classifier. Loading'"), 
			EventLogLevel.Error,,, 
			StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'File of the %1 address classifier contains errors: codes are not unique'"),
			"abbrbase.dbf"));
	EndIf;
	RecordSet.Write();
	
	Return True;
	
EndFunction

// Fills data from 2-nd to 6-th level of classification:
// 2-nd - areas of republics, territories, regions, autonomous districts, etc;
// 3-nd - cities, towns and villages if town type;
// 4-th - small towns and villages subordinate to territories of 3-rd type;
// 5-th - streets;
// 6-th - buildings.
//
// Parameters:
//  AddressClassifierUnitCode - String (2 chars) - string presentation of address unit 
//						  number
//  DataPathAtServer  - String - path to directory at server, where the classifier
//                        are stored. Path is ended with slash (back of regular)
//  AddressInfo 	  - ValueTable - table, being filled by loaded items
//  AlternativeNames  - ValueTable - returns the alternative names data, contains following 
//						  columns:
//		Code - String
//		Description - String
//		Abbreviation - String
//		PostalCode - String
//  AddressItemType   - Number - an address unit level, if not set it is defined 
//						  automatically by the address unit code
//
Function LoadAddressInfo(AddressClassifierUnitCode,
                         DataPathAtServer,
                         AddressInfo,
                         AlternativeNames,
                         Val AddressItemType = Undefined)
	
	AddressClassifierFile = DataPathAtServer +  ".dbf";
	ClassifierIndexFile   = DataPathAtServer +  ".cdx";
	
	IndexFile = New File (ClassifierIndexFile);
	If NOT IndexFile.Exist() Then
		xb = New XBase(AddressClassifierFile);
		xb.Encoding = XBaseEncoding.OEM;
		
		If xb.IsOpen() Then
			// For load of a group of address information is helpful
			// to use postal code by entire CODE field
			xb.indexes.Add("IDXCODE", "CODE", True);
			xb.CreateIndex(ClassifierIndexFile);
			xb.CloseFile();
		Else
			Return False;
		EndIf;
	EndIf;
	
	xb = New XBase(AddressClassifierFile,
	                 ClassifierIndexFile,
	                 True);
	xb.Encoding = XBaseEncoding.OEM;
	
	// If we load streets or buildings, then this item type is address
	If AddressItemType <> Undefined Then
		AddressItemTypeIsSet = True;
	Else
		AddressItemTypeIsSet = False;
	EndIf;
	
	If Not xb.IsOpen() Then
		Return False;
	EndIf;
		
	Controlling = New Map;
	AreErrors = False;
	
	xb.CurrentIndex = xb.Indexes.Find("IDXCODE");
	
	xb.Find (AddressClassifierUnitCode, "=");
	
	While Not xb.Eof() Do
		Code = xb.CODE;
		
		If Controlling[Code] = Undefined Then
			Controlling[Code] = 0;
			
			If Left(Code, 2) <> AddressClassifierUnitCode Then
				Break;
			EndIf;
			
			If Not AddressItemTypeIsSet Then
				AddressItemType = GetAddressItemTypeByCode(Code);
			EndIf;
			
			// If this is an alternative name, then placing information to separate
			// table of alternative descriptions (for building numbers there are no
			// alternative field names)
			ActualitySign = Right(Code, 2);
			
			If  (AddressItemType <> 6)
				And (ActualitySign <> "00")
				And (ActualitySign <> "99") Then
				
				StringOfAlternativeNames = AlternativeNames.Add();
				StringOfAlternativeNames.Code        = Code;
				StringOfAlternativeNames.Description = TrimAll(xb.NAME);
				StringOfAlternativeNames.Abbreviation        = TrimAll(xb.ABBR);
				StringOfAlternativeNames.PostalCode  = TrimAll(xb.PCODE);
				
				xb.Next();
				Continue;
				
			EndIf;
			
			NewRow = AddressInfo.Add();
			
			NewRow.Code = Code;
			
			NewRow.AddressItemType			= AddressItemType;
			NewRow.AddressClassifierUnitCodeInCode	= Number(Mid(Code, 1, 2));
			NewRow.ProvinceCodeInCode           = Number(Mid(Code, 3, 3));
			NewRow.CityCodeInCode			= Number(Mid(Code, 6, 3));
			NewRow.DistrictCodeInCode			= Number(Mid(Code, 9, 3));
			NewRow.StreetCodeInCode			= Number(Mid(Code, 12, 4));
			
			NewRow.Description				= TrimAll(xb.NAME);
			NewRow.PostalCode				= xb.PCODE;
			NewRow.Abbreviation   					= TrimAll(xb.ABBR);
			
			xb.Next();
		Else
			AreErrors = True;
		EndIf;
		
	EndDo;
	
	xb.CloseFile();
	
	If AreErrors Then
		WriteLogEvent(NStr("en = 'Address classifier. Loading'"), 
			EventLogLevel.Error, , ,
			StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'File of %1 address classifier contains errors: codes are not unique'"),
			DataPathAtServer));
	EndIf;
	
	Return True;
	
EndFunction

// Supplements address information with alternative names
//
Function FillAlternativeNames(DataPathAtServer,
                              AddressInfo,
                              AlternativeNames)
	
	FilePathAN      = DataPathAtServer + "altnames.dbf";
	IndexFilePathAN = DataPathAtServer + "altnames.cdx";
	
	IndexFile = New File (IndexFilePathAN);
	If Not IndexFile.Exist() Then
		xb = New XBase(FilePathAN);
		xb.Encoding = XBaseEncoding.OEM;
		If xb.IsOpen() Then
			xb.indexes.Add("IDXCODE", "OLDCODE", True);
			xb.CreateIndex(IndexFilePathAN);
			xb.CloseFile();
		Else
			Return False;
		EndIf;
	EndIf;
	
	xb = New XBase(FilePathAN,
	               IndexFilePathAN,
	               True);
	
	xb.Encoding = XBaseEncoding.OEM;
	
	If xb.IsOpen() Then
		xb.CurrentIndex = xb.Indexes.Find("IDXCODE");
	EndIf;
	
	For Each AlternativeObject In AlternativeNames Do
		
		ActualitySign = Right(AlternativeObject.Code, 2);
		
		ActualDescriptionCode = Left(AlternativeObject.Code,
		                             StrLen(AlternativeObject.Code) - 2) + "00";
		
		If ActualitySign = "51" Then
			// address information should be searched in altnames.dbf
			OLDCODE = ActualDescriptionCode;
			xb.Find(OLDCODE, "=");
			
			NewCode = TrimAll(xb.NewCode);
			
			// trying to find actual object in address data
			TableRow = AddressInfo.Find(NewCode, "Code");
			
			If TableRow = Undefined Then
				
				NewRow = AddressInfo.Add();
				
				Code = Left(AlternativeObject.Code, StrLen(AlternativeObject.Code) - 2) + "00";
				
				AddressItemType = GetAddressItemTypeByCode(Code);
				
				NewRow.Code = Code;
				
				NewRow.AddressItemType			= AddressItemType;
				NewRow.AddressClassifierUnitCodeInCode	= Number(Mid(Code, 1, 2));
				NewRow.ProvinceCodeInCode           = Number(Mid(Code, 3, 3));
				NewRow.CityCodeInCode       	= Number(Mid(Code, 6, 3));
				NewRow.DistrictCodeInCode 			= Number(Mid(Code, 9, 3));
				NewRow.StreetCodeInCode			= Number(Mid(Code, 12, 4));
				
				NewRow.Description 				= TrimAll(AlternativeObject.Description);
				NewRow.PostalCode       		= TrimAll(AlternativeObject.PostalCode);
				NewRow.Abbreviation   					= TrimAll(AlternativeObject.Abbreviation);
				
				Continue;
			EndIf;
			
		Else
			
			TableRow = AddressInfo.Find(ActualDescriptionCode, "Code");
			
		EndIf; // If ActualitySign = "51" Then ... Else
		
		
		If TableRow <> Undefined Then
			If ValueIsFilled(TrimAll(AlternativeObject.PostalCode)) Then 
				AAOPostalCode = " : " + AlternativeObject.PostalCode;
			Else
				AAOPostalCode = "";
			EndIf;
			
			AlternativeName = AlternativeObject.Description
		                      + " "
		                      + AlternativeObject.Abbreviation
		                      + AAOPostalCode;
			
			If TableRow.AlternativeNames = Undefined Then
				TableRow.AlternativeNames = AlternativeName;
			Else
				TableRow.AlternativeNames = TableRow.AlternativeNames
	                                        + ", "
	                                        + AlternativeName;
			EndIf;
		EndIf; // If TableRow <> Undefined Then
		
		TableRow = Undefined;
		
	EndDo;
	
	If xb.IsOpen() Then
		xb.CloseFile();
	EndIf;
	
EndFunction

// Function for filling data from 2-nd to 4-th classification level:
//
// Parameters:
//   AddressClassifierUnitCode  - string - code of address unit in NN format
//   AddressInfo 		- ValueTable - records, which repeat structure of IR AddressClassifier;
//                        being moved to the register
//
Function WriteClassifier(AddressClassifierUnitCode, AddressInfo)
	
	For Each Item In AddressInfo Do
		
		StrCode = String(Item.Code);
		DC = StrLen(StrCode);
		
		For Index = DC To 20 Do
			StrCode = StrCode + "0";
		EndDo;
		
		Item.Code = StrCode;
		
	EndDo;
	
	AddressInformationSet = InformationRegisters.AddressClassifier.CreateRecordSet();
	AddressInformationSet.Filter.AddressClassifierUnitCodeInCode.Use = True;
	AddressInformationSet.Filter.AddressClassifierUnitCodeInCode.Value = Number(AddressClassifierUnitCode);
	AddressInformationSet.Load(AddressInfo);
	AddressInformationSet.Write();
	
EndFunction

// Function obtains address item level (total 6 levels) in
// hierarchical system of classification by item code
// code format:
// _2__3___3___3___4____4____
// |CC|AAA|CCC|HHH|SSSS|BBBB|
// 
// the deeper level of hierarchy the lower digits will be filled
//
// Parameters:
//   Code           - string - code, taken from record field CODE of data file
// 
// Value returned:
//   Number [1-6]
Function GetAddressItemTypeByCode(Val Code)
	
	DigitsCount = StrLen(Code);
	
	// for codes with digits count of 13 or 17 code must be cropped
	// for 2 digits - chars of actuality of address unit
	If DigitsCount = 13 OR DigitsCount = 17 Then
		DigitsCount = DigitsCount - 2;
		CodeNumber = Number(Mid(Code, 1, StrLen(Code)-2));
	ElsIf DigitsCount = 19 Then
		CodeNumber = Number(Mid(Code, 1, StrLen(Code)));
	EndIf;
	
	// Check if digits BBBB are filled
	If DigitsCount = 19 Then
		
		Bal = CodeNumber % 10000;
		If Bal <> 0 Then
			Return 6;
		EndIf;
		
		CodeNumber = CodeNumber / 10000;
		
	EndIf;
	
	// Check if digits SSSS are filled
	If DigitsCount = 15 Then
		
		Bal = CodeNumber % 10000;
		If Bal <> 0 Then
			Return 5;
		EndIf;
		
		CodeNumber = CodeNumber / 10000;
		
	EndIf;
	
	// Check if digits HHH are filled
	Bal = CodeNumber % 1000;
	If Bal <> 0 Then
		Return 4;
	EndIf;
	
	// Check if digits CCC are filled
	Bal = CodeNumber % 1000000;
		
	If Bal <> 0 Then
		Return 3;
	EndIf;
	
	// Check if digits AAA are filled
	Bal = CodeNumber % 1000000000;
		
	If Bal <> 0 Then
		Return 2;
	EndIf;
	
	// Top hierarchy level - unit
	
	Return 1;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for getting information about address units
//

// Returns structure, containing information about address unit
// 
// Parameters:
//   AddressClassifierUnitCode - String - number of address unit starting 1 to 89 + 99 in NN format
//
// Value to return:
//   Structure, with keys: AddressClassifierUnitCode, Description, Abbreviation, PostalCode
//
Function InformationAboutAddressUnit(AddressClassifierUnitCode) Export
	
	AddressClassifierUnitsClassifierXML = InformationRegisters.AddressClassifier.GetTemplate("AddressClassifierUnits").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(AddressClassifierUnitsClassifierXML).Data;
	
	Result = New Structure("AddressClassifierUnitCode, Description, Abbreviation, PostalCode");
	
	For Each Unit In ClassifierTable Do
		If Left(Unit.Code, 2) = AddressClassifierUnitCode Then
			Break;
		EndIf;
	EndDo;
	
	Result.AddressClassifierUnitCode = Unit.Code;
	Result.Description       = Unit.Name;
	Result.Abbreviation          	 = Unit.Abbreviation;
	Result.PostalCode        = Unit.PCode;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Function for work with address units information versions 
//

// Sets version of address unit in register
// Parameters:
//   AddressUnitCode    - string - code of address unit in NN format
//   Description - description of address unit
//   DetailsVersionByAddressUnit - date - version of address unit
//
Procedure SetClassifierVersion(Val AddressUnitCode,
                               Val Description = "",
                               Val DetailsVersionByAddressUnit = "") Export
	
	RecordManager = InformationRegisters.AddressClassifierUnitVersions.CreateRecordManager();
	
	If IsBlankString(DetailsVersionByAddressUnit) Then
		RecordManager.Unit = AddressUnitCode;
		RecordManager.Read();
		RecordManager.Delete();
	Else
		RecordManager.Unit = AddressUnitCode;
		RecordManager.VersionIssueDate = DetailsVersionByAddressUnit;
		RecordManager.Description = Description;
		
		RecordManager.Write(True);
	EndIf;
	
EndProcedure

// Reads file of data object versions and returns
// information versions about address units
//
Function GetAddressInformationVersions(Val TextXML) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(TextXML);
	
	XMLReader.Read();
	
	Result = New Map;
	
	While XMLReader.Read() Do
		AddressClassifierUnitCode = GetAttribute(XMLReader, "code");
		If ValueIsFilled(AddressClassifierUnitCode) Then
			ManufactureDate         = GetAttribute(XMLReader, "date");
			Result.Insert(AddressClassifierUnitCode, ManufactureDate);
		EndIf;
		XMLReader.Read();
	EndDo;
	
	XMLReader.Close();
	
	Return Result;
	
EndFunction

// Reads attribute value by name from specified object, casts value
// to specified primitive type
//
// Parameters:
//   XMLReader    - Object of type XMLReader, positionned at element start,
//                  whose attribute should be received
//   Type         - Value of type Type. Attribute type
//   Name         - String. Attribute name
//
// Value returned:
//   Attribute value obtained by name and converted to specified type
//
Function GetAttribute(Val XMLReader, Val Name)
	
	StrValue = TrimAll(XMLReader.GetAttribute(Name));
	
	If Name = "date" Then
		Return Date(Mid(StrValue, 7, 4) + Mid(StrValue, 4, 2) + Left(StrValue, 2));
	ElsIf Name = "code" Then
		Return Left(StrValue, 2);
	EndIf;
	
EndFunction

// Function places address units on support. In fact information
// register is being filled by the map of address units codes and actuality dates
// Parameters:
//   TextXML        - multiline string - file text with the description of versions of address units
//   AddressClassifierUnits - array - list of address units, each row - address unit
//                    code in NN format
//
Procedure RefreshAddressInfoVersion(TextXML, AddressClassifierUnits) Export
	
	AddressDetailsVersions = GetAddressInformationVersions(TextXML);
	
	For Each Unit In AddressClassifierUnits Do
		AddressInfo = InformationAboutAddressUnit(Unit);
		SetClassifierVersion(Unit,
                             AddressInfo.Description + " " + AddressInfo.Abbreviation,
                             AddressDetailsVersions[Unit]);
	EndDo;
	
EndProcedure

// Saves archive file from binary data at server using
// passed name in passed directory, and extracts it.
//
// Parameters:
//   BinaryData 	 - BinaryData - file data
//   ArchiveFileName - String     - file name
//   PathToDirectoryAtServer      - path to the directory, where extracted file should be placed
//
Procedure SaveFileAtServerAndExtract(Val BinaryData,
                                     ArchiveFileName,
                                     PathToDirectoryAtServer) Export
	
	If PathToDirectoryAtServer = Undefined Then
		PathToDirectoryAtServer = CommonUseClientServer.GetTempDirectoryPath("addressclassifierfiles");
	EndIf;
	
	BinaryData.Write(PathToDirectoryAtServer + ArchiveFileName);
	
	ZIPReader = New ZipFileReader(PathToDirectoryAtServer + ArchiveFileName);
	ZIPReader.ExtractAll(PathToDirectoryAtServer,
	                     ZIPRestoreFilePathsMode.DontRestore);
	ZIPReader.Close();
	DeleteFiles(PathToDirectoryAtServer, ArchiveFileName);
	
EndProcedure

// ---------------------------------------------------------------
// Authentication at 1C user site

// Gets user authentication parameters (login and password) at 1C user site.
// Value returned:
// Boolean - True    - authentication parameters are filled
//           False   - at least one authentication parameter is not filled
//
Function GetAuthenticationParameters(Login, Password) Export
	
	Value = CommonSettingsStorage.Load("AuthenticationAtUsersWebsite", "Login");
	
	Login = ?(Value = Undefined, "", Value);
	
	Value = CommonSettingsStorage.Load(
	                  "AuthenticationAtUsersWebsite",
	                  "Password");
	
	Password = ? (Value = Undefined, "", Value);
	
	Return ((? (Login = Undefined, False, True))
	       And (? (IsBlankString(Password), False, True)))
	
EndFunction

// Saves login and password to IB settings system storage
// Parameters:
//   Login - String - login, for access to 1C user site
//   Password - String - password
//
Procedure SaveAuthenticationParameters(Login, Password) Export
	
	CommonSettingsStorage.Save(
	             "AuthenticationAtUsersWebsite",
	             "Login",
	             Login,,
	             Users.AuthorizedUser());
	
	CommonSettingsStorage.Save(
	             "AuthenticationAtUsersWebsite",
	             "Password",
	             Password,,
	             Users.AuthorizedUser());
	
EndProcedure
