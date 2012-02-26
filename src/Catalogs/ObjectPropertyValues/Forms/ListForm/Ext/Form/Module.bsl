

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Owner = Undefined;
	ContainsValues = False;
	
	If Parameters.Filter.Property("Owner", Owner) Then
		ContainsValues = Owner.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValues"));
	EndIf;
	
	If Not ContainsValues Then
		Items.List.ReadOnly = True;
	EndIf;
	
EndProcedure
