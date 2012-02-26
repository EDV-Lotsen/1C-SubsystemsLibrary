

Procedure FillCheckProcessing(Cancellation, CheckedAttributes)
	If Not OrderNumberIsUnique(FillSequence, Ref) Then
		Cancellation = True;
		
		ErrorText = NStr("en = 'The filling sequence is not unique - there is already a volume with the same sequence'");
		CommonUseClientServer.MessageToUser(ErrorText, ThisObject, "FillSequence");
	EndIf;
	
	If IsBlankString(FullPathWindows) And IsBlankString(FullPathLinux) Then
		ErrorText = NStr("en = 'Full path not filled'");
		CommonUseClientServer.MessageToUser(ErrorText, ThisObject, "FullPathWindows");
		CommonUseClientServer.MessageToUser(ErrorText, ThisObject, "FullPathLinux");
		Return;
	EndIf;
	
	If Not IsBlankString(FullPathWindows) And (Left(FullPathWindows, 2) <> "\\" OR Find(FullPathWindows, ":") <> 0) Then
		Cancellation = True;
		
		ErrorText = NStr("en = 'Path to volume must be in the UNC format (\\servername\resource)'");
		CommonUseClientServer.MessageToUser(ErrorText, ThisObject, "FullPathWindows");
		
		Return;
	EndIf;	
	
	FieldNameWithCompletePath = "";
	Try
		VolumeFullPath = "";
		
		ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
		
		If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
			VolumeFullPath = FullPathWindows;
			FieldNameWithCompletePath = "FullPathWindows";
		Else	
			VolumeFullPath = FullPathLinux;
			FieldNameWithCompletePath = "FullPathLinux";
		EndIf;
		
		DirectoryNameIsTest = VolumeFullPath + "AccessVerification\";
		CreateDirectory(DirectoryNameIsTest);
		DeleteFiles(DirectoryNameIsTest);
	Except
		Cancellation = True;
		
		ErrorText = NStr("en = 'The path to volume is incorrect:'");
		Information = ErrorInfo();
		If Information.Cause <> Undefined Then
			ErrorText = ErrorText + Information.Cause.Description;
			
			If Information.Cause.Cause <> Undefined Then
				ErrorText = ErrorText + ": " + Information.Cause.Cause.Description;
			EndIf;
		Else
			ErrorText = ErrorText + Information.Description;
		EndIf;
			
		CommonUseClientServer.MessageToUser(ErrorText, ThisObject, FieldNameWithCompletePath);
		
	EndTry;
	
	If MaximumSize <> 0 Then
		CurrentSizeInBytes = 0;
		If Not Ref.IsEmpty() Then
			CurrentSizeInBytes = FileOperations.CalculateFilesSizeOnVolume(Ref); 
		EndIf;
		CurrentSize = CurrentSizeInBytes / (1024 * 1024);
		
		If MaximumSize < CurrentSize Then
			Cancellation = True;
			
			ErrorText = NStr("en = 'Maximum size of the volume is smaller than the current size'");
			CommonUseClientServer.MessageToUser(ErrorText, ThisObject, "MaximumSize");
		EndIf;	
	EndIf;	
	
EndProcedure

// Returns False, if volume with such order exists
Function OrderNumberIsUnique(FillSequence, VolumeRef)
	Query = New Query;
	Query.Text = "SELECT
				   |	COUNT(Volumes.FillSequence) AS Quantity
				   |FROM
				   |	Catalog.FileStorageVolumes AS Volumes
				   |WHERE
				   |	Volumes.FillSequence = &FillSequence
				   |And   Volumes.Ref <> &VolumeRef";
	
	Query.Parameters.Insert("FillSequence", FillSequence);
	Query.Parameters.Insert("VolumeRef", VolumeRef);
				   
	Selection = Query.Execute().Choose();
	If Selection.Next() Then
		If Selection.Quantity = 0 Then
			Return True;
		Else
			Return False;
		EndIf;
	EndIf;
	
	Return True;
EndFunction // FindMaximumVersionNumber
