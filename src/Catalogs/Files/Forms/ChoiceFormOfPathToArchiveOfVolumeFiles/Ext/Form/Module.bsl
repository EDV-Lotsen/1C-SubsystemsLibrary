

&AtClient
Procedure Place1(Command)
	
	ClearMessages();
	
	If IsBlankString(PathToWindowsArchive) And IsBlankString(PathToLinuxArchive) Then
		Text = NStr("en = 'Specify the full name of the archive with files of the initial image (file *.zip)'");
		CommonUseClientServer.MessageToUser(Text, , "PathToWindowsArchive");
		Return;
	EndIf;	
	
	If Not IsBlankString(PathToWindowsArchive) And (Left(PathToWindowsArchive, 2) <> "\\" OR Find(PathToWindowsArchive, ":") <> 0) Then
		ErrorText = NStr("en = 'Path to archive initial image files must be in the UNC format (\\servername\resource)'");
		CommonUseClientServer.MessageToUser(ErrorText, , "PathToWindowsArchive");
		Return;
	EndIf;	
	
	
	Status(NStr("en = 'Data exchange'"), ,
						 NStr("en = 'Placing files form archive with files of initial image'"),
						 PictureLib.CreateInitialImage);
	
	FileExchange.AddFilesToVolumes(PathToWindowsArchive, PathToLinuxArchive);
	
	DoMessageBox(NStr("en = 'Placing files from archive with files of the initial image has successfully completed'"));
	
EndProcedure
