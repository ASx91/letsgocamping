# Static file server using raw TcpListener (no HTTP.sys / no admin required)
$port = if ($env:PORT) { [int]$env:PORT } else { 4200 }
$root = "C:\Users\ariel\Desktop\Claude\Malibu 2k26"

$mime = @{
  ".html"  = "text/html; charset=utf-8"
  ".css"   = "text/css"
  ".js"    = "application/javascript"
  ".png"   = "image/png"
  ".jpg"   = "image/jpeg"
  ".jpeg"  = "image/jpeg"
  ".svg"   = "image/svg+xml"
  ".ico"   = "image/x-icon"
  ".json"  = "application/json"
  ".woff2" = "font/woff2"
  ".woff"  = "font/woff"
}

$ep  = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback, $port)
$srv = [System.Net.Sockets.TcpListener]::new($ep)
$srv.Start()
Write-Host "Camp Malibu serving at http://127.0.0.1:$port/"
[Console]::Out.Flush()

try {
  while ($true) {
    $client = $srv.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $buf = New-Object byte[] 8192
      $n   = $stream.Read($buf, 0, $buf.Length)
      if ($n -eq 0) { $client.Close(); continue }
      $req = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)

      # Parse GET /path HTTP/1.x
      $path = "/"
      if ($req -match "^GET ([^\s]+)") { $path = $Matches[1] }
      if ($path -eq "/" -or $path -eq "") { $path = "/index_7.html" }
      $path = ($path -split "\?")[0]  # strip query string
      $path = [System.Uri]::UnescapeDataString($path)  # decode %20 etc.

      $file = Join-Path $root ($path.TrimStart("/").Replace("/", "\"))

      if (Test-Path $file -PathType Leaf) {
        $ext  = [System.IO.Path]::GetExtension($file).ToLower()
        $ct   = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $body = [System.IO.File]::ReadAllBytes($file)
        $hdr  = "HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      } else {
        $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
        $hdr  = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      }

      try {
        $hb = [System.Text.Encoding]::ASCII.GetBytes($hdr)
        $stream.Write($hb, 0, $hb.Length)
        $stream.Write($body, 0, $body.Length)
        $stream.Flush()
      } catch {
        # Client disconnected mid-response — ignore and continue
      }
    } catch {
      # Malformed request or read error — ignore
    } finally {
      try { $client.Close() } catch {}
    }
  }
} finally {
  try { $srv.Stop() } catch {}
}
