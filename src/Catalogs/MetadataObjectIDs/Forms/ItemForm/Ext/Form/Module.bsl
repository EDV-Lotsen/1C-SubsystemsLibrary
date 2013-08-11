
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
 
 ReadOnly = True;
 
 EmptyRefPresentation = String(TypeOf(Object.EmptyRefValue));
 
 If Object.Predefined Then
  PredefinedName = Catalogs.MetadataObjectIDs.GetPredefinedItemName(Object.Ref);
 EndIf;
 
EndProcedure