////////////////////////////////////////////////////////////////////////////////
// Address classifier subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Checks web server for address classifier
// updates for previously downloaded objects.
//
// Returns:
//     Array  - contains structures describing address objects. 
//     The structures follow this format:
//         * AddressObjectCode - String  - address object code
//         * Description       - String  - address object description
//         * Abbreviation      - String  - address object abbreviation
//         * Index             - String  - address object index 
//         * UpdateAvailable   - Boolean - update availability flag
//
Function CheckForAddressObjectUpdates() Export
	
	StoredDataVersions = AddressClassifierServerCall.AddressObjectVersions();
	
	Result = VersionsAvailableAt1CWebsite();
	If Not Result.Status Then
		Return Result;
	EndIf;
	AvailableVersions = Result.AvailableVersions;
	
	AvailableUpdates = New Array;
	
	For Each StoredVersionItem In StoredDataVersions Do
		AddressObject = StoredVersionItem.Presentation;
		AddressInformation = AddressClassifierServerCall.AddressObjectInformation(AddressObject);
		AddressInformation.Insert("UpdateAvailable",
			?(TypeOf(AvailableVersions[AddressObject]) <> Type("Date"),
			  False,
			  AvailableVersions[AddressObject] > Date(StoredVersionItem.Value)));
		AvailableUpdates.Add(AddressInformation);
	EndDo;
	
	// Retrieving the latest AC update version from the 1C website
	Result = FillResult(AvailableUpdates);
	//
	LatestACUpdateVersion = AvailableVersions["V0"];
	If TypeOf(LatestACUpdateVersion) <> Type("Date") Then
		LatestACUpdateVersion = '00000000';
	EndIf;
	Result.Insert("LatestACUpdateVersion", LatestACUpdateVersion);
	
	Return Result;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// Retrieves versions available at 1C website
//
// Returns:
//     Structure - version description:
//         * Status            - Boolean       - version availability status.
//         * AvailableVersions - Map           - available versions.
//
Function VersionsAvailableAt1CWebsite() Export
	
	URLString = PathToACDataDescriptionFile();
	
	// CTL-specific format
	AddressContent = CommonUseClientServer.URIStructure(URLString);
	If IsBlankString(AddressContent.Port) Then
		Protocol = Upper(AddressContent.Schema);
		If Protocol = "HTTP" Then
			AddressContent.Port = 80;
		ElsIf Protocol = "HTTPS" Then
			AddressContent.Port = 443;
		EndIf;
		URLString = URIByStructure(AddressContent);
	EndIf;
	
#If Client Then
	GetFilesResult = GetFilesFromInternetClient.DownloadFileAtClient(URLString);
#Else
	GetFilesResult = GetFilesFromInternet.DownloadFileAtServer(URLString);
#EndIf
	
	If Not GetFilesResult.Status Then
		Return GetFilesResult;
	EndIf;
	
	TextDocument = New TextDocument;
	TextDocument.Read(GetFilesResult.Path);
	XMLText = TextDocument.GetText();
	
	DeleteFiles(GetFilesResult.Path);
	
	AvailableVersions = AddressClassifierServerCall.GetAddressDataVersions(XMLText);
	
	Return New Structure("Status, AvailableVersions", True, AvailableVersions);
	
EndFunction

// Path to webserver-based file containing information on address data versions
//
// Returns:
//     String - path to AC data description file.
//
Function PathToACDataDescriptionFile() Export
	
	Return "http://1c-dn.com/demos/addressclassifier/versions.xml";
	
EndFunction

// Creates a structure with keys Status (True) and Value.
//
// Parameters:
//     Value  - Arbitrary - passed value. 
//     Status - Boolean   - passed status.
//
// Returns:
//     Structure - resulting structure
//
Function FillResult(Val Value, Val Status = True)
	
	If Status Then
		Return New Structure("Status, Value", True, Value);
	Else
		Return New Structure("Status, ErrorMessage", False, Value);
	EndIf;
	
EndFunction

// This function returns a structure containing a set of fields identical to a record
// of the AddressClassifier information register, with empty values.
//
// Returns:
//     Structure - required structure
//
Function EmptyAddressStructure() Export
	
	AddressStructure =  New Structure;
	AddressStructure.Insert("Code", 0);
	AddressStructure.Insert("Description", "");
	AddressStructure.Insert("Abbr", "");
	AddressStructure.Insert("AddressItemType", 0);
	AddressStructure.Insert("PostalCode", "");
	AddressStructure.Insert("AddressObjectCodeInCode", 0);
	AddressStructure.Insert("CountyCodeInCode", 0);
	AddressStructure.Insert("CityCodeInCode", 0);
	AddressStructure.Insert("SettlementCodeInCode", 0);
	AddressStructure.Insert("StreetCodeInCode", 0);
	AddressStructure.Insert("DataIsCurrentFlag", 0);
	
	Return AddressStructure;
	
EndFunction

// Opposite of CommonUseClientServer.URLStructure
Function URIByStructure(Val URLStructure)
	Result = "";
	
	// Protocol
	If Not IsBlankString(URLStructure.Schema) Then
		Result = Result + URLStructure.Schema + "://";
	EndIf;
	
	// Authorization
	If Not IsBlankString(URLStructure.Login) Then
		Result = Result + URLStructure.Login + ":" + URLStructure.Password + "@";
	EndIf;
		
	// Other
	Result = Result + URLStructure.Domain;
	If Not IsBlankString(URLStructure.Port) Then
		Result = Result + ":" + ?(TypeOf(URLStructure.Port) = Type("Number"), Format(URLStructure.Port, ""), URLStructure.Port);
	EndIf;
	
	Result = Result + "/" + URLStructure.PathAtServer;
	Return Result;
	
EndFunction

// Returns address classifier indetification: 
//
// Returns:
//     String    - address classifier ID
//     Undefined - if failed to identify an address classifier
//
Function UsedAddressClassifier() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	AddressClassifierSubsystemExists = CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier");
#Else
	AddressClassifierSubsystemExists = CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier");
#EndIf
	
	If AddressClassifierSubsystemExists Then
		Return "AC";
	EndIf;
	
	// Subsystem not available
	Return Undefined;
EndFunction

// Checking availability of all files to be imported
//
// Parameters:
//     StateCodes         - Array     - contain numeric values - codes of regions to be imported
//     WorkingDirectory   - String    - directory where the checked files are stored
//     ImportParameters - Structure - contains fields 
//         * ImportSourceCode - String - describes a set of files to be analyzed. 
//            Allowed values: DIRECTORY, ITS
//         * ErrorField       - String - name of attribute used to link error messages
//
// Returns - structure containing fields:
//     * StateCodes        - Array     - contains numeric values of codes of regions 
//        for which all files are available 
//     * AllFilesAvailable - Boolean   - flag allowing to import data for all regions
//     * Errors            - Structure - see CommonUseClientServer.AddUserError description
//     * FilesByState      - Map       - files sorted by state. Key can be:
//          - a number (state code). In this case, value is an array 
//            containing names of files required to import data for this state
//          - asterisk (*) character. In this case, value is an array 
//            containing names of files required to import data for all states
//
Function CheckForClassifierFilesAvailabilityInDirectory(Val StateCodes, Val WorkingDirectory, Val ImportParameters) Export
	
	// The list of files may vary depending on the classifier
	ClassifierType = UsedAddressClassifier();
	If ClassifierType = "AC" Then
		Return CheckForClassifierFilesAvailabilityInACDirectory(StateCodes, WorkingDirectory, ImportParameters);
	EndIf;
	
	// Dummy call in order to create an empty structure
	ImportParameters = New Structure("ImportSourceCode");
	Return CheckForClassifierFilesAvailabilityInACDirectory(StateCodes, WorkingDirectory, ImportParameters);
EndFunction

Function CheckForClassifierFilesAvailabilityInACDirectory(Val StateCodes, Val WorkingDirectory, Val ImportParameters)
	
	Result = New Structure;
	Result.Insert("StateCodes", StateCodes);
	Result.Insert("AllFilesAvailable", True);
	Result.Insert("Errors",       Undefined);
	Result.Insert("FilesByState",              New Map);
	
	If ImportParameters.ImportSourceCode = "DIRECTORY" Then
		// Full AC file list
		//ErrorPattern = NStr("en = 'AC file ""%1"" not found'");
		//Extension   = ".DBF";
		//FileNames  = "ALTNAMES, DOMA, KLADR, SOCRBASE, STREET";
		
		ErrorPattern = NStr("en = 'AC file ""%1"" not found'");
		Extension   = ".dbf";
		FileNames  = "ALTNAMES, BUILD45, CLASSF45, ABBRBASE, STREET45";
		
	//ElsIf ImportParameters.ImportSourceCode = "ITS" Then
	//	// Supplied files
	//	ErrorPattern = NStr("en = 'File ""%1"" not found'");
	//	Extension   = ".EXE";
	//	FileNames  = "ALTNAMES, DOMA, KLADR, SOCRBASE, STREET";
		
	Else
		Return Result;
		
	EndIf;

	WorkingDirectory = CommonUseClientServer.AddFinalPathSeparator(WorkingDirectory);
	
	Result.FilesByState["*"] = New Array;
	For Each KeyValue In New Structure(FileNames) Do
		FileName = KeyValue.Key + Extension;
		File = FindFile(WorkingDirectory, FileName);
		If File.Exist Then
			Result.FilesByState["*"].Add(File.FullName);
		Else
			Result.AllFilesAvailable = False;
			CommonUseClientServer.AddUserError(Result.Errors, ImportParameters.ErrorField, 
				StringFunctionsClientServer.SubstituteParametersInString(ErrorPattern, FileName));
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Searching for a file by mask, case-insensitive (OS specifics ignored)
//
// Parameters:
//     Directory - String - directory used to search for file 
//     FileName  - String - file name
//
// Returns:
//     Structure - found file's description. Contains fields:
//         * Exists    - Boolean - flag stating that the specified file exists 
//         * Name      - String  - file parameter, see File type description 
//         * BaseName  - String  - file parameter, see File type description 
//         * FullName  - String  - file parameter, see File type description 
//         * Path      - String  - file parameter, see File type description 
//         * Extension - String  - file parameter, see File type description
//
Function FindFile(Val Directory, Val FileName) Export
	
	SystemInfo = New SystemInfo;
	Platform = SystemInfo.PlatformType;
	
	CaseInsensitive = Platform = PlatformType.Windows_x86 Or Platform = PlatformType.Windows_x86_64;
	
	If CaseInsensitive Then
		Mask = Upper(FileName);
	Else
		Mask = "";
		For Position = 1 To StrLen(FileName) Do
			Char = Mid(FileName, Position, 1);
			UpperCase = Upper(Char);
			LowerCase  = Lower(Char);
			If UpperCase = LowerCase Then
				Mask = Mask + Char;
			Else
				Mask = Mask + "[" + UpperCase + LowerCase + "]";
			EndIf;
		EndDo;
	EndIf;
	
	Result = New Structure("Exist, Name, BaseName, FullName, Path, Extension", False); 
	Options = FindFiles(Directory, Mask);
	If Options.Count() > 0 Then 
		Result.Exist = True;
		FillPropertyValues(Result, Options[0]);
	EndIf;
	
	Return Result;
EndFunction

// Returns flag stating that the client runs under Windows
//
// Returns:
//     Boolean - True if the client runs under Windows
//
Function IsWindowsClient() Export
	
#If Client Or ExternalConnection Then
	SystemInfo = New SystemInfo;
	Result = SystemInfo.PlatformType = PlatformType.Windows_x86
		Or SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
#Else
		
	SetPrivilegedMode(True);
	
	IsLinuxClient = StandardSubsystemsServer.ClientParametersOnServer().Get("IsLinuxClient");
	
	If IsLinuxClient = Undefined Then
		// No client application
		Return False;
	EndIf;
	
	Result = Not IsLinuxClient;
#EndIf
	
	Return Result;
EndFunction

// Deletes temporary file. 
// Any errors that may occur during delete attempt will be ignored and the file will be deleted later
//
Procedure DeleteTempFile(Val FullFileName) Export
	
	Try
		DeleteFiles(FullFileName)
	Except
		// No additional processing is necessary
	EndTry
	
EndProcedure

#EndRegion
