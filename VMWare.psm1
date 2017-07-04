Function Connect-VmWareBD_NonProd_1 {
[Cmdletbinding()]       
    param(
        [bool]$promptForCEIP = $false,
        [Parameter(Mandatory=$false)]
        [string]$User,
        [Parameter(Mandatory=$false)]
        [string]$Domain,
        [Parameter(Mandatory=$false)]
        [string]$VIServer
    )
    BEGIN{}
    PROCESS{
        # List of modules to be loaded
        $moduleList = @(
            "VMware.VimAutomation.Core",
            "VMware.VimAutomation.Vds",
            "VMware.VimAutomation.Cloud",
            "VMware.VimAutomation.PCloud",
            "VMware.VimAutomation.Cis.Core",
            "VMware.VimAutomation.Storage",
            "VMware.VimAutomation.HorizonView",
            "VMware.VimAutomation.HA",
            "VMware.VimAutomation.vROps",
            "VMware.VumAutomation",
            "VMware.DeployAutomation",
            "VMware.ImageBuilder",
            "VMware.VimAutomation.License"
            )
        
        $productName = "PowerCLI"
        $productShortName = "PowerCLI"
        
        $loadingActivity = "Loading $productName"
        $script:completedActivities = 0
        $script:percentComplete = 0
        $script:currentActivity = ""
        $script:totalActivities = `
           $moduleList.Count + 1
        
        function ReportStartOfActivity($activity) {
           $script:currentActivity = $activity
           Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
        }
        function ReportFinishedActivity() {
           $script:completedActivities++
           $script:percentComplete = (100.0 / $totalActivities) * $script:completedActivities
           $script:percentComplete = [Math]::Min(99, $percentComplete)
           
           Write-Progress -Activity $loadingActivity -CurrentOperation $script:currentActivity -PercentComplete $script:percentComplete
        }
        
        # Load modules
        function LoadModules(){
         ReportStartOfActivity "Searching for $productShortName module components..."
         
         $loaded = Get-Module -Name $moduleList -ErrorAction Ignore | % {$_.Name}
         $registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction Ignore | % {$_.Name}
         $notLoaded = $registered | ? {$loaded -notcontains $_}
         
         ReportFinishedActivity
         
            foreach ($module in $registered) {
               if ($loaded -notcontains $module) {
            	 ReportStartOfActivity "Loading module $module"
                  
            	 Import-Module $module -Global
            	 
            	 ReportFinishedActivity
               }
            }
        }

        function Connect-VmwareInstance {
        [Cmdletbinding()]       
            param(
                [string]$UserName,
                [string]$Domain,
                [string]$VIServer     
            )
            BEGIN{}
            PROCESS{
                if($global:DefaultVIServers){
                  throw "Alredy connected to VmWare"
                }else {
                    $cred = Get-Credential "$domain\$UserName"
                    Connect-VIServer $VIServer -Credential $cred -Verbose -WarningAction SilentlyContinue | Out-Null
                }
            }
            END{}        
        }
        
        LoadModules
        
        # Update PowerCLI version after snap-in load
        $powerCliFriendlyVersion = [VMware.VimAutomation.Sdk.Util10.ProductInfo]::PowerCLIFriendlyVersion
        $host.ui.RawUI.WindowTitle = $powerCliFriendlyVersion   
        
        # CEIP
        Try	{
        	$configuration = Get-PowerCLIConfiguration -Scope Session
        
        	if ($promptForCEIP -and
        		$configuration.ParticipateInCEIP -eq $null -and `
        		[VMware.VimAutomation.Sdk.Util10Ps.CommonUtil]::InInteractiveMode($Host.UI)) {
        
        		# Prompt
        		$caption = "Participate in VMware Customer Experience Improvement Program (CEIP)"
        		$message = `
        			"VMware's Customer Experience Improvement Program (`"CEIP`") provides VMware with information " +
        			"that enables VMware to improve its products and services, to fix problems, and to advise you " +
        			"on how best to deploy and use our products.  As part of the CEIP, VMware collects technical information " +
        			"about your organization’s use of VMware products and services on a regular basis in association " +
        			"with your organization’s VMware license key(s).  This information does not personally identify " +
        			"any individual." +
        			"`n`nFor more details: press Ctrl+C to exit this prompt and type `"help about_ceip`" to see the related help article." +
        			"`n`nYou can join or leave the program at any time by executing: Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP `$true or `$false. "
        
        		$acceptLabel = "&Join"
        		$choices = (
        			(New-Object -TypeName "System.Management.Automation.Host.ChoiceDescription" -ArgumentList $acceptLabel,"Participate in the CEIP"),
        			(New-Object -TypeName "System.Management.Automation.Host.ChoiceDescription" -ArgumentList "&Leave","Don't participate")
        		)
        		$userChoiceIndex = $Host.UI.PromptForChoice($caption, $message, $choices, 0)
        		
        		$participate = $choices[$userChoiceIndex].Label -eq $acceptLabel
        
        		if ($participate) {
                 [VMware.VimAutomation.Sdk.Interop.V1.CoreServiceFactory]::CoreService.CeipService.JoinCeipProgram();
              } else {
                 Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
              }
        	}
        } Catch {
        	# Fail silently
        }
        # end CEIP
        
        Write-Progress -Activity $loadingActivity -Completed
        
        Set-Location -Path \

        #Connecting to VIServer
        Connect-VmwareInstance -UserName $User -Domain $Domain -VIServer $VIServer
    }
    END{}
}