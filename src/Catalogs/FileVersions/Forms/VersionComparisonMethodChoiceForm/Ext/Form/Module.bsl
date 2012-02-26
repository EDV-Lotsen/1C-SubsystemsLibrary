

&AtClient
Procedure WriteAndClose(Command)
	StructuresArray = New Array;
	
	Item = New Structure;
	Item.Insert("Object", 	"FilesComparisonSettings");
	Item.Insert("Options", 	"FileVersionsCompareMethod");
	Item.Insert("Value", 	FileVersionsCompareMethod);
	StructuresArray.Add(Item);
	
	CommonUse.CommonSettingsStorageSaveArray(StructuresArray);
	RefreshReusableValues();
	
	Close(DialogReturnCode.OK);
	
EndProcedure
