#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	If AdditionalProperties.Property("Import") Then
		Return;
	EndIf;
	
	If Not IsNew() Then
		
		If DeletionMark <> CommonUse.ObjectAttributeValue(Ref, "DeletionMark") Then
			
			SetPrivilegedMode(True);
			
			CommonUse.SetDeletionMarkForSubordinateObjects(Ref, DeletionMark);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndIf