
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Selected",        Parameters.Selected);
	Query.SetParameter("GroupUser",       Parameters.GroupUser);
	Query.SetParameter("Responsible",     Users.AuthorizedUser());
	Query.SetParameter("FullResponsible", Users.InfobaseUserWithFullAccess());
	
	SetPrivilegedMode(True);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref,
	|	AccessGroups.Description,
	|	AccessGroups.IsFolder,
	|	CASE
	|		WHEN AccessGroups.IsFolder
	|				AND Not AccessGroups.DeletionMark
	|			THEN 0
	|		WHEN AccessGroups.IsFolder
	|				AND AccessGroups.DeletionMark
	|			THEN 1
	|		WHEN Not AccessGroups.IsFolder
	|				AND Not AccessGroups.DeletionMark
	|			THEN 3
	|		ELSE 4
	|	END AS PictureNumber,
	|	FALSE AS Check
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	CASE
	|			WHEN AccessGroups.IsFolder
	|				THEN TRUE
	|			WHEN AccessGroups.Ref IN (&Selected)
	|				THEN FALSE
	|			WHEN AccessGroups.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Profile.DeletionMark
	|				THEN FALSE
	|			WHEN AccessGroups.Ref = VALUE(Catalog.AccessGroups.Administrators)
	|				THEN &FullResponsible
	|						AND VALUETYPE(&GroupUser) = TYPE(Catalog.Users)
	|			WHEN &FullResponsible = FALSE
	|					AND AccessGroups.Responsible <> &Responsible
	|				THEN FALSE
	|			ELSE CASE
	|						WHEN AccessGroups.User = UNDEFINED
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.Users.EmptyRef)
	|							THEN TRUE
	|						WHEN AccessGroups.User = VALUE(Catalog.ExternalUsers.EmptyRef)
	|							THEN TRUE
	|						ELSE AccessGroups.User = &GroupUser
	|					END
	|					AND CASE
	|						WHEN AccessGroups.UserType = UNDEFINED
	|							THEN TRUE
	|						WHEN VALUETYPE(AccessGroups.UserType) = TYPE(Catalog.Users)
	|							THEN CASE
	|									WHEN VALUETYPE(&GroupUser) = TYPE(Catalog.Users)
	|											OR VALUETYPE(&GroupUser) = TYPE(Catalog.UserGroups)
	|										THEN TRUE
	|									ELSE FALSE
	|								END
	|						WHEN VALUETYPE(&GroupUser) = TYPE(Catalog.ExternalUsers)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.ExternalUsers AS ExternalUsers
	|									WHERE
	|										ExternalUsers.Ref = &GroupUser
	|										AND VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(AccessGroups.UserType))
	|						WHEN VALUETYPE(&GroupUser) = TYPE(Catalog.ExternalUserGroups)
	|							THEN TRUE IN
	|									(SELECT TOP 1
	|										TRUE
	|									FROM
	|										Catalog.ExternalUserGroups AS ExternalUserGroups
	|									WHERE
	|										ExternalUserGroups.Ref = &GroupUser
	|										AND VALUETYPE(ExternalUserGroups.AuthorizationObjectType) = VALUETYPE(AccessGroups.UserType))
	|						ELSE FALSE
	|					END
	|		END
	|
	|ORDER BY
	|	AccessGroups.Ref HIERARCHY";
	
	NewTree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Folders = NewTree.Rows.FindRows(New Structure("IsFolder", True), True);
	
	DeleteFolders = New Map;
	NoFolders = True;
	
	For Each Folder In Folders Do
		If Folder.Parent = Undefined
		   And Folder.Rows.Count() = 0
		 Or Folder.Rows.FindRows(New Structure("IsFolder", False), True).Count() = 0 Then
			
			DeleteFolders.Insert(
				?(Folder.Parent = Undefined, NewTree.Rows, Folder.Parent.Rows),
				Folder);
		Else
			NoFolders = False;
		EndIf;
	EndDo;
	
	For Each DeleteFolder In DeleteFolders Do
		If DeleteFolder.Key.IndexOf(DeleteFolder.Value) > -1 Then
			DeleteFolder.Key.Delete(DeleteFolder.Value);
		EndIf;
	EndDo;
	
	NewTree.Rows.Sort("IsFolder Desc, Description Asc", True);
	ValueToFormAttribute(NewTree, "AccessGroups");
	
	If NoFolders Then
		Items.AccessGroups.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

#EndRegion

#Region AccessGroupsFormTableItemEventHandlers

&AtClient
Procedure AccessGroupsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OnChoice();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	OnChoice();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure OnChoice()
	
	CurrentData = Items.AccessGroups.CurrentData;
	
	If CurrentData <> Undefined Then
		If CurrentData.IsFolder Then
			
			If Items.AccessGroups.Expanded(Items.AccessGroups.CurrentRow) Then
				Items.AccessGroups.Collapse(Items.AccessGroups.CurrentRow);
			Else
				Items.AccessGroups.Expand(Items.AccessGroups.CurrentRow);
			EndIf;
		Else
			NotifyChoice(CurrentData.Ref);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
