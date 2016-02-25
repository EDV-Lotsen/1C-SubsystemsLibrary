////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

Procedure ExportInfobaseUsers(Container) Export
	
	InfobaseUsers = InfobaseUsers.GetUsers();
	InfobaseUsers = SortInfobaseUserArrayBeforeExport(InfobaseUsers);
	
	FileName = Container.CreateFile(DataExportImportInternal.Users());
	
	RecordStream = New XMLWriter();
	RecordStream.OpenFile(FileName);
	RecordStream.WriteXMLDeclaration();
	RecordStream.WriteStartElement("Data");
	
	For Each IBUser In InfobaseUsers Do
		
		XDTOFactory.WriteXML(RecordStream, SerializeInfobaseUser(IBUser));
		
	EndDo;
	
	RecordStream.WriteEndElement();
	RecordStream.Close();
	
EndProcedure

Procedure ImportInfobaseUsers(Container) Export
	
	FileName = Container.GetFileFromDirectory(DataExportImportInternal.Users());
	
	ReaderStream = New XMLReader();
	ReaderStream.OpenFile(FileName);
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
		
		UserSerialization = XDTOFactory.ReadXML(ReaderStream, XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "InfoBaseUser"));
		
		IBUser = DeserializeInfobaseUser(UserSerialization);
		
		Cancel = False;
		DataExportImportInternalEvents.ExecuteActionsOnImportInfobaseUser(
			Container, UserSerialization, IBUser, Cancel);
		
		If Not Cancel Then
			
			IBUser.Write();
			
			DataExportImportInternalEvents.ExecuteActionsAfterImportInfobaseUser(
				Container, UserSerialization, IBUser);
			
		EndIf;
		
	EndDo;
	
	ReaderStream.Close();
	
	DataExportImportInternalEvents.ExecuteActionsOnImportInfobaseUsers(Container);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Data

Function SortInfobaseUserArrayBeforeExport(Val SourceArray)
	
	VT = New ValueTable();
	VT.Columns.Add("User", New TypeDescription("InfobaseUser"));
	VT.Columns.Add("Administrator", New TypeDescription("Boolean"));
	
	For Each IBUser In SourceArray Do
		
		VTRow = VT.Add();
		VTRow.User = IBUser;
		VTRow.Administrator = AccessRight("DataAdministration", Metadata, VTRow.User);
		
	EndDo;
	
	VT.Sort("Administrator Desc");
	
	Return VT.UnloadColumn("User");
	
EndFunction

Function SerializeInfobaseUser(Val User, Val SavePassword = False, Val StoreSeparation = False)
	
	InfobaseUserType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "InfoBaseUser");
	UserRolesType = XDTOFactory.Type("http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1", "UserRoles");
	
	XDTOUser = XDTOFactory.Create(InfobaseUserType);
	XDTOUser.OSAuthentication = User.OSAuthentication;
	XDTOUser.StandardAuthentication = User.StandardAuthentication;
	XDTOUser.CannotChangePassword = User.CannotChangePassword;
	XDTOUser.Name = User.Name;
	If User.DefaultInterface <> Undefined Then
		XDTOUser.DefaultInterface = User.DefaultInterface.Name;
	Else
		XDTOUser.DefaultInterface = "";
	EndIf;
	XDTOUser.PasswordIsSet = User.PasswordIsSet;
	XDTOUser.ShowInList = User.ShowInList;
	XDTOUser.FullName = User.FullName;
	XDTOUser.OSUser = User.OSUser;
	If StoreSeparation Then
		XDTOUser.DataSeparation = XDTOSerializer.WriteXDTO(User.DataSeparation);
	Else
		XDTOUser.DataSeparation = Undefined;
	EndIf;
	XDTOUser.RunMode = RunModeString(User.RunMode);
	XDTOUser.Roles = XDTOFactory.Create(UserRolesType);
	For Each Role In User.Roles Do
		XDTOUser.Roles.Role.Add(Role.Name);
	EndDo;
	If SavePassword Then
		XDTOUser.StoredPasswordValue = User.StoredPasswordValue;
	Else
		XDTOUser.StoredPasswordValue = Undefined;
	EndIf;
	XDTOUser.UUID = User.UUID;
	If User.Language <> Undefined Then
		XDTOUser.Language = User.Language.Name;
	Else
		XDTOUser.Language = "";
	EndIf;
	
	Return XDTOUser;
	
EndFunction

Function RunModeString(Val RunMode)
	
	If RunMode = Undefined Then
		Return "";
	ElsIf RunMode = ClientRunMode.Auto Then
		Return "Auto";
	ElsIf RunMode = ClientRunMode.OrdinaryApplication Then
		Return "OrdinaryApplication";
	ElsIf RunMode = ClientRunMode.ManagedApplication Then
		Return "ManagedApplication";
	Else
		MessagePattern = NStr("en = 'Unknown client application run mode %1'");
		MessageText = CTLAndSLIntegration.SubstituteParametersInString(MessagePattern, RunMode);
		Raise(MessageText);
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Import

Function DeserializeInfobaseUser(Val XDTOUser, Val RestorePassword = False, Val RestoreSeparation = False)
	
	User = InfobaseUsers.FindByUUID(XDTOUser.UUID);
	If User = Undefined Then
		User = InfobaseUsers.CreateUser();
	EndIf;
	
	User.OSAuthentication = XDTOUser.OSAuthentication;
	User.StandardAuthentication = XDTOUser.StandardAuthentication;
	User.CannotChangePassword = XDTOUser.CannotChangePassword;
	User.Name = XDTOUser.Name;
	If IsBlankString(XDTOUser.DefaultInterface) Then
		User.DefaultInterface = Undefined;
	Else
		User.DefaultInterface = Metadata.Interfaces.Find(XDTOUser.DefaultInterface);
	EndIf;
	User.ShowInList = XDTOUser.ShowInList;
	User.FullName = XDTOUser.FullName;
	User.OSUser = XDTOUser.OSUser;
	If RestoreSeparation Then
		If XDTOUser.DataSeparation = Undefined Then
			User.DataSeparation = New Structure;
		Else
			User.DataSeparation = XDTOSerializer.ReadXDTO(XDTOUser.DataSeparation);
		EndIf;
	Else
		User.DataSeparation = New Structure;
	EndIf;
	User.RunMode = ClientRunMode[XDTOUser.RunMode];
	User.Roles.Clear();
	For Each RoleName In XDTOUser.Roles.Role Do
		Role = Metadata.Roles.Find(RoleName);
		If Role <> Undefined Then
			User.Roles.Add(Role);
		EndIf;
	EndDo;
	If RestorePassword Then
		User.StoredPasswordValue = XDTOUser.StoredPasswordValue;
	Else
		User.StoredPasswordValue = "";
	EndIf;
	If IsBlankString(XDTOUser.Language) Then
		User.Language = Undefined;
	Else
		User.Language = Metadata.Languages[XDTOUser.Language];
	EndIf;
	
	Return User;
	
EndFunction




