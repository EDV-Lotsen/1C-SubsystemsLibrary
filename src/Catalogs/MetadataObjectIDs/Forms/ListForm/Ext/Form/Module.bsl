
&AtClient
Procedure UpdateCatalogData(Command)
 
	HasChanges = False;
	HasDeleted = False;

	UpdateCatalogDataAtServer(HasChanges, HasDeleted);

	If HasChanges Then
		Text = NStr("en = 'Update completed successfully.'");
	Else
		Text = NStr("en = 'Update is not required.'");
	EndIf;

	If HasDeleted Then
		Text = Text
			+ Chars.LF
			+ Chars.LF
			+ NStr("en = ' Deleted metadata objects is found 
			|(see items that begin with a ""?"").'");
	EndIf;

	ShowMessageBox(, Text);
 
EndProcedure

&AtServer
Procedure UpdateCatalogDataAtServer(HasChanges, HasDeleted)
 
	SetPrivilegedMode(True);
 
	Catalogs.MetadataObjectIDs.UpdateCatalogData(HasChanges, HasDeleted);

	Items.List.Refresh();
 
EndProcedure
