
&AtClient
Procedure GroupsOnActivateRow(Item)
	AttachIdleHandler("IdleProcessing", 0.2, True);
EndProcedure

// Procedure updates file list
&AtClient
Procedure IdleProcessing()
	
	If Items.Folders.CurrentRow <> Undefined Then
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;	
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.Property("FileOwner") Then 
		List.Parameters.SetParameterValue(
			"Owner", Parameters.FileOwner);
	
		If TypeOf(Parameters.FileOwner) = Type("CatalogRef.FileFolders") Then
			Items.Folders.CurrentRow = Parameters.FileOwner;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		Else
			Items.Folders.Visible = False;
		EndIf;
	Else	
		If Parameters.Property("TemplateChoice") And Parameters.TemplateChoice Then 	
			Items.Folders.CurrentRow = Catalogs.FileFolders.FileTemplates;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		Else
			Folders.Filter.Items.Clear();
		EndIf;	
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
	If Parameters.Property("CurrentRow") Then 
		Items.Folders.CurrentRow = Parameters.CurrentRow;
	EndIf;
	
EndProcedure

