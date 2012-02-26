
////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Function returns default value for the passed user and setting.
//
// Parameters:
//  User 		- Program current user
//  Setting     - Flag, for which default value is being returned
//
// Value returned:
//  Default value for the setting.
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

	Selection  = Query.Execute().Choose();

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

EndFunction // GetValueByDefaultUser()

