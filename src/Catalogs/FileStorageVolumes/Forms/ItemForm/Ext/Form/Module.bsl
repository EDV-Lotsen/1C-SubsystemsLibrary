
// Finds maximum order among the volumes
&AtServer
Function FindMaximumOrder()
	Query = New Query;
	Query.Text = "SELECT
				   |	MAX(Volumes.FillSequence) AS MaximumNumber
				   |FROM
				   |	Catalog.FileStorageVolumes AS Volumes";
	
	Selection = Query.Execute().Choose();
	If Selection.Next() Then
		If Selection.MaximumNumber = Null Then
			Return 0;
		Else
			Return Number(Selection.MaximumNumber);
		EndIf;		
	EndIf;
	
	Return 0;
EndFunction // FindMaximumOrder

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	If Object.Ref.IsEmpty() Then
		Object.FillSequence = FindMaximumOrder() + 1;
	EndIf;	
	
	If NOT Object.Ref.IsEmpty() Then
		Items.FullPathLinux.WarningOnEditRepresentation = WarningOnEditRepresentation.Show;
		Items.FullPathWindows.WarningOnEditRepresentation = WarningOnEditRepresentation.Show;
		
		CurrentSizeInBytes = FileOperations.CalculateFilesSizeOnVolume(Object.Ref); 
		CurrentSize = CurrentSizeInBytes / (1024 * 1024);
	EndIf;	
	
	ServerPlatformType = FileOperationsSecondUse.ServerPlatformType();
	If ServerPlatformType = PlatformType.Windows_x86 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		Items.FullPathWindows.AutoMarkIncomplete = True;
	Else
		Items.FullPathLinux.AutoMarkIncomplete = True;
	EndIf;	
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancellation, WriteParameters)
	
	// Add closing slash, if it is missing
	If Not IsBlankString(Object.FullPathWindows) Then
		If Right(Object.FullPathWindows, 1) <> "\" Then
			Object.FullPathWindows = Object.FullPathWindows + "\";
		EndIf;
		
		If Right(Object.FullPathWindows, 2) = "\\" Then
			Object.FullPathWindows = Left(Object.FullPathWindows, StrLen(Object.FullPathWindows) - 1);
		EndIf;
	EndIf;
	
	// Add closing slash, if it is missing
	If Not IsBlankString(Object.FullPathLinux) Then
		If Right(Object.FullPathLinux, 1) <> "\" Then
			Object.FullPathLinux = Object.FullPathLinux + "\";
		EndIf;
		
		If Right(Object.FullPathLinux, 2) = "\\" Then
			Object.FullPathLinux = Left(Object.FullPathLinux, StrLen(Object.FullPathLinux) - 1);
		EndIf;
	EndIf;
	
EndProcedure
