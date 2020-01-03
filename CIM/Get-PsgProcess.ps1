function Get-PsgProcess {
    <#
    .SYNOPSIS
        Query the CIM Object database for a list of processes on a target host.
    .DESCRIPTION
        Query the CIM Object database for a list of processes on a target host. The function allows for
        filtering so as to better target the desired processes.
    .EXAMPLE
        PS C:\> Get-PsgProcess -CimSession (Get-CimSession -Id 2) -ExecutablePath "C:\\User" 


        ProcessId       : 4560
        ParentProcessId : 4556
        Name            : mimikatz.exe
        ExecutablePath  : C:\Users\Administrator\Desktop\mimikatz_trunk-2\x64\mimikatz.exe
        CommandLine     : "C:\Users\Administrator\Desktop\mimikatz_trunk-2\x64\mimikatz.exe" 
        CreationDate    : 8/21/2019 4:56:05 PM
        SessionId       : 1
        ComputerName    : dc1

        ProcessId       : 2284
        ParentProcessId : 796
        Name            : mimikatz.exe
        ExecutablePath  : C:\Users\Administrator\Desktop\mimikatz_trunk-2\x64\mimikatz.exe
        CommandLine     : "C:\Users\Administrator\Desktop\mimikatz_trunk-2\x64\mimikatz.exe" rpc::server service::me exit
        CreationDate    : 8/21/2019 4:56:14 PM
        SessionId       : 0
        ComputerName    : dc1

        Enumerate processes running under C:\Users folder.
    .EXAMPLE
        PS C:\> Get-PsgProcess -CimSession (Get-CimSession -Id 2) -CreatedBefore "9/1/2019" -CreatedAfter "8/20/2019"

        Find processes that where created inside a given time window.

    .EXAMPLE
        PS C:\>  Get-PsgProcess -CimSession (Get-CimSession -Id 2) -SessionId 0 -name pse   


        ProcessId       : 4800
        ParentProcessId : 796
        Name            : PSEXESVC.exe
        ExecutablePath  : C:\Windows\PSEXESVC.exe
        CommandLine     : C:\Windows\PSEXESVC.exe
        CreationDate    : 8/17/2019 12:00:42 AM
        SessionId       : 0
        ComputerName    : dc1

        Find processes started by SYSTEM (Always session ID 0) whose name contains *pse*
    .EXAMPLE
        PS C:\> Get-PsgProcess -CimSession (Get-CimSession -Id 2) -name conhost,powershell,cmd  

        Query for all terminal processes on a system. 

    .INPUTS
        Microsoft.Management.Infrastructure.CimSession
    .OUTPUTS
        PSGumshoe.Process
    .NOTES
        Pulling the process owner will have an impact on the speed of execution on large numbers of targets.
    #>
    [CmdletBinding(DefaultParameterSetName = "Local")]
    param (
        # Name or part of the process name to  query for.
        [Parameter(Mandatory=$false,
            ValueFromPipelineByPropertyName = $true)]
        [string[]]
        $Name,

        # Commandline or part of a commandline to query for.
        [Parameter(mandatory=$false)]
        [string[]]
        $commandline,

        # Path or part of the path of the executable to query for.
        [Parameter(mandatory=$false)]
        [string[]]
        $ExecutablePath,

        # ProcessId to query for.
        [Parameter(Mandatory=$false)]
        [int[]]
        $ProcessId,

        # Created before the specified time.
        [Parameter(Mandatory=$false)]
        [datetime]
        $CreatedBefore,

        # Created after the specified time.
        [Parameter(mandatory=$false)]
        [datetime]
        $CreatedAfter,

        # Session Id
        [Parameter(mandatory=$false)]
        [int[]]
        $SessionId,

        # Parent Process Id
        [Parameter(mandatory=$false)]
        [int[]]
        $ParentProcessId,

        # CIMSession to perform query against
        [Parameter(ValueFromPipelineByPropertyName = $True,
            ValueFromPipeline = $true)]
        [Alias('Session')]
        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession,

        # Process properties to get.
        [Parameter(Mandatory = $false)]
        [String[]]
        [ValidateSet(
            'Caption',
            'CommandLine',
            'CreationClassName',
            'CreationDate',
            'CSCreationClassName',
            'CSName',
            'Description',
            'ExecutablePath',
            'ExecutionState',
            'Handle',
            'HandleCount',
            'InstallDate',
            'KernelModeTime',
            'MaximumWorkingSetSize',
            'MinimumWorkingSetSize',
            'Name',
            'OSCreationClassName',
            'OSName',
            'OtherOperationCount',
            'OtherTransferCount',
            'PageFaults',
            'PageFileUsage',
            'ParentProcessId',
            'PeakPageFileUsage',
            'PeakVirtualSize',
            'PeakWorkingSetSize',
            'Priority',
            'PrivatePageCount',
            'ProcessId',
            'QuotaNonPagedPoolUsage',
            'QuotaPagedPoolUsage',
            'QuotaPeakNonPagedPoolUsage',
            'QuotaPeakPagedPoolUsage',
            'ReadOperationCount',
            'ReadTransferCount',
            'SessionId',
            'Status',
            'TerminationDate',
            'ThreadCount',
            'UserModeTime',
            'VirtualSize',
            'WindowsVersion',
            'WorkingSetSize',
            'WriteOperationCount',
            'WriteTransferCount')]
        $Property = @('ProcessId', 'ParentProcessId', 'Name', 'ExecutablePath', 'CommandLine', 'CreationDate', 'SessionId'),

        # Get the owner for each process. This will require an addional query per process.
        [Parameter(mandatory=$false)]
        [switch]
        $GetOwner,

        # Invert the logic of the filtering showing only processes that do not match
        [Parameter(Mandatory=$false)]
        [switch]
        $InvertLogic
    )
    
    begin {
       
        # Build WQL Query
        $PassedParams = $PSBoundParameters.Keys
        $filter = @()
        switch ($PassedParams) {
            "Name" {
                $nFilter = @()
                foreach($n in $name){
                    $nfilter += "Name LIKE '%$($n)%'"  
                }
                $filter += "($($nfilter -join " OR "))"
            }

            "Commandline" { 
                $cFilter = @()
                foreach($c in $Commandline){
                    $cfilter += "Commandline LIKE '%$($c)%'"  
                }
                $filter += "($($cfilter -join " OR "))"
            }

            "ExecutablePath"  { 
                $eFilter = @()
                foreach($e in $ExecutablePath){
                    $efilter += "ExecutablePath LIKE '%$($e)%'"  
                }
                $filter += "($($efilter -join " OR "))"
            }
            "ProcessId" { 
                $pidFilter = @()
                foreach($pid in $ProcessId){
                    $pidFilter += "ProcessId = $($pid)"  
                }
                $filter += "($($pidFilter -join " OR "))"
            }

             "ParentProcessId" { 
                $pidFilter = @()
                foreach($pid in $ParentProcessId){
                    $ppidFilter += "ParentProcessID = $($pid)"  
                }
                $filter += "($($ppidFilter -join " OR "))"
            }
            
             "SessionId" { 
                $sidFilter = @()
                foreach($sid in $SessionId){
                    $sidFilter += "SessionId = $($sid)"  
                }
                $filter += "($($sidFilter -join " OR "))"
            }

            "CreatedBefore" {
                $before = [system.management.ManagementDateTimeConverter]::ToDmtfDateTime(($CreatedBefore))
                $filter += "CreationDate <= '$($before)'"
            }

            "CreatedAfter" {
                $after = [system.management.ManagementDateTimeConverter]::ToDmtfDateTime(($CreatedAfter))
                $filter += "CreationDate >= '$($after)'"
            }
            Default {}
        }
        
        $filterLogic =  ''
        if ($InvertLogic) {
            $filterLogic = "NOT"
        }
        if ($filter.Length -eq 0) {
            $Wql = "SELECT $( $Property -join ',' ) FROM Win32_Process"
        } else {
            $Wql = "SELECT $( $Property -join ',' ) FROM Win32_Process WHERE $($filterLogic) $($filter -join " AND " )"
        }
        Write-Verbose -Message "Using WQL query - $($Wql)"
    }
    
    process {

        if ($CimSession.Count -gt 0 ) {
            foreach ($Session in $CimSession) {
                Get-CimInstance -Query $Wql -CimSession $Session | ForEach-Object {
                    $objectProps = [ordered]@{}
                    foreach($p in $Property) {
                        $objectProps.Add($p, $_."$($p)")
                    }
                    $objectProps.Add('ComputerName', $Session.ComputerName)
                    
                    if($GetOwner) {
                        $ownerInfo = Invoke-CimMethod -InputObject $_ -MethodName GetOwner
                        if ($ownerInfo.ReturnValue -eq 0) {
                            $objectProps.Add('Owner', "$($ownerInfo.Domain)\$($ownerInfo.User)")
                        } else {
                            $objectProps.Add('Owner', "")
                        }
                    }

                    
                    $obj = [PSCustomObject]$objectProps
                    $obj.pstypenames.insert(0,'PSGumshoe.Process')
                    $obj
                }
            }
        } else {
            Get-CimInstance -Query $Wql | ForEach-Object {
                $objectProps = [ordered]@{}
                foreach($p in $Property) {
                    $objectProps.Add($p, $_."$($p)")
                    if ($p -eq 'ProcessID') {
                        $objectProps.Add('ProcessIdHex', "0x$("{0:x}" -f $_.ProcessId)")
                    }
                }
                $objectProps.Add('ComputerName', $_.CSName)
                $obj = [PSCustomObject]$objectProps
                $obj.pstypenames.insert(0,'PSGumshoe.Process')
                $obj
            }
        }
    }
    
    end {
        
    }
}
