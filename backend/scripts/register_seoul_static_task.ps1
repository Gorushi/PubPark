param([string]$TaskName = 'PubPark-SeoulStaticMonthly')
$ErrorActionPreference = 'Stop'
$backend = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path -LiteralPath (Join-Path $backend '.venv/Scripts/python.exe'))) {
    throw 'Install backend/.venv before registering the task.'
}
if ((Get-TimeZone).Id -ne 'Korea Standard Time') {
    throw 'This task uses local time. Configure Korea Standard Time first.'
}
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) { throw "Task already exists: $TaskName. Inspect it before replacing it." }
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$escape = { param($text) [System.Security.SecurityElement]::Escape($text) }
$script = Join-Path $PSScriptRoot 'run_seoul_static.ps1'
$arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $script + '"'
$xml = @"
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>Refresh Seoul parking static inventory and Naver coordinates monthly.</Description></RegistrationInfo>
  <Triggers><CalendarTrigger><StartBoundary>2026-01-01T03:00:00</StartBoundary><Enabled>true</Enabled>
    <ScheduleByMonth><DaysOfMonth><Day>1</Day></DaysOfMonth><Months>
      <January/><February/><March/><April/><May/><June/><July/><August/><September/><October/><November/><December/>
    </Months></ScheduleByMonth>
  </CalendarTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>$(& $escape $user)</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><StartWhenAvailable>true</StartWhenAvailable><ExecutionTimeLimit>PT2H</ExecutionTimeLimit><RestartOnFailure><Interval>PT1H</Interval><Count>3</Count></RestartOnFailure></Settings>
  <Actions Context="Author"><Exec><Command>powershell.exe</Command><Arguments>$(& $escape $arguments)</Arguments><WorkingDirectory>$(& $escape $backend)</WorkingDirectory></Exec></Actions>
</Task>
"@
Register-ScheduledTask -TaskName $TaskName -Xml $xml | Select-Object TaskName, State
Get-ScheduledTaskInfo -TaskName $TaskName | Select-Object NextRunTime, LastTaskResult
