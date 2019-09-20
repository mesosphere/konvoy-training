# Instructor Guide for Konvoy Workshops
This guide will walk you through prepping for a D2iQ Konvoy Workshop:

This guide assumes all workshop prep activities will be preformed from an SE laptop with the following prerequisites installed and working:

- MAWS with salesleadgen account access (see regional SE manager for access) https://github.com/mesosphere/maws
- Github with access to the mesosphere repos and configured per IT recommendations: https://wiki.mesosphere.com/display/MSPHERE/Setting+up+your+computer
- WorkshopJumpServer keys downloaded and identity added from the secure notes in Onelogin. (provides instructor/se access into all workshop jump servers)
- Access to the Konvoy Workshops - Lab Environments Google drive. https://drive.google.com/drive/u/2/folders/0AFXn3fuo6X2WUk9PVA

# Deploying workshop jump servers

Follow instructions on the WorkshopJumpServers repo https://github.com/mesosphere/workshopjumpservers

# Uploading SSH Keys to Google Drive

From the terraform folder (~/WorkshopJumpServers/aws-us-west-2/) Copy all id_rsa_student# pem files to the google share drive location for the students to access. https://drive.google.com/drive/u/2/folders/0AFXn3fuo6X2WUk9PVA

# Creating and Updating a Google Sheet with Student Jump Server Information

1. From the terraform folder (~/WorkstationJumpServers/aws-us-west-2/) run the studentoutput.sh script.  This will create a studentoutput.txt file that can be imported into the example google sheet.
2. Open the Student_Data spreadsheet from the templates directory on the Google Drive: https://drive.google.com/drive/u/2/folders/0AFXn3fuo6X2WUk9PVA
3. Copy the spreadsheet to the Google Drive location for the workshop.
4. Open the "Student_Data" spreadsheet from the workshop folder and select cell A2.
5. Select File-Import on the Google Sheets menu.
6. Select Upload a file from your device and select the studentoutput.txt file from the terraform folder used to deploy the WorkshopJumpServers.
7. From the import file window:
   1. Select replace data at selected cell for the import file location
   2. Select comma for separator type
8. Click import data.
9. The Students should enter their name in the Student Name column.
10. Share the workshop folder 

# Be sure to update your Lab presentation with the location of the Google Drive share for the workshop.

⚠️***Warning***: Remember to remove sharing once the workshop is complete.
