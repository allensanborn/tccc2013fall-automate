#This file builds VMs based on differencing disks

#initialize defaults
$ParentDef = "w2k8r2datacenterbase"
$Namedef = "Scratch"
$Networkdef = "10.0.x.y"
[int64]$Memdef = 1024MB
$Procdef = 2
$ParentDir = "p:\ParentDrives"
$global:VHD="v:\VirtualDisks\"
$procval=1,2,4
[int64]$maxmem=4192MB

#mdghost creates a differencing disk
#with the parameters [parentdrive name] [vhdname] [network] [memory] [processors]
#mdghost is parameter validation and main()

function global:mdghost
{
param(  [string]$parent=$ParentDef,
	[string]$newvhd=$Namedef,
	[string]$net=$Networkdef,
	[int64]$mem=$memdef,
	[int]$cpu=$ProcDef,
	[switch]$help,
	[switch]$go)

if ($help)
	{
		write-host "mdghost [parent] [newvhd] [net] [mem] [cpu] [help] [go]"
		return
	}

write-debug "Parent:$parent`tVHD:$newvhd`tNet:$net`tMemory:$mem`tCPU:$cpu"

#find the parent vhd
$ptemp = Choose-ParentVHD $parent

if ($ptemp) 
    {
	$vParent=$ptemp
	write-debug "Validated Parent $vParent"
    }
	else
	{
		write-error "Parent $parent not Found." -errorid Hyperwrap_NoParent
		return
	}		


#validate the vhd name and/or create a new one
if ($newvhd -like $NameDef)
	{
		#create a randomvhd name
		$testpath=GenRandomVHD
		while (test-path "$vhd\$testpath.vhd")
		{
			$testpath=GenRandomVHD
		}
		$vNewVHD="$testpath.vhd"
		$NewVHD=$TestPath
	}
elseif ((test-path "$vhd$newvhd.vhd"))
	{
		write-error "$newvhd already exists" -errorid HyperWrap_VHDAlreadyExists
		return
	}
else
	{
		$vNewVHD="$NewVHD.vhd"
	}

write-debug "NewVHD is $vNewVHD"

#validate the netname
$vnet=Get-VmSwitch | ? {$_.Name -eq $net}

If ($vnet.count -ne 1)
{
    $vNet = Choose-VMSwitch $net
}

if ($vNet)
	{
		write-debug "Valid NetName $($vnet.name)"
	}
	else
	{
		write-error "Network $net does not exist" -errorid HyperWrap_NoNet
		return
	}
	
if (($mem -gt $maxmem) -or ($mem -lt $minmem))
	{
		write-Error "Memory Out of Bounds: $mem" -errorid HyperWrap_MemoryOut of Bounds
		return
	}

if ($procval -notcontains $cpu)
	{
		write-error "Invalid CPU parameter $cpu" -errorid HyperWrap_InvalidCPuNum
		return
	}

#theoretically, we've validated all the parameters
#time to create the VHD

if (-not $go)
	{
		write-host "`n`nParent:$vparent`tVHD:$newvhd`tNet:$($vnet.name)`tMemory:$($mem/$([MATH]::Pow(1024,2)))MB`tCPU:$cpu"
		$c=read-host "Confirm (y/n)"
		if ($c -ne "y") {return}
	}

write-debug "New-Vhd $vhd$Vnewvhd -parent $ParentDir\$vParent"
write-host "`n`n"

#create the vhd
$myvhd=new-vhd -path "$vhd$Vnewvhd" -parentpath "$ParentDir\$vParent" -differencing


#create the nm
write-debug "New-VM $newvhd"
$MyVm=New-VM -name $newvhd  -MemoryStartupBytes $mem -switchname $vnet.Name -vhdpath $myvhd.Path 

#Set the CPUCount
Set-VMProcessor $myvm.VMName -count $cpu

#Start the VM
start-vm $myvm.vmname



} #end of mdghost
		
function script:GenRandomVHD
{
	#Append a Random Value to the name of the vhd
	$random=new-object random
	$append=$random.next(268435456,536870912)
	$hexval="{0:X}" -f $append
	$append=$hexval.TOString()
	$full="$NameDef-$append"
	return $full
}

	
Function Choose-List
{Param ($InputObject, $Property, [Switch]$multiple)
 $Global:counter=-1
 $Property=@(@{Label="ID"; Expression={ ($global:Counter++) }}) + $Property
 if ($inputObject -is [Array]) {
     $InputObject | format-table -autosize -property $Property | out-host
     if ($multiple) { $InputObject[ [int[]](Read-Host "Which one(s) ?").Split(",")] }
     else           { $InputObject[        (Read-Host "Which one ?")              ] }}
 else {$inputObject}
}

Function Choose-VMSwitch
{Param($net)
 choose-list  (Get-VMSwitch | ? {$_.name -like "*$($net)*"}) @(@{Label="Switch Name"; Expression={$_.Name}} )
}

Function Choose-ParentVHD
{Param ($parent)
 choose-list (get-childitem $parentdir |? {$_.name -like "*$parent*"}) @(@{Label="Parent VHD";Expression={$_}})
 }
