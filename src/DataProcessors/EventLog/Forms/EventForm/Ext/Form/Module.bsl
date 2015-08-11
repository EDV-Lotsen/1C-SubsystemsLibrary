////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Date = Parameters.Date;
	UserName = Parameters.UserName;
	ApplicationPresentation = Parameters.ApplicationPresentation;
	Computer = Parameters.Computer;
	Event = Parameters.Event;
	EventPresentation = Parameters.EventPresentation;
	Comment = Parameters.Comment;
	MetadataPresentation = Parameters.MetadataPresentation;
	Data = Parameters.Data;
	DataPresentation = Parameters.DataPresentation;
	TransactionID = Parameters.TransactionID;
	TransactionStatus = Parameters.TransactionStatus;
	Session = Parameters.Session;
	ServerName = Parameters.ServerName;
	Port = Parameters.Port;
	SyncPort = Parameters.SyncPort;
	
	// Enabling open buttion for the metadata list 
	If TypeOf(MetadataPresentation) = Type("ValueList") Then
		Items.MetadataPresentation.OpenButton = True;
		Items.AccessMetadataPresentation.OpenButton = True;
		Items.AccessRightRejectionMetadataPresentation.OpenButton = True;
		Items.AccessActionRejectionMetadataPresentation.OpenButton = True;
	EndIf;
	
	// Processing special event data
	Items.AccessData.Visible = False;
	Items.AccessRightDeniedData.Visible = False;
	Items.AccessActionDeniedData.Visible = False;
	Items.AuthenticationData.Visible = False;
	Items.InfoBaseUserData.Visible = False;
	Items.SimpleData.Visible = False;
	Items.DataPresentations.PagesRepresentation = FormPagesRepresentation.None;
	
	If Event = "_$Access$_.Access" Then
		Items.DataPresentations.CurrentPage = Items.AccessData;
		Items.AccessData.Visible = True;
		EventData = GetFromTempStorage(Parameters.DataAddress);
		If EventData <> Undefined Then
			CreateFormTable("AccessDataTable", "DataTable", EventData.Data);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	ElsIf Event = "_$Access$_.AccessDenied" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		
		If EventData <> Undefined Then
			If EventData.Property("Right") Then
				Items.DataPresentations.CurrentPage = Items.AccessRightDeniedData;
				Items.AccessRightDeniedData.Visible = True;
				AccessRightDenied = EventData.Right;
			Else
				Items.DataPresentations.CurrentPage = Items.AccessActionDeniedData;
				Items.AccessActionDeniedData.Visible = True;
				AccessActionDenied = EventData.Action;
				CreateFormTable("AccessActionDeniedDataTable", "DataTable", EventData.Data);
				Items.Comment.VerticalStretch = False;
				Items.Comment.Height = 1;
			EndIf;
		EndIf;
		
	ElsIf Event = "_$Session$_.Authentication"
		 or Event = "_$Session$_.AuthenticationError" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		Items.DataPresentations.CurrentPage = Items.AuthenticationData;
		Items.AuthenticationData.Visible = True;
		If EventData <> Undefined Then
			EventData.Property("Name", AuthenticationUserName);
			EventData.Property("OSUser", AuthenticationOSUser);
			EventData.Property("CurrentOSUser", AuthenticationCurrentOSUser);
		EndIf;
		
	ElsIf Event = "_$User$_.Delete"
		 or Event = "_$User$_.New"
		 or Event = "_$User$_.Update" Then
		EventData = GetFromTempStorage(Parameters.DataAddress);
		Items.DataPresentations.CurrentPage = Items.InfoBaseUserData;
		Items.InfoBaseUserData.Visible = True;
		InfoBaseUserProperties = New ValueTable;
		InfoBaseUserProperties.Columns.Add("Name");
		InfoBaseUserProperties.Columns.Add("Value");
		RoleArray = Undefined;
		If EventData <> Undefined Then
			For Each KeyAndValue In EventData Do
				If KeyAndValue.Key = "Roles" Then
					RoleArray = KeyAndValue.Value;
					Continue;
				EndIf;
				NewRow = InfoBaseUserProperties.Add();
				NewRow.Name = KeyAndValue.Key;
				NewRow.Value = KeyAndValue.Value;
			EndDo;
		EndIf;
		CreateFormTable("InfoBaseUserPropertyTable", "DataTable", InfoBaseUserProperties);
		If RoleArray <> Undefined Then
			IBUserRoles = New ValueTable;
			IBUserRoles.Columns.Add("Role",, NStr("en = 'Role'"));
			For Each CurrentRole In RoleArray Do
				IBUserRoles.Add().Role = CurrentRole;
			EndDo;
			CreateFormTable("InfoBaseUserRoleTable", "Roles", IBUserRoles);
		EndIf;
		Items.Comment.VerticalStretch = False;
		Items.Comment.Height = 1;
		
	Else
		Items.DataPresentations.CurrentPage = Items.SimpleData;
		Items.SimpleData.Visible = True;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure MetadataPresentationOpening(Item, StandardProcessing)
	
	ShowValue(, MetadataPresentation);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF AccessActionDeniedDataTable TABLE

&AtClient
Procedure DataTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(, Item.CurrentData[Mid(Field.Name, StrLen(Item.Name)+1)]);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure CreateFormTable(Val FormTableFieldName, Val AttributeNameFormDataCollection, Val ValueTable)
	
	If TypeOf(ValueTable) <> Type("ValueTable") Then
		ValueTable = New ValueTable;
		ValueTable.Columns.Add("Undefined", , " ");
	EndIf;
	
	// Adding attributes to the form table
	AttributesToAdd = New Array;
	For Each Column In ValueTable.Columns Do
		AttributesToAdd.Add(New FormAttribute(Column.Name, Column.ValueType, AttributeNameFormDataCollection, Column.Title));
	EndDo;
	ChangeAttributes(AttributesToAdd);
	
	// Adding items to the form
	For Each Column In ValueTable.Columns Do
		AttributeItem = Items.Add(FormTableFieldName + Column.Name, Type("FormField"), Items[FormTableFieldName]);
		AttributeItem.DataPath = AttributeNameFormDataCollection + "." + Column.Name;
	EndDo;
	
	ValueToFormAttribute(ValueTable, AttributeNameFormDataCollection);
	
EndProcedure


