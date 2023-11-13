#################################################################################################################################################
# Include required function libs:
#################################################################################################################################################
# These included files depend on each other and on globals defined here, so removing any of them is likely to cause problems: the are just being
# used to keep the functions organized instead of having one huge file, not to make dependency management resilient.
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\utility-funs.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\dicom-funs.ps1")
#################################################################################################################################################


#################################################################################################################################################
# Globals meant to be used for configuration purposes, user may change as required:
#################################################################################################################################################
$global:sleepSeconds             = 0 # if greater than 0 script will loop, sleeping $global:sleepSeconds seconds each time.
$global:mtimeThreshholdSeconds   = 3
$global:largeFileThreshholdBytes = 50000
$global:rejectByDeleting         = $true
#================================================================================================================================================
$global:qrServerAE               = "HOROS"
$global:qrServerHost             = "localhost"
$global:qrServerPort             = 2763
$global:qrDestAE                 = "FLUXTEST1AB"
$global:myAE                     = "QR-TOOL"
#################################################################################################################################################


#################################################################################################################################################
# Require some directories:
#################################################################################################################################################
$cacheDirBasePath            = $PSScriptRoot
$incomingStoredItemsDirPath  = Join-Path -Path $cacheDirBasePath -ChildPath "incoming-stored-items"
$queuedStoredItemsDirPath    = Join-Path -Path $cacheDirBasePath -ChildPath "queued-stored-items"
$processedStoredItemsDirPath = Join-Path -Path $cacheDirBasePath -ChildPath "processed-stored-items"
$rejectedStoredItemsDirPath  = Join-Path -Path $cacheDirBasePath -ChildPath "rejected-stored-items"
#================================================================================================================================================
Require-DirectoryExists -DirectoryPath $cacheDirBasePath            # if this doesn't already exist, assume something is seriously wrong, bail.
Require-DirectoryExists -DirectoryPath $incomingStoredItemsDirPath  # if this doesn't already exist, assume something is seriously wrong, bail.
Require-DirectoryExists -DirectoryPath $queuedStoredItemsDirPath    -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $processedStoredItemsDirPath -CreateIfNotExists $true
Require-DirectoryExists -DirectoryPath $rejectedStoredItemsDirPath  -CreateIfNotExists $true
#################################################################################################################################################


#################################################################################################################################################
# Set up packages (well, just fo-dicom presently):
#################################################################################################################################################
$packagesDirPath        = Join-Path -Path $PSScriptRoot -ChildPath "packages"
$foDicomName            = "fo-dicom.Desktop"
$foDicomVersion         = "4.0.8"
$foDicomDirPath         = Join-Path -Path $packagesDirPath          -ChildPath "$foDicomName.$foDicomVersion"
$foDicomExpectedDllPath = Join-Path -Path $foDicomDirPath           -ChildPath "lib\net45\Dicom.Core.dll"
#================================================================================================================================================
Require-NuGetPackage `
-PackageName $foDicomName `
-PackageVersion $foDicomVersion `
-ExpectedDllPath $foDicomExpectedDllPath `
-DestinationDir $packagesDirPath
#================================================================================================================================================
$null = [Reflection.Assembly]::LoadFile($foDicomExpectedDllPath)
#################################################################################################################################################


#################################################################################################################################################
# Main:
#################################################################################################################################################
do {
    #############################################################################################################################################
    # Pass #1/2: Examine files in $incomingStoredItemsDirPath and either accept them by moving them to $queuedStoredItemsDirPath or reject them.
    #############################################################################################################################################
    
    $filesInIncomingStoredItemsDir = Get-ChildItem -Path $incomingStoredItemsDirPath -Filter *.dcm

    if ($filesInIncomingStoredItemsDir.Count -eq 0) {
        Write-Indented "Pass #1: No DCM files found in incomingStoredItemsDir."
    } else {
        $counter = 0
        
        Write-Indented "Pass #1: Found $($filesInIncomingStoredItemsDir.Count) files in incomingStoredItems."

        Indent
        
        foreach ($file in $filesInIncomingStoredItemsDir) {
            $counter++

            Write-Indented "Processing file #$counter/$($filesInIncomingStoredItemsDir.Count) '$($file.FullName)'..."
            
            Indent
            
            $lastWriteTime = $file.LastWriteTime
            $timeDiff      = (Get-Date) - $lastWriteTime

            if (File-IsTooFresh -File $file) {
                continue
            }

            $tags = Extract-StudyTags -File $file

            WriteStudyTags-Indented -StudyTags $tags
            
            $studyHash                        = GetHashFrom-StudyTags -StudyTags $tags 
            $possibleQueuedStoredItemsPath    = Join-Path -Path $queuedStoredItemsDirPath    -ChildPath "$studyHash.dcm"
            $possibleProcessedStoredItemsPath = Join-Path -Path $processedStoredItemsDirPath -ChildPath "$studyHash.dcm"

            $foundFile = $null

            if (Test-Path -Path $possibleQueuedStoredItemsPath) {
                $foundFile = $possibleQueuedStoredItemsPath
            } elseif (Test-Path -Path $possibleProcessedStoredItemsPath) {
                $foundFile = $possibleProcessedStoredItemsPath
            }

            if ($foundFile -eq $null) {                
                Write-Indented "Enqueuing $($file.FullName) as $possibleQueuedStoredItemspath."
                MaybeStripPixelDataAndThenMoveTo-Path -File $file -Destination $possibleQueuedStoredItemsPath
            } else {
                Write-Indented "Item for hash $studyHash already exists in one of our directories as $foundFile, rejecting."
                Reject-File -File $file -RejectedDirPath $rejectedStoredItemsDirPath
            }
            
            Outdent
        } # foreach $file
        #########################################################################################################################################

        Outdent
    } # Pass #1/2
    #############################################################################################################################################

    #############################################################################################################################################
    # Pass #2/2: Examine files in $queuedStoredItemsDirPath, issue move requests for them and then move them to $processedStoredItemsPath.
    #############################################################################################################################################

    $filesInQueuedStoredItemsDir = Get-ChildItem -Path $queuedStoredItemsDirPath -Filter *.dcm

    if ($filesInQueuedStoredItemsDir.Count -eq 0) {
        Write-Indented "Pass #2: No DCM files found in queuedStoredItems."
    } else {
        $counter = 0
        
        Write-Indented "Pass #2: Found $($filesInQueuedStoredItemsDir.Count) files in queuedStoredItems."

        Indent
        
        foreach ($file in $filesInQueuedStoredItemsDir) {
            $counter++

            Write-Indented "Processing file #$counter/$($filesInQueuedStoredItemsDir.Count) '$($file.FullName)'..."
            
            Indent
            
            $tags = Extract-StudyTags -File $file

            WriteStudyTags-Indented -StudyTags $tags
            MoveStudyBy-StudyInstanceUID $tags.StudyInstanceUID
            
            $processedStoredItemPath = Join-Path -Path $processedStoredItemsDirPath -ChildPath $file.Name

            Write-Indented "Moving $($file.FullName) to $processedStoredItemPath"
            Move-Item -Path $File.FullName -Destination $processedStoredItemPath
            
            Outdent
        } # foreach $file
        #####################################################################################################################################
        
        Outdent
    } # Pass #2/2
    #############################################################################################################################################
    
    #############################################################################################################################################
    # All passes complete, maybe sleep and loop, otherwise fall through and exit.
    #############################################################################################################################################
    if ($global:sleepSeconds -gt 0) {
        Write-Indented "Sleeping $($global:sleepSeconds) seconds..." -NoNewLine
        Start-Sleep -Seconds $global:sleepSeconds
        Write-Host " done."
    }
    #############################################################################################################################################
} while ($global:sleepSeconds -gt 0)#
#################################################################################################################################################
Write-Indented "Done."
