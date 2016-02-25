#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If Not AdditionalProperties.Property("IgnoreBasicFillingCheck") Then
	
		If Not SequenceNumberUnique(FillOrder, Ref) Then
			ErrorText = NStr("en = 'Fill order is not unique. There is a volume of the same order.'");
			CommonUseClientServer.MessageToUser(ErrorText, , "FillOrder", "Object", Cancel);
		EndIf;
		
		If MaxSize <> 0 Then
			CurrentSizeInBytes = 0;
			If Not Ref.IsEmpty() Then
				
				FileFunctionsInternal.VolumeFilesSizeOnDefine(
					Ref, CurrentSizeInBytes);
			EndIf;
			CurrentSize = CurrentSizeInBytes / (1024 * 1024);
			
			If MaxSize < CurrentSize Then
				ErrorText = NStr("en = 'Max volume size is less than the current one'");
				CommonUseClientServer.MessageToUser(ErrorText, , "MaxSize", "Object", Cancel);
			EndIf;
		EndIf;
		
		If IsBlankString(WindowsFullPath) And IsBlankString(LinuxFullPath) Then
			ErrorText = NStr("en = 'Full path is not filled'");
			CommonUseClientServer.MessageToUser(ErrorText, , "WindowsFullPath", "Object", Cancel);
			CommonUseClientServer.MessageToUser(ErrorText, , "LinuxFullPath",   "Object", Cancel);
			Return;
		EndIf;
		
		If Not GetFunctionalOption("UseSecurityProfiles")
		   And Not IsBlankString(WindowsFullPath)
		   And (   Left(WindowsFullPath, 2) <> "\\"
		      Or Find(WindowsFullPath, ":") <> 0 ) Then
			
			ErrorText = NStr("en = 'Path to volume should have UNC-format (\\servername\resource).'");
			CommonUseClientServer.MessageToUser(ErrorText, , "WindowsFullPath", "Object", Cancel);
			Return;
		EndIf;
	EndIf;
	
	If Not AdditionalProperties.Property("IgnoreDirectoryAccessCheck") Then
		FullPathFieldName = "";
		VolumeFullPath = "";
		
		ServerPlatformType = CommonUseCached.ServerPlatformType();
		
		If ServerPlatformType = PlatformType.Windows_x86
		 Or ServerPlatformType = PlatformType.Windows_x86_64 Then
			
			VolumeFullPath = WindowsFullPath;
			FullPathFieldName = "WindowsFullPath";
		Else
			VolumeFullPath = LinuxFullPath;
			FullPathFieldName = "LinuxFullPath";
		EndIf;
		
		TestDirectoryName = VolumeFullPath + "CheckAccess\";
		
		Try
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			ErrorInfo = ErrorInfo();
			
			If GetFunctionalOption("UseSecurityProfiles") Then
				ErrorPattern =
					NStr("en = 'Invalid volume path.
					           |Permissions in security profiles may be configured in a wrong way 
					           |or 1C:Enterprise server account may not have enough rights
					           |to access the volume directory.
					           |
					           |%1'");
			Else
				ErrorPattern =
					NStr("en = 'Invalid volume path.
					           |1С:Enterprise server account may not have enough rights 
					           |to access the volume directory.
					           |
					           |%1'");
			EndIf;
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				ErrorPattern, BriefErrorDescription(ErrorInfo));
			
			CommonUseClientServer.MessageToUser(
				ErrorText, , FullPathFieldName, "Object", Cancel);
		EndTry;
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Returns False if there is a volume of the same order
Function SequenceNumberUnique(FillOrder, VolumeRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(Volumes.FillOrder) AS Quantity
	|FROM
	|	Catalog.FileStorageVolumes AS Volumes
	|WHERE
	|	Volumes.FillOrder = &FillOrder
	|	AND Volumes.Ref <> &VolumeRef";
	
	Query.Parameters.Insert("FillOrder", FillOrder);
	Query.Parameters.Insert("VolumeRef", VolumeRef);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Quantity = 0;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf