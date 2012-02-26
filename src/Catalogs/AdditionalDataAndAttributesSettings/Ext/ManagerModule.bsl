
Function UsedAdditionalAttributes(FirstPartOfName, SecondPartOfName) Export
	
	MetadataOfPropertyOwner = Metadata.FindByFullName(FirstPartOfName+"."+SecondPartOfName);
	
	If MetadataOfPropertyOwner = Undefined Then
		Return False;
	EndIf;
	
	If MetadataOfPropertyOwner.TabularSections.Find("AdditionalAttributes") = Undefined Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function UsedAdditionalData(FirstPartOfName, SecondPartOfName) Export
	
	If Metadata.CommonCommands.Find("AdditionalData") = Undefined
	   Or Not Metadata.CommonCommands.AdditionalData.CommandParameterType.ContainsType(Type(FirstPartOfName+"Ref."+SecondPartOfName)) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure GetNameParts(Ref, FirstPartOfName, SecondPartOfName) Export
	
	PredefinedName = Catalogs.AdditionalDataAndAttributesSettings.GetPredefinedItemName(Ref);
	CharPosition = Find(PredefinedName, "_");
	FirstPartOfName = Left(PredefinedName, CharPosition - 1);
	SecondPartOfName = Right(PredefinedName, StrLen(PredefinedName) - CharPosition);
	
EndProcedure
