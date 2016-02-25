
//
Var ForExport;
Var ForImport;
//
Var ContainerInitialized;
Var RootDirectory;
Var DirectoryStructure;
Var Content;
//
Var Parameters;


////////////////////////////////////////////////////////////////////////////////
// EXPORT

// Initializes export procedure.
//
// Parameters:
//  ExportDirectory - String - path to export directory.
//
Procedure InitializeExport(Val ExportDirectory, Val ExportParameters) Export
	
	ContainerInitializationCheck(True);
	
	ExportDirectory = TrimAll(ExportDirectory);
	If Right(ExportDirectory, 1) = "\" Then
		RootDirectory = ExportDirectory;
	Else
		RootDirectory = ExportDirectory + "\";
	EndIf;
	
	Parameters = ExportParameters;
	
	ForExport = True;
	ContainerInitialized = True;
	
EndProcedure

Function ExportParameters() Export
	
	ContainerInitializationCheck();
	
	If ForExport Then
		Return New FixedStructure(Parameters);
	Else
		Raise NStr("en = 'The container is not initialized for data export.'");
	EndIf;
	
EndFunction

// Creates a file in the export directory.
//
// Parameters:
//  FileKind - String - export file kind.
//  DataType - String - data type.
//
// Returns:
//  String - file name.
//
Function CreateFile(Val FileKind, Val DataType = Undefined) Export
	
	ContainerInitializationCheck();
	
	Return AppendFile(FileKind, "xml", DataType);
	
EndFunction

// Creates an arbitrary export file.
//
// Parameters:
//  Extension - String - file extension.
//  DataType - String - data type.
//
// Returns:
//  String - file name.
//
Function CreateArbitraryFile(Val Extension, Val DataType = Undefined) Export
	
	ContainerInitializationCheck();
	
	Return AppendFile(DataExportImportInternal.CustomData(), Extension, DataType);
	
EndFunction

Procedure SetObjectAndRecordCount(Val FullPathToFile, Val ObjectCount = Undefined) Export
	
	ContainerInitializationCheck();
	
	Filter = New Structure;
	Filter.Insert("FullName", FullPathToFile);
	FilesInContent = Content.FindRows(Filter);
	If FilesInContent.Count() = 0 Or FilesInContent.Count() > 1 Then 
		Raise NStr("en = 'File not found'");
	EndIf;
	
	FilesInContent[0].ObjectCount = ObjectCount;
	
EndProcedure

Procedure ExcludeFile(Val FullPathToFile) Export
	
	ContainerInitializationCheck();
	
	ContentRow = Content.Find(FullPathToFile, "FullName");
	If ContentRow = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'File %1 is not found in the container content.'"), FullPathToFile);
	Else
		
		Content.Delete(ContentRow);
		DeleteFiles(FullPathToFile);
		
	EndIf;
	
EndProcedure

// Finalizes the export procedure. Writes export information to a file.
//
Procedure FinalizeExport() Export
	
	UpdateExportFileList();
	FileName = CreateFile(DataExportImportInternal.PackageContents());
	WriteContainerContentToFile(FileName);
	
EndProcedure

Procedure UpdateExportFileList()
	
	For Each CurrentFile In Content Do 
		
		File = New File(CurrentFile.FullName);
		If Not File.Exist() Then 
			Raise NStr("en = 'The file was deleted'");
		EndIf;
		
		CurrentFile.Size = File.Size();
		CurrentFile.Hash    = CalculateHash(File.FullName);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// IMPORT

// Initializes import procedure.
//
// Parameters:
//  ImportDirectory - String - path to import directory.
//
Procedure InitializeImport(Val ImportDirectory, Val ImportParameters) Export
	
	ContainerInitializationCheck(True);
	
	ImportDirectory = TrimAll(ImportDirectory);
	If Right(ImportDirectory, 1) = "\" Then
		RootDirectory = ImportDirectory;
	Else
		RootDirectory = ImportDirectory + "\";
	EndIf;
	
	ContentFileName = ImportDirectory + GetFileName(DataExportImportInternal.PackageContents());
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(ContentFileName);
	ReaderStream.MoveToContent();
	
	If ReaderStream.NodeType <> XMLNodeType.StartElement
			Or ReaderStream.Name <> "Data" Then
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'XML read error. Invalid file format. Expecting beginning of item %1.'"),
			"Data"
		);
		
	EndIf;
	
	If Not ReaderStream.Read() Then
		Raise NStr("en = 'XML read error. End of file detected.'");
	EndIf;
	
	While ReaderStream.NodeType = XMLNodeType.StartElement Do
		
		ContainerItem = XDTOFactory.ReadXML(ReaderStream, XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "Файл"));
		ReadContainerItem(ContainerItem);
		
	EndDo;
	
	ReaderStream.Close();
	
	For Each Item In Content Do
		Item.FullName = ImportDirectory + Item.Directory + "\" + Item.Name;
	EndDo;
	
	Parameters = ImportParameters;
	
	ForImport = True;
	ContainerInitialized = True;
	
EndProcedure

Function ImportParameters() Export
	
	ContainerInitializationCheck();
	
	If ForImport Then
		Return New FixedStructure(Parameters);
	Else
		Raise NStr("en = 'The container is not initialized for data import.'");
	EndIf;
	
EndFunction

// Gets a file from directory.
//
// Parameters:
//  FileKind - String - export file kind.
//  DataType - String - data type.
//
// Returns:
//  ValueTableRow - see the Content value table.
//
Function GetFileFromDirectory(Val FileKind, Val DataType = Undefined) Export
	
	ContainerInitializationCheck();
	
	Files = GetFilesFromContent(FileKind, DataType);
	If Files.Count() = 0 Then
		Return Undefined;
	ElsIf Files.Count() > 1 Then
		Raise NStr("en = 'Export data contains duplicates'");
	EndIf;
	
	Return Files[0].FullName;
	
EndFunction

// Gets an arbitrary file from directory.
//
// Parameters:
//  DataType - String - data type.
//
// Returns:
//  ValueTableRow - see the Content value table.
//
Function GetArbitraryFile(Val DataType = Undefined) Export
	
	Files = GetFilesFromContent(DataExportImportInternal.CustomData() , DataType);
	If Files.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Arbitrary file with data type %1 is not found in the export data.'"),
			DataType
		);
	ElsIf Files.Count() > 1 Then
		Raise NStr("en = 'Export data contains duplicates'");
	EndIf;
	
	Return Files[0].FullName;
	
EndFunction

Function GetFilesFromDirectory(Val FileKind, Val DataType = Undefined) Export
	
	Return GetDescriptionOfFilesFromDirectory(FileKind, DataType).UnloadColumn("FullName");
	
EndFunction

Function GetDescriptionOfFilesFromDirectory(Val FileKind, Val DataType = Undefined) Export
	
	ContainerInitializationCheck();
	
	FilesTable = Undefined;
	
	If TypeOf(FileKind) = Type("Array") Then 
		
		For Each SeparateKind In FileKind Do
			AppendFilesToValueTable(FilesTable, GetFilesFromContent(SeparateKind , DataType));
		EndDo;
		Return FilesTable;
		
	ElsIf TypeOf(FileKind) = Type("String") Then 
		
		Return GetFilesFromContent(FileKind, DataType);
		
	Else
		
		Raise NStr("en = 'Unknown file kind'");
		
	EndIf;
	
EndFunction

Function GetArbitraryFiles(Val DataType = Undefined) Export
	
	Return GetArbitraryFileDescriptions(DataType).UnloadColumn("FullName");
	
EndFunction

Function GetArbitraryFileDescriptions(Val DataType = Undefined) Export
	
	ContainerInitializationCheck();
	
	Return GetFilesFromContent(DataExportImportInternal.CustomData(), DataType);
	
EndFunction

Procedure AppendFilesToValueTable(FilesTable, Val FilesFromContent)
	
	If FilesTable = Undefined Then 
		FilesTable = FilesFromContent;
		Return;
	EndIf;
	
	CTLAndSLIntegration.SupplementTable(FilesFromContent, FilesTable);
	
EndProcedure

Function GetFullFileName(Val RelativeFileName) Export
	
	ContentRow = Content.Find(RelativeFileName, "Name");
	
	If ContentRow = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'File with relative name %1 is not found in the container.'"),
			RelativeFileName
		);
	Else
		Return ContentRow.FullName;
	EndIf;
	
EndFunction

Function GetRelativeFileName(Val FullFileName) Export
	
	ContentRow = Content.Find(FullFileName, "FullName");
	
	If ContentRow = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'File %1 is not found in the container.'"),
			FullFileName
		);
	Else
		Return ContentRow.Name;
	EndIf;
	
EndFunction

Procedure FinalizeImport() Export
	
	ContainerInitializationCheck();
	
EndProcedure

Function GetFilesFromContent(Val FileKind = Undefined, Val DataType = Undefined)
	
	Filter = New Structure;
	If FileKind <> Undefined Then
		Filter.Insert("FileKind", FileKind);
	EndIf;
	If DataType <> Undefined Then
		Filter.Insert("DataType", DataType);
	EndIf;
	
	Return Content.Copy(Filter);
	
EndFunction

//

Procedure ContainerInitializationCheck(Val OnInitialize = False)
	
	If ForExport And ForImport Then
		Raise NStr("en = 'Invalid container initialization.'");
	EndIf;
	
	If OnInitialize Then
		
		If ContainerInitialized <> Undefined And ContainerInitialized Then
			Raise NStr("en = 'The export container is already initialized.'");
		EndIf;
		
	Else
		
		If Not ContainerInitialized Then
			Raise NStr("en = 'The export container is not initialized.'");
		EndIf;
		
	EndIf;
	
EndProcedure

// Operations with files in container content

Function AppendFile(Val FileKind, Val Extension = "xml", Val DataType = Undefined)
	
	FileName = GetFileName(FileKind, Extension, DataType);
	
	DirectoryByFileType = GetDirectoryForFilePlacement(FileKind);
	If IsBlankString(DirectoryByFileType) Then
		
		FullName = RootDirectory + FileName;
		
	Else
		
		NumberedDirectory = GetNumberedDirectory(DirectoryByFileType);
		FullName = RootDirectory + DirectoryByFileType + "\" + NumberedDirectory + "\" + FileName;
		
	EndIf;
	
	File = Content.Add();
	File.Name = FileName;
	File.Directory = DirectoryByFileType;
	File.FullName = FullName;
	File.DataType = DataType;
	File.FileKind = FileKind;
	
	Return FullName;
	
EndFunction

Function GetFileName(Val FileKind, Val Extension = "xml", Val DataType = Undefined)
	
	If FileKind = DataExportImportInternal.DumpInfo() Then
		FileName = DataExportImportInternal.DumpInfo();
	ElsIf FileKind = DataExportImportInternal.PackageContents() Then
		FileName = DataExportImportInternal.PackageContents();
	ElsIf FileKind = DataExportImportInternal.Users() Then
		FileName = DataExportImportInternal.Users();
	Else
		FileName = String(New UUID);
	EndIf;
	
	FileName = FileName + "." + Extension;
	
	Return FileName;
	
EndFunction

// Operations with directory structure

Function GetDirectoryForFilePlacement(Val FileKind)
	
	Rules = DataExportImportInternal.DirectoryStructureCreationRules();
	If Rules.Property(FileKind) Then
		
		Subdirectory = Rules[FileKind];
		If IsBlankString(Subdirectory) Then
			
			Return "";
			
		Else
			
			// Checking whether a directory exists for this data type
			If Not DirectoryStructure.Property(Subdirectory) Then
				CreateDirectory(RootDirectory + Subdirectory);
				DirectoryStructure.Insert(Subdirectory, 1);
			EndIf;
			
			Return Subdirectory;
			
		EndIf;
		
	Else
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = 'File kind %1 is not supported.'"), FileKind);
		EndIf;
		
EndFunction

Function GetNumberedDirectory(Val Subdirectory)
	
	FileCount = Content.Copy(New Structure("Directory", Subdirectory), "Name").Count();
	
	If FileCount >= 1000 Then
		
		DirectoryStructure[Subdirectory] = DirectoryStructure[Subdirectory] + 1;
		CreateDirectory(RootDirectory + Subdirectory + "\" + Format(DirectoryStructure[Subdirectory], "NG=0"));
		Return Format(DirectoryStructure[Subdirectory], "NG=0");
		
	EndIf;
	
	Return "";
	
EndFunction

// Operations with container content description

Procedure WriteContainerContentToFile(FileName)
	
	Rules = ContainerContentSerializationRules();
	
	RecordStream = New XMLWriter();
	RecordStream.OpenFile(FileName);
	RecordStream.WriteXMLDeclaration();
	RecordStream.WriteStartElement("Data");
	
	FileType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "Файл");
	For Each Row In Content Do
		
		FileData = XDTOFactory.Create(FileType);
		
		For Each Rule In Rules Do
			
			If ValueIsFilled(Row[Rule.ObjectField]) Then
				FileData[Rule.XDTOObjectField] = Row[Rule.ObjectField];
			EndIf;
			
		EndDo;
		
		XDTOFactory.WriteXML(RecordStream, FileData);
		
	EndDo;
	
	RecordStream.WriteEndElement();
	RecordStream.Close();
	
EndProcedure

Procedure ReadContainerItem(Val ContainerItemDescription)
	
	Rules = ContainerContentSerializationRules();
	
	File = Content.Add();
	For Each Rule In Rules Do
		File[Rule.ObjectField] = ContainerItemDescription[Rule.XDTOObjectField]
	EndDo;
	
EndProcedure

Function ContainerContentSerializationRules()
	
	Rules = New ValueTable();
	Rules.Columns.Add("ObjectField", New TypeDescription("String"));
	Rules.Columns.Add("XDTOObjectField", New TypeDescription("String"));
	
	AddContainerContentSerializationRule(Rules, "Name", "Name");
	AddContainerContentSerializationRule(Rules, "Directory", "Directory");
	AddContainerContentSerializationRule(Rules, "Size", "Size");
	AddContainerContentSerializationRule(Rules, "FileKind", "Type");
	AddContainerContentSerializationRule(Rules, "Hash", "Hash");
	AddContainerContentSerializationRule(Rules, "ObjectCount", "Count");
	AddContainerContentSerializationRule(Rules, "DataType", "DataType");
	
	Return Rules;
	
EndFunction

Procedure AddContainerContentSerializationRule(Rules, Val ObjectField, Val XDTOObjectField)
	
	Rule = Rules.Add();
	Rule.ObjectField = ObjectField;
	Rule.XDTOObjectField = XDTOObjectField;
	
EndProcedure

Function CalculateHash(Val PathToFile)
	
	Try
		MD5Function = Eval("HashFunction.MD5");
	Except
		Return "";
	EndTry;
	
	TypeParameters = New Array;
	TypeParameters.Add(MD5Function);
	
	TypeName = "DataHashing";
	DataHashing = New(TypeName, TypeParameters);
	DataHashing.AppendFile(PathToFile);
	Return MD5ToString(DataHashing.HashSum);
	
EndFunction

Function MD5ToString(Val BinaryData)
	
	Value = XDTOFactory.Create(XDTOFactory.Type("http://www.w3.org/2001/XMLSchema", "hexBinary"), BinaryData);
	Return Value.LexicalValue;
	
EndFunction


// Initializing default state for the container

AdditionalProperties = New Structure();

DirectoryStructure = New Structure();

ForExport = False;
ForImport = False;

NumberedDirectories = New Map();

Content = New ValueTable;
Content.Columns.Add("Name", New TypeDescription("String"));
Content.Columns.Add("Directory", New TypeDescription("String"));
Content.Columns.Add("FullName", New TypeDescription("String"));
Content.Columns.Add("Size", New TypeDescription("Number"));
Content.Columns.Add("FileKind", New TypeDescription("String"));
Content.Columns.Add("Hash", New TypeDescription("String"));
Content.Columns.Add("ObjectCount", New TypeDescription("Number"));
Content.Columns.Add("DataType", New TypeDescription("String"));

Content.Indexes.Add("FileKind, DataType");
Content.Indexes.Add("FileKind");
Content.Indexes.Add("FullName");
Content.Indexes.Add("Directory");