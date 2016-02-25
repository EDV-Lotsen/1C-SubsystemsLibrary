////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Returns the table of prefix forming attributes specified in the overridable module.
//
Function PrefixFormingAttributes() Export
	
	Objects = New ValueTable;
	Objects.Columns.Add("Object");
	Objects.Columns.Add("Attribute");
	
	ObjectPrefixationOverridable.GetPrefixFormingAttributes(Objects);
	
	ObjectAttributes = New Map;
	
	For Each Row In Objects Do
		ObjectAttributes.Insert(Row.Object.FullName(), Row.Attribute);
	EndDo;
	
	Return New FixedMap(ObjectAttributes);
	
EndFunction

#EndRegion
