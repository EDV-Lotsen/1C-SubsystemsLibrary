////////////////////////////////////////////////////////////////////////////////
// Users subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Returns a value table that contains names of all configuration roles.
// 
// Returns:
//  ValueTable with the following column:
//   Name - String.
//
Function AllRoles() Export
	
	Table = New ValueTable;
	Table.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(1000)));
	
	For Each Role In Metadata.Roles Do
		Table.Add().Name = Role.Name;
	EndDo;
	
	Return Table;
	
EndFunction

// Returns a value table that contains Role and RoleSynonym columns.
// Fills this table according to metadata.
//
// Returns:
//  ValueTable with the following columns:
//   Role - String(150).
//   RoleSynonym - String(1000).
//
Function RoleSynonyms() Export
	
	RoleSynonyms = New ValueTable;
	RoleSynonyms.Columns.Add("Role", New TypeDescription("String",, New StringQualifiers(150)));
	RoleSynonyms.Columns.Add("RoleSynonym", New TypeDescription("String",, New StringQualifiers(1000)));
	
	For Each Role In Metadata.Roles Do
		
		RoleDetails = RoleSynonyms.Add();
		RoleDetails.Role = Role.Name;
		RoleDetails.RoleSynonym = Role.Synonym;
		
	EndDo;
		
	Return RoleSynonyms;
	
EndFunction

// Returns a tree of roles with or without subsystems.
// If a role is not included in any subsystem it is added to the root.
// 
// Parameters:
//  BySubsystems - Boolean - if it is False, all roles are added to the root.
// 
// Returns:
//  ValueTree with the following columns:
//   IsRole  - Boolean.
//   Name    - String - name of a role or a subsystem.
//   Synonym - String - synonym of a role of a subsystem.
//
Function RoleTree(BySubsystems = True, Val UserType = Undefined) Export
	
	If UserType = Undefined Then
		If CommonUseCached.DataSeparationEnabled() Then
			UserType = Enums.UserTypes.DataAreaUser;
		Else
			UserType = Enums.UserTypes.LocalApplicationUser;
		EndIf;
	EndIf;
	
	Tree = New ValueTree;
	Tree.Columns.Add("IsRole", New TypeDescription("Boolean"));
	Tree.Columns.Add("Name", New TypeDescription("String"));
	Tree.Columns.Add("Synonym", New TypeDescription("String", , New StringQualifiers(1000)));
	
	If BySubsystems Then
		FillSubsystemsAndRoles(Tree.Rows, , UserType);
	EndIf;
	
	InaccessibleRoles = UsersServerCached.InaccessibleRolesByUserType(UserType);
	
	// Adding missed roles
	For Each Role In Metadata.Roles Do
		
		If InaccessibleRoles.Get(Role) <> Undefined
			Or Upper(Left(Role.Name, StrLen("Delete"))) = Upper("Delete") Then
			
			Continue;
		EndIf;
		
		If Tree.Rows.FindRows(New Structure("IsRole, Name", True, Role.Name), True).Count() = 0 Then
			TreeRow = Tree.Rows.Add();
			TreeRow.IsRole = True;
			TreeRow.Name = Role.Name;
			TreeRow.Synonym = ?(ValueIsFilled(Role.Synonym), Role.Synonym, Role.Name);
		EndIf;
	EndDo;
	
	Tree.Rows.Sort("IsRole Desc, Synonym Asc", True);
	
	Return Tree;
	
EndFunction

Function InaccessibleRightsByUserType(Val UserType) Export
	
	If UserType = Enums.UserTypes.ExternalUser Then
		Result = New Array;
		Result.Add("Administration");
		Result.Add("DataAdministration");
	ElsIf UserType = Enums.UserTypes.LocalApplicationUser Then
		Result = New Array;
	ElsIf UserType = Enums.UserTypes.DataAreaUser Then
		Result = New Array;
		Result.Add("Administration");
		Result.Add("UpdateDataBaseConfiguration");
		Result.Add("ExclusiveMode");
		Result.Add("ThickClient");
		Result.Add("ExternalConnection");
		Result.Add("Automation");
		Result.Add("InteractiveOpenExtDataProcessors");
		Result.Add("InteractiveOpenExtReports");
		Result.Add("AllFunctionsMode");
	Else
		MessageTemplate = NStr("en = 'An unknown type of the user %1.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(MessageTemplate, UserType);
		Raise(Message);
	EndIf;
	
	Return Result;
	
EndFunction

Function CommonDataChangeAllowed(Val UserType) Export
	
	If UserType = Enums.UserTypes.ExternalUser Then
		Return True;
	ElsIf UserType = Enums.UserTypes.LocalApplicationUser Then
		Return True;
	ElsIf UserType = Enums.UserTypes.DataAreaUser Then
		Return False;
	Else
		MessageTemplate = NStr("en = 'An unknown type of the user %1.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(MessageTemplate, UserType);
		Raise(Message);
	EndIf;
	
EndFunction

Function CommonDataChangeAvailable(Val RoleName) Export
	
	Return UsersServerCached.SharedDataAvailableForChanges(RoleName).Count() > 0;
	
EndFunction

// Returns a table of shared metadata object full names and
// corresponded access right sets.
//
// Parameters:
//  RoleName - String.
//
// Returns:
//  ValueTree with the following columns: 
//   Name  - String - metadata object full name.
//   Right - String - access right name.
//
Function SharedDataAvailableForChanges(Val RoleName) Export
	
	Role = Metadata.Roles[RoleName];
	
	MetadataKinds = New Array;
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ExchangePlans, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Constants, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Catalogs, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Sequences, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Documents, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfCharacteristicTypes, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfAccounts, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.ChartsOfCalculationTypes, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.BusinessProcesses, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.Tasks, True));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.InformationRegisters, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.AccumulationRegisters, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.AccountingRegisters, False));
	MetadataKinds.Add(New Structure("Kind, Reference" , Metadata.CalculationRegisters, False));
	
	SetPrivilegedMode(True);
	
	ObjectTable = New ValueTable;
	ObjectTable.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	ObjectTable.Columns.Add("Right", New TypeDescription("String", , New StringQualifiers(0, AllowedLength.Variable)));
	
	CheckedRights = New Array;
	CheckedRights.Add(New Structure("Name, Reference", "Edit", False));
	CheckedRights.Add(New Structure("Name, Reference", "Insert", True));
	CheckedRights.Add(New Structure("Name, Reference", "Delete", True));
	
	SeparatedMetadataObjects = CommonUseCached.SeparatedMetadataObjects();
	
	For Each KindDescription In MetadataKinds Do // by metadata kinds
		For Each MetadataObject In KindDescription.Kind Do // by kind objects
			MetadataObjectFullName = MetadataObject.FullName();
			If SeparatedMetadataObjects.Get(MetadataObjectFullName) = Undefined Then
				
				For Each RightDetails In CheckedRights Do
					If Not RightDetails.Reference
						Or KindDescription.Reference Then
						
						If AccessRight(RightDetails.Name, MetadataObject, Role) Then
							RowRights = ObjectTable.Add();
							RowRights.Name = MetadataObjectFullName;
							RowRights.Right = RightDetails.Name;
						EndIf;
						
					EndIf;
				EndDo;
				
			EndIf;
		EndDo;
	EndDo;
	
	Return ObjectTable;
	
EndFunction

Function InaccessibleRolesByUserType(Val UserType) Export
	
	SetPrivilegedMode(True);
	
	Result = New Map;
	
	InaccessibleRights = InaccessibleRightsByUserType(UserType);
		
	CheckSharedData = Not CommonDataChangeAllowed(UserType);
		
	For Each Role In Metadata.Roles Do
		InaccessibleRightsFound = False;
		For Each Right In InaccessibleRights Do
			If AccessRight(Right, Metadata, Role) Then
				InaccessibleRightsFound = True;
				Break;
			EndIf;
		EndDo;
		
		If CheckSharedData
			And Not InaccessibleRightsFound Then
			
			InaccessibleRightsFound = CommonDataChangeAvailable(Role.Name);
		EndIf;
		
		If InaccessibleRightsFound Then
			Result.Insert(Role, True);
		EndIf;
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure FillSubsystemsAndRoles(TreeRowCollection, Subsystems = Undefined, UserType)
	
	InaccessibleRoles = 
		UsersServerCached.InaccessibleRolesByUserType(UserType);
	
	If Subsystems = Undefined Then
		Subsystems = Metadata.Subsystems;
	EndIf;
	
	For Each Subsystem In Subsystems Do
		
		SubsystemDetails = TreeRowCollection.Add();
		SubsystemDetails.Name = Subsystem.Name;
		SubsystemDetails.Synonym = ?(ValueIsFilled(Subsystem.Synonym), Subsystem.Synonym, Subsystem.Name);
		
		FillSubsystemsAndRoles(SubsystemDetails.Rows, Subsystem.Subsystems, UserType);
		
		For Each Role In Metadata.Roles Do
			If InaccessibleRoles.Get(Role) <> Undefined
				Or Upper(Left(Role.Name, StrLen("Delete"))) = Upper("Delete") Then
				
				Continue;
			EndIf;
			
			If Subsystem.Content.Contains(Role) Then
				RoleDetails = SubsystemDetails.Rows.Add();
				RoleDetails.IsRole = True;
				RoleDetails.Name = Role.Name;
				RoleDetails.Synonym = ?(ValueIsFilled(Role.Synonym), Role.Synonym, Role.Name);
			EndIf;
		EndDo;
		
		If SubsystemDetails.Rows.FindRows(New Structure("IsRole", True), True).Count() = 0 Then
			TreeRowCollection.Delete(SubsystemDetails);
		EndIf;
	EndDo;
	
EndProcedure

