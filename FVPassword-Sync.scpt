-- Author: Bernardo Prieto
-- License: MIT

-- Path to local icon. Can be changed to reflect company identity.
set logopath to "/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/Assistant.icns"

-- Temp file to store a temporary password only in case of failure
set PWPATH to "/Library/Application Support/JAMF/pwd.txt"

-- URL to Domain Controller. Used to verify the user is not connected.
set dcurl to "corp.mycompany.net"

-- Path to Domains. Used to check the password of current user.
set domainPath to "/Active\\ Directory/CORP/All\\ Domains"

-- Standard texts for the messages.
set title_text to "FileVault Password Sync"
set welcome_text to "This application will synchronize your passwords."
set disconnect_text to "ATTENTION:

Please disconnect from the network, both Ethernet and Wi-Fi and then click OK."
set temp_user_text to "An old temporary user is present and needs to be removed. Please click OK and authenticate in order to do it."
set current_password_text to "Please enter your CURRENT password:"
set current_password_error to "Your CURRENT password was mistyped.
Please try again."
set adding_temp_text to "A new temporary user is needed for this process. Please click OK and then authenticate in order to create it.
This may require your OLD password."
set removing_FV_text to "Temporarily removing your user from FileVault."
set reconnect_text to "ATTENTION:

Please connect to the network, then click OK."
set adding_FV_text to "Adding your user back to FileVault."
set before_users_list to "You will be asked to authenticate to verify the list of FileVault users. Use your CURRENT password here."
set show_users_list to "Make sure your user appears in the following list of FileVault users. If it doesn't, please click NO and contact Helpdesk.

"
set final_ok to "Your passwords are now in sync!"
set final_fail to "Please DO NOT REBOOT OR SHUT DOWN THE MACHINE AT THIS POINT. Contact helpdesk to escalate the case."

-- FUNCTIONS --

-- Checks the machine is connected to Company network pinging the DC 
on CompanyCheck()
	try
		set ping to (do shell script "ping -c 2 " & dcurl)
		if ping contains "64 bytes" then set networkUp to true
		return true
	on error
		set networkUp to false
		return false
	end try
end CompanyCheck

-- Check connection to Company AD by a DSCL query. Should be tweaked according to company's AD to get valid replies.
on adCheck()
	set ad_check to (do shell script "dscl " & domainPath & " -list /Places; echo $?")
	if ad_check contains 0 then
		writeToLog("Machine bound to AD. Continue.")
		return true
	else
		return false
	end if
end adCheck

-- Check if a previous instance of the FVuser exists, to delete it before starting.
set FVUSER to "fvuser"
set FVPASSWORD to generateFVPass()
set removeUser to "set timeout -1
set FVUSER \"" & FVUSER & "\"
set FVPASSWORD \"" & FVPASSWORD & "\"
set USER \"$env(USER)\"
spawn su ${FVUSER} -c \"sudo fdesetup remove -user $USER\"
expect \"Password:\" {
        send \"$FVPASSWORD\\r\"
}
expect \"Password:\" {
        send \"$FVPASSWORD\\r\"
        expect eof
}"
on checkForTemporaryUser()
	tell application "System Events" to name of every user contains "fvuser"
	
	if result then
		return true
	end if
	return false
end checkForTemporaryUser

-- Checks the current password (provided earlier by the user) against AD using a login command
on currentPasswordCheck(PWDTEST)
	set checkUser to "set timeout 3
set ADUSER \"$env(USER)\"
set ADPASSWORD \"" & PWDTEST & "\"
spawn login ${ADUSER}
expect \"Password:\" {
	send \"$ADPASSWORD\\r\"
	expect eof
}"
	try
		set out to do shell script "expect <<< " & quoted form of checkUser
		if out contains "Login incorrect" then
			return false
		else
			return true
		end if
	on error
		return false
	end try
end currentPasswordCheck

-- Log to local log (/var/log/locallog.log) useful for troubleshooting
on writeToLog(message)
	try
		set the log_file to "/private/var/log/locallog.log"
		do shell script "NOW=$(date '+%Y-%m-%d %H:%M:%S'); echo [FVUpdate] $NOW - " & quoted form of message & " >> " & quoted form of log_file
		return true
	on error
		return false
	end try
end writeToLog

-- Creates a random 20 char string to use as the password for the fvuser
on generateFVPass()
	set randomString to ""
	
	repeat with x from 1 to 20
		set randomChar to ASCII character (random number from 97 to 122)
		set randomString to randomString & randomChar
	end repeat
	
	return randomString
end generateFVPass

-- Execution start
writeToLog("Execution of FVUpdater started")

--Checks AD binding
if adCheck() is false then
	writeToLog("The machine is not bound to AD. Stop execution")
	display dialog "The machine MUST be bound to Company AD in order to fix this issue. Please contact Help Desk" buttons {"OK"} default button 1 with icon stop with title title_text
	error number -128
end if

--Initial message
display dialog welcome_text buttons {"OK"} default button 1 with icon {logopath} with title title_text

-- Waits for network connection
repeat while not NetworkCheck()
	writeToLog("Network is not connected. Asking user  to connect.")
	display dialog reconnect_text buttons {"OK"} default button 1 with icon {logopath} with title title_text
end repeat

-- Gets the CURRENT password
writeToLog("Current password requested")
display dialog current_password_text buttons {"OK"} default answer "" default button "OK" with icon {logopath} with title title_text with hidden answer
set PASSWD to (text returned of result)

-- Verifies the provided password is correct
repeat while currentPasswordCheck(PASSWD) is false
	display dialog current_password_error buttons {"OK"} default answer "" default button "OK" with icon {logopath} with title title_text with hidden answer
	set PASSWD to (text returned of result)
end repeat

set networkUp to true
-- Asks the user to disconnect
repeat while NetworkCheck()
	writeToLog("Network is connected. Asking user  to disconnect.")
	display dialog disconnect_text buttons {"OK"} default button 1 with icon {logopath} with title title_text
end repeat

-- Checks for a previous user
repeat while checkForTemporaryUser()
	writeToLog("Temporary user is present. Will try to delete.")
	display dialog temp_user_text buttons {"OK"} default button 1 with icon {logopath} with title title_text
	tell application "Terminal" to do shell script ("sysadminctl interactive -deleteUser fvuser")
end repeat

-- Once the machine is not connected
if not NetworkCheck() then
	
	-- Add the temporary user
	writeToLog("Adding temporary user")
	display dialog adding_temp_text buttons {"OK"} default button 1 with icon {logopath} with title title_text
	tell application "Terminal"
		set currentTab to do shell script ("sysadminctl interactive -addUser " & FVUSER & " -admin -password \"" & FVPASSWORD & "\"")
	end tell
	
	-- Removes affected user from FileVault
	writeToLog("Removing user from FileVault")
	display dialog removing_FV_text buttons {"OK"} default button 1 with icon {logopath} with title title_text
	tell application "Terminal"
		set currentTab to do shell script "expect <<<" & quoted form of removeUser
		#set currentTab to do script "echo Test"
	end tell
	
	-- Asks the user to reconnect
	repeat while not NetworkCheck()
		writeToLog("Asking the user to reconnect to network.")
		display dialog reconnect_text buttons {"OK"} default button 1 with icon {logopath} with title title_text
		delay 3
	end repeat
	
	-- Adds the user back to FileVault. This should grant a correct Secure Token to the user.
	writeToLog("Adding the user back to FileVault.")
	set addUser to "set timeout -1
set FVUSER \"" & FVUSER & "\"
set FVPASSWORD \"" & FVPASSWORD & "\"
set USER \"$env(USER)\"
set PASSWORD \"" & PASSWD & "\"
spawn su ${FVUSER} -c \"sudo fdesetup add -usertoadd ${USER}\"
expect \"Password:\" {
	send \"$FVPASSWORD\\r\"
}
expect \"Password:\" {
	send \"$FVPASSWORD\\r\"

}
expect \"Enter the user name:\" {
	send \"$FVUSER\\r\"

}
expect \"Enter the password for user '$FVUSER':\" {
	send \"$FVPASSWORD\\r\"

}
expect \"Enter the password for the added user '$USER':\" {
       send \"$PASSWORD\\r\"
       expect eof
 #       interact
}"
	display dialog adding_FV_text buttons {"OK"} default button 1 with icon {logopath} with title title_text
	tell application "Terminal"
		set currentTab to do shell script "expect <<<" & quoted form of addUser
	end tell
	
	-- Notify the user about the list of FVUsers
	display dialog before_users_list buttons {"OK"} default button 1 with icon {logopath} with title title_text
	
	-- Gets the list of FVUsers and displays it
	writeToLog("Checking FileVault users:")
	set out to do shell script "fdesetup list" with administrator privileges
	writeToLog(out)
	set answer to the button returned of (display dialog show_users_list & out buttons {"Yes", "No"} default button 1 with icon {logopath} with title title_text)
	
	-- If the users sees himself in the list, we delete the user and finish.
	if answer is "Yes" then
		writeToLog("User clicked Yes. Will delete temporary user.")
		do shell script "sysadminctl -deleteUser " & FVUSER with administrator privileges
		display dialog final_ok buttons {"OK"} default button 1 with icon {logopath} with title title_text
	else
		-- Otherwise, we keep the FVuser and store its password safely (/Library/Application Support/JAMF/pwd.txt)
		writeToLog("User clicked NO. Won't delete temporary user.")
		do shell script "echo " & quoted form of FVPASSWORD & " > " & quoted form of PWPATH with administrator privileges
		do shell script "chown root:wheel " & quoted form of PWPATH with administrator privileges
		do shell script "chmod 740 " & quoted form of PWPATH with administrator privileges
		display dialog final_fail buttons {"OK"} default button 1 with icon {logopath} with title title_text
	end if
end if