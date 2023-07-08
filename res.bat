<# : Batch portion
@echo off & setlocal enabledelayedexpansion

REM Check if winget is installed
where winget >nul 2>nul

if %errorlevel% equ 0 (
    echo winget is installed on this machine.   
) else (
    echo winget is not installed on this machine.
    echo Please install winget from "https://apps.microsoft.com/store/detail/appinstaller/9NBLGGH4NNS1?hl=de-de&gl=de&rtc=1"
    echo and try again.
    pause
    exit    
)

ECHO Installing Python and required packages...

winget install python
pip install pyautogui pywinauto argparse

CLS

set "menu[0]=1440x1080"
set "menu[1]=1920x1080"

set "default=0"

powershell -noprofile "iex (${%~f0} | out-string)"
echo You chose !menu[%ERRORLEVEL%]!.

goto :EOF
: end batch / begin PowerShell hybrid chimera #>

$menutitle = "What resolution do you want to use?"
$menuprompt = "Use the arrow keys.  Hit Enter to select."
$menufgc = "white"
$menubgc = "black"

[int]$selection = $env:default
$h = $Host.UI.RawUI.WindowSize.Height
$w = $Host.UI.RawUI.WindowSize.Width

# assume the dialog must be at least as wide as the menu prompt
$len = [math]::max($menuprompt.length, $menutitle.length)

# get all environment vars matching menu[int]
$menu = gci env: | ?{ $_.Name -match "^menu\[(\d+)\]$" } | sort @{

    # sort on array index as int
    Expression={[int][RegEx]::Match($_.Name, '\d+').Value}

} | %{
    $val = $_.Value.trim()
    # truncate long values
    if ($val.length -gt ($w - 8)) { $val = $val.Substring(0,($w - 11)) + "..." }
    $val
    # as long as we're looping through all vals anyway, check whether the
    # dialog needs to be widened
    $len = [math]::max($val.Length, $len)
}

# dialog must accomodate string length + box borders + idx label
$dialogwidth = $len + 8

# center horizontally
$xpos = [math]::floor(($w - $dialogwidth) / 2)

# center at top 1/3 of the console
$ypos = [math]::floor(($h - ($menu.Length + 4)) / 3)

# Is the console window scrolled?
$offY = [console]::WindowTop

# top left corner coords...
$x = [math]::max(($xpos - 1), 0); $y = [math]::max(($offY + $ypos - 1), 0)
$coords = New-Object Management.Automation.Host.Coordinates $x, $y

# ... to the bottom right corner coords
$rect = New-Object Management.Automation.Host.Rectangle `
    $coords.X, $coords.Y, ($w - $xpos + 1), ($offY + $ypos + $menu.length + 4 + 1)

# The original console contents will be restored later.
$buffer = $Host.UI.RawUI.GetBufferContents($rect)

function destroy { $Host.UI.RawUI.SetBufferContents($coords,$buffer) }

$box = @{
    "nw" = [char]0x2554     # northwest corner
    "ns" = [char]0x2550     # horizontal line
    "ne" = [char]0x2557     # northeast corner
    "ew" = [char]0x2551     # vertical line
    "sw" = [char]0x255A     # southwest corner
    "se" = [char]0x255D     # southeast corner
    "lsel" = [char]0x2192   # right arrow
    "rsel" = [char]0x2190   # left arrow

}

function WriteTo-Pos ([string]$str, [int]$x = 0, [int]$y = 0,
    [string]$bgc = $menubgc, [string]$fgc = $menufgc) {
    $saveY = [console]::CursorTop
    [console]::setcursorposition($x,$offY+$y)
    Write-Host $str -b $bgc -f $fgc -nonewline
    [console]::setcursorposition(0,$saveY)
}

# Wait for keypress of a recognized key, return virtual key code
function getKey {

    # PgUp/PgDn + arrows + enter + 0-9
    $valid = 33..34 + 37..40 + 13 + 48..(47 + [math]::min($menu.length, 10))

    # 10=a, 11=b, etc.
    if ($menu.length -gt 10) { $valid += 65..(54 + $menu.length) }

    while (-not ($valid -contains $keycode)) {
        $keycode = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode
    }
    $keycode
}

# for centering the title and footer prompt
function center([string]$what, [string]$fill = " ") {
    $lpad = $fill * [math]::max([math]::floor(($dialogwidth - 4 - $what.length) / 2), 0)
    $rpad = $fill * [math]::max(($dialogwidth - 4 - $what.length - $lpad.length), 0)
    "$lpad $what $rpad"
}

function menu {
    $y = $ypos
    WriteTo-Pos ($box.nw + (center $menutitle $box.ns) + $box.ne) $xpos ($y++)
    WriteTo-Pos ($box.ew + (" " * ($dialogwidth - 2)) + $box.ew) $xpos ($y++)

    # while $item can equal $menu[$i++] without error...
    for ($i=0; $item = $menu[$i]; $i++) {
        $rtpad = " " * [math]::max(($dialogwidth - 8 - $item.length), 0)
        if ($i -eq $selection) {
            WriteTo-Pos ($box.ew + "  " + $box.lsel + " $item " + $box.rsel + $rtpad `
                + $box.ew) $xpos ($y++) $menufgc $menubgc
        } else {
            # if $i is 2 digits, switch to the alphabet for labeling
            $idx = $i; if ($i -gt 9) { [char]$idx = $i + 55 }
            WriteTo-Pos ($box.ew + " $idx`: $item  $rtpad" + $box.ew) $xpos ($y++)
        }
    }
    WriteTo-Pos ($box.sw + ([string]$box.ns * ($dialogwidth - 2) + $box.se)) $xpos ($y++)
    WriteTo-Pos (" " + (center $menuprompt) + " ") $xpos ($y++)
    1
}

while (menu) {

    [int]$key = getKey

    switch ($key) {

        33 { $selection = 0; break }    # PgUp/PgDn
        34 { $selection = $menu.length - 1; break }

        37 {}   # left or up
        38 { if ($selection) { $selection-- }; break }

        39 {}   # right or down
        40 { if ($selection -lt ($menu.length - 1)) { $selection++ }; break }

        # letter, number, or enter
        default {
            # if alpha key, align with VirtualKeyCodes of number keys
            if ($key -gt 64) { $key -= 7 }
            if ($key -gt 13) {$selection = $key - 48}

            # restore the original console buffer contents
            destroy
            
            # Add your code here
            if ($selection -eq 0) {
                # Code for "Switch to 1440p" option
                # ...
                python ./res.py 1440
            }
            elseif ($selection -eq 1) {
                # Code for "Switch to 1920p" option
                # ...
                python ./res.py 1920
            }
            
            exit($selection)
        }
    }
}