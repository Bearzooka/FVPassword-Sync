# FVPassword-Sync
![AppleScript](https://img.shields.io/badge/AppleScript-2.7-green.svg)

![Version](https://img.shields.io/badge/Version-1.0.1-lightgrey.svg)

Since the update to macOS Mojave, the synchronization between Network password (from AD) and Encryption Password (from FileVault) has been very problematic.

This AppleScript addresses this out-of-sync issue by creating an additional user (which will have a valid SecureToken) and then removing and readding the affected user in order to grant it a valid SecureToken.
## Requirements and Settings
- The script works **ONLY** on cases in which one of the passwords is valid on Active Directory (ONLINE) and the other is valid for FileVault (OFFLINE).
- The user MUST know both passwords, which will be used during the process.
- It's **necessary** to configure the initial variables to have the *Domain Controller* url and the *Active Directory* path to query a valid connection.
- It's possible to modify the path used on the logging function as well as the logo used for the alerts.
