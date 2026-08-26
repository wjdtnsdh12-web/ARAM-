$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter SDK가 없어. https://docs.flutter.dev/get-started/install/windows 에서 먼저 설치해줘."
}

if (-not (Test-Path "android")) {
    flutter create --platforms=android --org com.soonolab .
}

$manifest = "android\app\src\main\AndroidManifest.xml"
$manifestText = Get-Content $manifest -Raw
if ($manifestText -notmatch "android.permission.INTERNET") {
    $manifestText = $manifestText -replace '(<manifest[^>]*>)', "`$1`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
    Set-Content $manifest $manifestText -Encoding UTF8
}

flutter pub get
flutter test
flutter build apk --release

$source = "build\app\outputs\flutter-apk\app-release.apk"
$target = "build\app\outputs\flutter-apk\ARAM-AI-Analyzer-OpenAI-v0.2.0.apk"
Copy-Item $source $target -Force
Write-Host "APK: $target"
