#################################################################################################################################################
# Extract-StudyTags
#################################################################################################################################################
function Extract-StudyTags {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $dicomFile   = [Dicom.DicomFile]::Open($File.FullName)
    $dataset     = $dicomFile.Dataset
    $method      = [Dicom.DicomDataset].GetMethod("GetSingleValueOrDefault").MakeGenericMethod([string])

    $patientName = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientName,      [string]""))
    $patientDob  = $method.Invoke($dataset, @([Dicom.DicomTag]::PatientBirthDate, [string]""))
    $studyDate   = $method.Invoke($dataset, @([Dicom.DicomTag]::StudyDate,        [string]""))
    $modality    = $method.Invoke($dataset, @([Dicom.DicomTag]::Modality,         [string]""))
    $studyUID    = $method.Invoke($dataset, @([Dicom.DicomTag]::StudyInstanceUID, [string]""))

    $result      = New-Object PSObject -Property @{
        PatientName      = $patientName
        PatientDob       = $patientDob
        StudyDate        = $studyDate
        Modality         = $modality
        StudyInstanceUID = $studyUID
    }

    return $result
}
#################################################################################################################################################


#################################################################################################################################################
# GetHashFrom-StudyTags
#################################################################################################################################################
function GetHashFrom-StudyTags {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$StudyTags
    )

    $hashInput     = "$($StudyTags.PatientName)-$($StudyTags.PatientDob)-$($StudyTags.StudyDate)-$($StudyTags.Modality)-$($StudyTags.StudyInstanceUID)"

    Write-Indented "Hash Input: $hashInput"

    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create("MD5")
    $hashBytes     = $hashAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
    $hashOutput    = [System.BitConverter]::ToString($hashBytes).Replace("-", "")
    
    Write-Indented "Hash Output: $hashOutput"

    return $hashOutput
}
#################################################################################################################################################


#################################################################################################################################################
# WriteIndented-StudyTags
#################################################################################################################################################
function WriteIndented-StudyTags {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject]$StudyTags)
   
    Write-Indented "Patient Name:     $($StudyTags.PatientName)"
    Write-Indented "Patient DOB:      $($StudyTags.PatientDob)"
    Write-Indented "Study Date:       $($StudyTags.StudyDate)"
    Write-Indented "Modality:         $($StudyTags.Modality)"
    Write-Indented "StudyInstanceUID: $($StudyTags.StudyInstanceUID)"
}
#################################################################################################################################################


