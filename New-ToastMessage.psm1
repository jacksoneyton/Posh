function New-ToastMessage
{
<#
        .SYNOPSIS
        Displays a toast notification with a message and optional image.
        .DESCRIPTION
        Displays a toast notification with a message and optional image.
        .PARAMETER message
        The text message you want to display in your toast.
        .PARAMETER ActionCentre
        Send this to the action centre.
        .PARAMETER image
        An image that you wish to display alongside the message.
        .EXAMPLE
        New-ToastMessage -message "Alert: Disk Space Low (5%)" -image 'C:\Windows\LTSvc\LabTech.ico'
        .EXAMPLE
         New-ToastMessage -message "Alert: Disk Space Low (5%)" -image 'C:\Windows\LTSvc\LabTech.ico' -ActionCenter
#>

param(
    [Parameter(Mandatory = $true,HelpMessage = 'Toast Message?')]
    [String]
    $Message,

    [Parameter(HelpMessage = 'Send to action centre')]
    [Switch]
    $ActionCentre,

    [Parameter(Mandatory = $false,HelpMessage = 'Path to image?')]
    [String]
    $Image
)

$ErrorActionPreference = 'Stop'

#$notificationTitle = [DateTime]::Now.ToShortTimeString() + ': ' + $Message
$notificationTitle = 'Hello! ' + $Message + '    --SENT: ' + [DateTime]::Now.ToShortTimeString()

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null

if($Image)
{
    $templateType = 'ToastImageAndText01'
}
else
{
    $templateType = 'ToastText01'
}

$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::$templateType)

#Convert to .NET type for XML manipuration
$toastXml = [xml]$template.GetXml()

if($Image)
{
    $toastXml.GetElementsByTagName('image').SetAttribute('src',$Image) > $null
    $toastXml.GetElementsByTagName('image').SetAttribute('alt','overlay text') > $null
}
$toastXml.GetElementsByTagName('text').AppendChild($toastXml.CreateTextNode($notificationTitle)) > $null

#Convert back to WinRT type
$xml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml.OuterXml)

$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
$toast.Tag = 'Moriarty'
$toast.Group = 'Moriarty'
$toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)
if($actioncentre)
{
    $toast.SuppressPopup = $false
}
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Moriarty')
$notifier.Show($toast)
}
