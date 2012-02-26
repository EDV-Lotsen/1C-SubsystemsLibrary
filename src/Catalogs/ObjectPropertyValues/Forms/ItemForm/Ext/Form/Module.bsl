

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	OwnerOfPropertyValue = Catalogs.ObjectPropertyValues.EmptyRef();
	
	If Object.Ref = Catalogs.ObjectPropertyValues.EmptyRef() Then
		If Parameters.CopyingValue = Catalogs.ObjectPropertyValues.EmptyRef() Then
			OwnerOfPropertyValue = Parameters.FillingValues.Owner;
		Else
			OwnerOfPropertyValue = Parameters.CopyingValue.Owner;
		EndIf;
	Else
		OwnerOfPropertyValue = Object.Ref.Owner;
	EndIf;
	
	PropertyName = TrimAll(StrGetLine(OwnerOfPropertyValue.SubjectDeclension, 1));
	
	If IsBlankString(PropertyName) Then
		PropertyName = OwnerOfPropertyValue.Description;
	EndIf;
	
	If Object.Ref = Catalogs.ObjectPropertyValues.EmptyRef() Then // create new one
		Title = PropertyName + " (" + NStr("en = 'creation'") + ")";
	Else
		Title = Object.Description + " (" + PropertyName + ")";
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	PropertyName = TrimAll(StrGetLine(Object.Owner.SubjectDeclension, 1));
	
	If IsBlankString(PropertyName) Then
		PropertyName = Object.Owner.Description;
	EndIf;
	
	Title = Object.Description + " (" + PropertyName + ")";
	
EndProcedure
