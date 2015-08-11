﻿
////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Returns the default value for the passed user and options.
//
// Parameters:
//  User 	- current user.
//  Options - flag whose default value is returned.
//
// Returns:
//  Default value for the options.
//
Function GetValueByDefaultUser(User, Options) Export

	Query = New Query;
	Query.SetParameter("User", User);
	Query.SetParameter("Options"   , ChartsOfCharacteristicTypes.UsersSettings[Options]);
	Query.Text = "SELECT
	             |	RegisterValueRight.Value
	             |FROM
	             |	InformationRegister.UsersSettings AS RegisterValueRight
	             |WHERE
	             |	RegisterValueRight.User = &User
	             |	AND RegisterValueRight.Options = &Options";

	Selection  = Query.Execute().Select();

	EmptyValue = ChartsOfCharacteristicTypes.UsersSettings[Options].ValueType.AdjustValue();

	If Selection.Count() = 0 Then
		
		Return EmptyValue;

	ElsIf Selection.Next() Then

		If NOT ValueIsFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;

	Else
		Return EmptyValue;

	EndIf;

EndFunction

