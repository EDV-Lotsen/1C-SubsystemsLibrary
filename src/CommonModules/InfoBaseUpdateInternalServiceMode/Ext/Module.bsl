// Internal use only
Function SharedDataUpdateRequired() Export
	
	SetPrivilegedMode(True);
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		MetadataVersion = Metadata.Version;
		If IsBlankString(MetadataVersion) Then
			MetadataVersion = "0.0.0.0";
		EndIf;
		
		SharedDataVersion = InfoBaseUpdate.InfoBaseVersion(Metadata.Name, True);
		
		If InfoBaseUpdate.UpdateRequired(MetadataVersion, SharedDataVersion) Then
			Return True;
		EndIf;
		
		If Not CommonUseCached.CanUseSeparatedData() Then
			
			SetPrivilegedMode(True);
			Start = SessionParameters.ClientParametersAtServer.Get("StartInfoBaseUpdate");
			SetPrivilegedMode(False);
			
			If Start <> Undefined And InfoBaseUpdate.CanUpdateInfoBase() Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

// Internal use only.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
EndProcedure
