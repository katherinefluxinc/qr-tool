## QR Tool

A script for automating pre-fetching studies by automatically performing find and move queries based on tags in observed files.

### Build notes:

Prior to runninig qr-tool.ps1, build the FoDicomCmdlets solution in Release mode as the script will need to make use of both the DLL it will build and the copy of fo-dicom that it will install's DLL.
