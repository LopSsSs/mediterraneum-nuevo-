Add-Type -AssemblyName System.Drawing

$dir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$iconPath = Join-Path $dir 'icon-512.png'
$logo = [System.Drawing.Image]::FromFile($iconPath)

function New-RoundedPath($x,$y,$w,$h,$r){
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r*2
  $p.AddArc($x,$y,$d,$d,180,90)
  $p.AddArc($x+$w-$d,$y,$d,$d,270,90)
  $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90)
  $p.AddArc($x,$y+$h-$d,$d,$d,90,90)
  $p.CloseFigure()
  return $p
}

function Make-Shot($file,$W,$H,$iconSize,$iconY,$nameSize,$layout){
  $bmp = New-Object System.Drawing.Bitmap($W,$H)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'ClearTypeGridFit'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'

  # Fondo degradado verde profundo
  $rect = New-Object System.Drawing.Rectangle(0,0,$W,$H)
  $c1 = [System.Drawing.Color]::FromArgb(255,31,58,36)
  $c2 = [System.Drawing.Color]::FromArgb(255,12,22,14)
  $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,$c1,$c2,[System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
  $g.FillRectangle($lg,$rect)

  # Resplandores sutiles
  $glow1 = New-Object System.Drawing.Drawing2D.GraphicsPath
  $glow1.AddEllipse(-($W*0.15),-($H*0.2),$W*0.7,$H*0.7)
  $pgb1 = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow1)
  $pgb1.CenterColor = [System.Drawing.Color]::FromArgb(60,74,124,89)
  $pgb1.SurroundColors = @([System.Drawing.Color]::FromArgb(0,74,124,89))
  $g.FillPath($pgb1,$glow1)
  $glow2 = New-Object System.Drawing.Drawing2D.GraphicsPath
  $glow2.AddEllipse($W*0.45,$H*0.5,$W*0.7,$H*0.7)
  $pgb2 = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow2)
  $pgb2.CenterColor = [System.Drawing.Color]::FromArgb(45,201,168,76)
  $pgb2.SurroundColors = @([System.Drawing.Color]::FromArgb(0,201,168,76))
  $g.FillPath($pgb2,$glow2)

  # Logo centrado
  $ix = ($W - $iconSize)/2
  $g.DrawImage($logo,$ix,$iconY,$iconSize,$iconSize)

  # Colores texto
  $gold = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,226,196,122))
  $cream = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,245,240,232))
  $creamDim = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180,237,229,208))

  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = 'Center'

  # Wordmark "Mediterraneum" (serif elegante)
  $serif = New-Object System.Drawing.Font('Georgia',$nameSize,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $nameY = $iconY + $iconSize + ($H*0.05)
  $word = 'Mediterraneum'
  $g.DrawString($word,$serif,$cream,($W/2),$nameY,$sf)

  # Subrayado dorado fino
  $nmeas = $g.MeasureString($word,$serif)
  $lineW = $nmeas.Width*0.42
  $lineY = $nameY + $nmeas.Height + 6
  $penG = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,212,176,85),2)
  $g.DrawLine($penG,($W/2-$lineW/2),$lineY,($W/2+$lineW/2),$lineY)

  # Tagline
  $tagFont = New-Object System.Drawing.Font('Segoe UI',[int]($nameSize*0.32),[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $tagY = $lineY + ($H*0.025)
  $g.DrawString('Suite de Gestion Inteligente con IA',$tagFont,$creamDim,($W/2),$tagY,$sf)

  # Chips de funcionalidades
  $chips = @('Presupuestos IA','CRM Clientes','Maquinaria','Rutas','Equipos','Asistente IA')
  $chipFont = New-Object System.Drawing.Font('Segoe UI',[int]($nameSize*0.26),[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $padX = [int]($nameSize*0.32); $chipH = [int]($nameSize*0.95); $gap = [int]($nameSize*0.22)
  $chipSf = New-Object System.Drawing.StringFormat
  $chipSf.Alignment = 'Center'; $chipSf.LineAlignment = 'Center'
  $chipSf.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
  $chipFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40,201,168,76))
  $chipPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,201,168,76),1.5)

  if($layout -eq 'wide'){
    # Linea unica de funciones separadas por puntos dorados (siempre cabe)
    $featFont = New-Object System.Drawing.Font('Segoe UI',[int]($nameSize*0.30),[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    $dotFont  = New-Object System.Drawing.Font('Segoe UI',[int]($nameSize*0.30),[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $cy = $tagY + ($H*0.11)
    $sep = '     '
    # Mide ancho total
    $totalW = 0
    for($i=0;$i -lt $chips.Count;$i++){
      $totalW += [int]($g.MeasureString($chips[$i],$featFont).Width)
      if($i -lt $chips.Count-1){ $totalW += [int]($g.MeasureString($sep,$featFont).Width) }
    }
    $x = ($W-$totalW)/2
    $sfNW = New-Object System.Drawing.StringFormat; $sfNW.FormatFlags=[System.Drawing.StringFormatFlags]::NoWrap; $sfNW.Alignment='Near'
    for($i=0;$i -lt $chips.Count;$i++){
      $g.DrawString($chips[$i],$featFont,$cream,(New-Object System.Drawing.PointF($x,$cy)),$sfNW)
      $x += [int]($g.MeasureString($chips[$i],$featFont).Width)
      if($i -lt $chips.Count-1){
        $sw = [int]($g.MeasureString($sep,$featFont).Width)
        $g.DrawString([char]0x2022,$dotFont,$gold,(New-Object System.Drawing.PointF(($x+$sw/2-6),$cy)),$sfNW)
        $x += $sw
      }
    }
  } else {
    # Dos columnas para movil
    $colGap = 18
    $cw = [int](($W*0.74-$colGap)/2)
    $cy = $tagY + ($H*0.06)
    $leftX = ($W-($cw*2+$colGap))/2
    for($i=0;$i -lt $chips.Count;$i++){
      $col = $i % 2; $row = [math]::Floor($i/2)
      $cx = $leftX + $col*($cw+$colGap)
      $yy = $cy + $row*($chipH+$gap)
      $path = New-RoundedPath $cx $yy $cw $chipH ([int]($chipH/2))
      $g.FillPath($chipFill,$path); $g.DrawPath($chipPen,$path)
      $g.DrawString($chips[$i],$chipFont,$gold,(New-Object System.Drawing.RectangleF($cx,$yy,$cw,$chipH)),$chipSf)
    }
  }

  $g.Dispose()
  $out = Join-Path $dir $file
  $bmp.Save($out,[System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output "OK -> $out"
}

Make-Shot 'screenshot-wide.png'   1280 800  210 150 66 'wide'
Make-Shot 'screenshot-mobile.png' 720  1280 230 230 60 'mobile'

$logo.Dispose()
Write-Output "DONE"
