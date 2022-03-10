# =================================================================================================
# Update These:
$NSXUser = "admin"                               ## NSX-T Admin Username 
$NSXPW = "Password123!Password123!"              ## NSX-T Admin Password
$baseuri = "https://nsxt-site-b.lab"             ## NSX-T Manager URL
$NSXTSite = "Site-B"                             ## NSX-T Site Name
# vCenter Connection # ============================
$vc = "vc-site-b.lab"                            ## vCenter Hostname
$VCSSOUser = "administrator@vsphere.local"       ## vCenter SSO Admin Username 
$VCSSOPass = "Password123!"                      ## vCenter SSO Admin Password
$VCCluster = "SITE-B-CLUSTER"                    ## Cluster Name
$DVSwitch = "SITE-B-DSWITCH"                     ## Distributed Switch Name
$Datastore = "ESXi7-SITE-B-LOCAL"                ## Datastore to deploy edge to
$MgmtDVPrtGrp = "Site-B-Management"              ## Distributed Switch Port group for MGMT traffic
# Transport Zones # ===============================
$TZOvLySuffix = "Overlay-Transport-Zone"         ## Overlay Transport Zone Name Suffix
$TZVlanSuffix = "VLAN-Transport-Zone"            ## VLAN Transport Zone Name Suffix
# Host Uplink Profile # ===========================
$HUPSuffix = "Host-Uplink-Profile"               ## Host Uplink Profile Name Suffix
$HUP1Name = "Uplink-1"                           ## Host Uplink 1 Name
$HUP2Name = "Uplink-2"                           ## Host Uplink 2 Name
$HUPTeaming = "FAILOVER_ORDER"                   ## Host Uplink Teaming Policy
$HTransVLAN = "21"                               ## Host Transport VLAN ID
# Edge Uplink Profile # ===========================
$EUPSuffix = "Edge-Uplink-Profile"               ## Edge Uplink Profile Name Suffix
$EUP1Name = "Uplink-1"                           ## Edge Uplink 1 Name
$EUP2Name = "Uplink-2"                           ## Edge Uplink 2 Name
$EUPTeaming = "LOADBALANCE_SRCID"                ## Edge Uplink Teaming Policy
$ETransVLAN = "21"                               ## Edge Transport VLAN ID
# TEP Pool # ======================================
$IPPSuffix = "TEP-Pool"                          ## TEP Pool Name Suffix
$IPPDescription = "Site-B TEP Pool"              ## TEP Pool Description
$IPPStart = "192.168.21.2"                       ## TEP Pool Start IP
$IPPEnd = "192.168.21.254"                       ## TEP Pool End IP
$IPPCIDR = "192.168.21.0/24"                     ## TEP Pool CIDR
$IPPGW = "192.168.21.1"                          ## TEP Pool Gateway
# Transport Node Profile # ========================
$TNPSuffix = "Transport-Node-Profile"            ## Transport Node Profile Name Suffix
# Edge VMs # ======================================
$EdgeNodes = @"
Edge,IP
esg-site-b,192.168.20.22
"@ | ConvertFrom-Csv                             ## List of Edge Nodes "Name","IP"
$EdgeCIDR = "24"                                 ## Edge Management IP CIDR
$EdgeGWIP = "192.168.20.1"                       ## Edge Management IP Gateway
$EdgeDNSIP = "192.168.20.1"                      ## Edge DNS Server IP
$EdgeDNSSearch = "lab"                           ## Edge DNS Search List
$EdgeNTPIP = "192.168.20.1"                      ## Edge NTP Server List
$EdgeUplinks = "Site-B-Trunk"                    ## Distributed Switch Port group for Edge Uplinks
$EdgerootPW = $NSXPW                             ## Edge root User Password
$EdgeCLIPW = $NSXPW                              ## Edge CLI User Password
$EdgeCluSuffix = "Edge-Cluster"                  ## Edge Cluster Name Suffix
# ==== HANDLE API RESPONSE EXCEPTIONS ========================================================================================================================
Function ResponseException {
#Get response from the exception
    $response = $_.exception.response
    if ($response) {
      Write-Host ""
      Write-Host "Oops something went wrong, please check your API call" -ForegroundColor Red -BackgroundColor Black
      Write-Host ""
      $responseStream = $_.exception.response.GetResponseStream()
      $reader = New-Object system.io.streamreader($responseStream)
      $responseBody = $reader.readtoend()
      $ErrorString = "Exception occured calling invoke-restmethod. $($response.StatusCode.value__) : $($response.StatusDescription) : Response Body: $($responseBody)"
      Throw $ErrorString
      Write-Host ""
    }
    else {
      Throw $_
    }
} 
# ==== ACCEPT CERTS + CREDENTIAL HANDLING ====================================================================================================================
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
$pair = "$($NSXUser):$($NSXPW)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$headers = @{
"Authorization"="basic $base64"
"Content-Type"="application/json"
"Accept"="application/json"
}
# ==== CREATE TRANSPORT ZONES ================================================================================================================================
$tzuri = "$baseuri/policy/api/v1/transport-zones/"
$body = @"
{
    "display_name": "$($NSXTSite)-$($TZOvLySuffix)",
    "transport_type": "OVERLAY"
}
"@
Try {
$response = invoke-restmethod -uri $tzuri -headers $headers -method POST -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
$body = @"
{
    "display_name": "$($NSXTSite)-$($TZVlanSuffix)",
    "transport_type": "VLAN"
}
"@
Try {
$response = invoke-restmethod -uri $tzuri -headers $headers -method POST -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== CREATE HOST UPLINK PROFILE ============================================================================================================================
$hupuri = "$baseuri/policy/api/v1/infra/host-switch-profiles/$NSXTSite-$HUPSuffix"
$body = @"
{
"display_name": "$($NSXTSite)-$($HUPSuffix)",
"resource_type": "PolicyUplinkHostSwitchProfile",
"transport_vlan": $($HTransVLAN),
"teaming": {
    "policy": "$($HUPTeaming)",
    "active_list": [
                    {
                    "uplink_name": "Uplink-1",
                    "uplink_type": "PNIC"
                },
                {
                    "uplink_name": "Uplink-2",
                    "uplink_type": "PNIC"
                }
            ]
    }
}
"@
Try {
$response = invoke-restmethod -uri $hupuri -headers $headers -method PATCH -body $body
$response
Write-Host ""}
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== CREATE EDGE UPLINK PROFILE ============================================================================================================================
$eupuri = "$baseuri/policy/api/v1/infra/host-switch-profiles/$NSXTSite-$EUPSuffix"
$body = @"
{
"display_name": "$($NSXTSite)-$($EUPSuffix)",
"resource_type": "PolicyUplinkHostSwitchProfile",
"transport_vlan": $($ETransVLAN),
"teaming": {
    "policy": "$($EUPTeaming)",
    "active_list": [
                    {
                    "uplink_name": "Uplink-1",
                    "uplink_type": "PNIC"
                },
                {
                    "uplink_name": "Uplink-2",
                    "uplink_type": "PNIC"
                }
            ]
    }
}
"@
Try {
$response = invoke-restmethod -uri $eupuri -headers $headers -method PATCH -body $body
$response
Write-Host ""}
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== CREATE TEP POOL =======================================================================================================================================
$ippooluri = "$baseuri/policy/api/v1/infra/ip-pools/$NSXTSite-$IPPSuffix"
$body = @"
{
    "display_name": "$($NSXTSite)-$($IPPSuffix)"
}
"@
Try {
$response = invoke-restmethod -uri $ippooluri -headers $headers -method PATCH -body $body
$response
Write-Host ""}
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== CREATE TEP POOL SUBNET ================================================================================================================================
$ippoolsubneturi = "$baseuri/policy/api/v1/infra/ip-pools/$NSXTSite-$IPPSuffix/ip-subnets/Subnet-1"
$body = @"
{
  "resource_type": "IpAddressPoolStaticSubnet",
  "allocation_ranges": [
    {
        "start": "$IPPStart",
        "end": "$IPPEnd"
       }
    ],
  "cidr": "$IPPCIDR",
  "gateway_ip": "$IPPGW"
}
"@
Try {
$response = invoke-restmethod -uri $ippoolsubneturi -headers $headers -method PATCH -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== ADD vCENTER ===========================================================================================================================================
Try {
$response = invoke-restmethod -uri "https://$vc" -Method Get | Out-Null
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
$EndPoint = [System.Net.Webrequest]::Create("https://$vc")
$cert = $EndPoint.ServicePoint.Certificate
$BYTES = $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
Set-content -value $BYTES -encoding byte -path $ENV:TMP\cert-temp
$VCThumbprint = ((Get-FileHash -Path $ENV:TMP\cert-temp -Algorithm SHA256).Hash) -replace '(..(?!$))','$1:'
$VCHost = "$($EndPoint.Host)"
$addcompmgruri = "$baseuri/api/v1/fabric/compute-managers"
$body = @"
{
  "server": "$($VCHost)",
  "origin_type": "vCenter",
  "display_name": "$($VCHost.ToUpper())",
  "credential" : {
    "credential_type" : "UsernamePasswordLoginCredential",
    "username": "$($VCSSOUser)",
    "password": "$($VCSSOPass)",
    "thumbprint": "$($VCThumbprint)"
  }
}
"@
Try {
$response = invoke-restmethod -uri $addcompmgruri -headers $headers -method POST -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== CREATE TRANSPORT NODE PROFILE =========================================================================================================================
# Get DVS ID
$vctr = Connect-VIServer $vc -User "$VCSSOUser" -Password $VCSSOPass #-WarningAction SilentlyContinue
$vds = (Get-VDSwitch -Name "$DVSwitch" -Server "$vc").ExtensionData
$vdsuuid = $vds.Uuid
Disconnect-VIServer $vc -Confirm:$false
# Get transport zone IDs
$uri = "$baseuri/policy/api/v1/transport-zones"
Try {
$response = invoke-restmethod -uri $uri -headers $headers -method GET
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
foreach ($zone in $($response.results)) {
    if ($zone.display_name -eq "$($NSXTSite)-$($TZOvLySuffix)") { $ovlytzid = $zone.id }
    if ($zone.display_name -eq "$($NSXTSite)-$($TZVlanSuffix)") { $vlantzid = $zone.id }
}
# Create Profile
$tnpuri = "$baseuri/policy/api/v1/infra/host-transport-node-profiles/$NSXTSite-$TNPSuffix"
$body = @"
{
    "host_switch_spec": {
        "host_switches": [
            {
                "host_switch_name": "nsxDefaultHostSwitch",
                "host_switch_id": "$($vdsuuid)",
                "host_switch_type": "VDS",
                "host_switch_mode": "STANDARD",
                "host_switch_profile_ids": [
                    {
                        "key": "UplinkHostSwitchProfile",
                        "value": "/infra/host-switch-profiles/$($NSXTSite)-$($HUPSuffix)"
                    }
                ],
                "uplinks": [
                    {
                        "vds_uplink_name": "Uplink 1",
                        "uplink_name": "Uplink-1"
                    },
                    {
                        "vds_uplink_name": "Uplink 2",
                        "uplink_name": "Uplink-2"
                    }
                ],
                "is_migrate_pnics": false,
                "ip_assignment_spec": {
                    "ip_pool_id": "/infra/ip-pools/$($NSXTSite)-$($IPPSuffix)",
                    "resource_type": "StaticIpPoolSpec"
                },
                "cpu_config": [],
                "transport_zone_endpoints": [
                    {
                        "transport_zone_id": "/infra/sites/default/enforcement-points/default/transport-zones/$ovlytzid"
                    },
                    {
                        "transport_zone_id": "/infra/sites/default/enforcement-points/default/transport-zones/$vlantzid"
                    }
                ],
                "not_ready": false
            }
        ],
        "resource_type": "StandardHostSwitchSpec"
    },
    "ignore_overridden_hosts": false,
    "resource_type": "PolicyHostTransportNodeProfile",
    "display_name": "$($NSXTSite)-$($TNPSuffix)"
}
"@
Try {
$response = invoke-restmethod -uri $tnpuri -headers $headers -method PUT -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== PREPARE CLUSTER =======================================================================================================================================
# Get Compute Cluster ID
$uri = "$baseuri/api/v1/fabric/compute-collections"
Try {
$response = invoke-restmethod -uri $uri -headers $headers -method GET
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
foreach ($collection in $($response.results)) {
    if ($collection.display_name -eq "$VCCluster") {$collectid = $collection.external_id}
}
# Prepare Cluster
$prepuri = "$baseuri/policy/api/v1/infra/sites/default/enforcement-points/default/transport-node-collections/TNC"
$body = @"
{
"resource_type": "HostTransportNodeCollection",
"compute_collection_id": "$collectid",
"transport_node_profile_id": "/infra/host-transport-node-profiles/$($NSXTSite)-$($TNPSuffix)"
}
"@
Try {
$response = invoke-restmethod -uri $prepuri -headers $headers -method PUT -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
Sleep 300 # Wait 5 mins for Cluster Preparation
# ==== CREATE TRUNK VLAN SEGMENT =============================================================================================================================
$seguri = "$baseuri/policy/api/v1/infra/segments/$NSXTSite-Trunk"
$body = @"
{
"display_name": "$NSXTSite-Trunk",
"vlan_ids": [
    "0-4094"
  ],
"transport_zone_path": "/infra/sites/default/enforcement-points/default/transport-zones/$vlantzid"
}
"@
Try {
$response = invoke-restmethod -uri $seguri -headers $headers -method PUT -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
# ==== CREATE EDGE NODES =====================================================================================================================================
# Get Edge Uplink Profile ID
$eupuri = "$baseuri/policy/api/v1/infra/host-switch-profiles/$NSXTSite-$EUPSuffix"
Try {
$response = invoke-restmethod -uri $eupuri -headers $headers -method GET
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
$eupid = $response.unique_id
# Get IP Pool ID
$ippooluri = "$baseuri/policy/api/v1/infra/ip-pools/$NSXTSite-$IPPSuffix"
Try {
$response = invoke-restmethod -uri $ippooluri -headers $headers -method GET
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
$ippid = $response.unique_id
# Get Overlay Transport Zone IDs
$tzuri = "$baseuri/policy/api/v1/transport-zones/"
Try {
$response = invoke-restmethod -uri $tzuri -headers $headers -method GET
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
foreach ($zone in $($response.results)) {
    if ($zone.display_name -eq "$($NSXTSite)-$($TZOvLySuffix)") { $ovlytzid = $zone.id }
    if ($zone.display_name -eq "$($NSXTSite)-$($TZVlanSuffix)") { $vlantzid = $zone.id }
}
# Get IDs from vCenter 
$vctr = Connect-VIServer $vc -User "$VCSSOUser" -Password $VCSSOPass #-WarningAction SilentlyContinue
$vds = (Get-VDSwitch -Name "$DVSwitch" -Server "$vc").ExtensionData
$vdsuuid = $vds.Uuid
$storid = (Get-Datastore -Name "$Datastore" -Server "$vc").ExtensionData.MoRef.Value
$mgtprtgrp = (Get-VirtualPortgroup -Name "$MgmtDVPrtGrp").key
$computeid = (Get-Cluster -Name $VCCluster).ExtensionData.moref.value
Disconnect-VIServer $vc -Confirm:$false
# Create Edges
$edgeuri = "$baseuri/api/v1/transport-nodes"
ForEach ($Node in $EdgeNodes){
$body = @"
{
    "display_name": "$(($Node.Edge).ToUpper())",
    "host_switch_spec": {
        "host_switches": [
            {
                "host_switch_name": "N-DVS-01",
                "host_switch_type": "NVDS",
                "host_switch_mode": "STANDARD",
                "host_switch_profile_ids": [
                    {
                        "key": "UplinkHostSwitchProfile",
                        "value": "$eupid"
                    }
                ],
                "pnics": [
                    {
                        "device_name": "fp-eth0",
                        "uplink_name": "Uplink-1"
                    },
                    {
                        "device_name": "fp-eth1",
                        "uplink_name": "Uplink-2"
                    }
                ],
                "is_migrate_pnics": false,
                "ip_assignment_spec": {
                    "ip_pool_id": "$ippid",
                    "resource_type": "StaticIpPoolSpec"
                },
                "cpu_config": [],
                "transport_zone_endpoints": [
                    {
                        "transport_zone_id": "$ovlytzid",
                        "transport_zone_profile_ids": [
                            {
                                "resource_type": "BfdHealthMonitoringProfile",
                                "profile_id": "52035bb3-ab02-4a08-9884-18631312e50a"
                            }
                        ]
                    },
                    {
                        "transport_zone_id": "$vlantzid",
                        "transport_zone_profile_ids": [
                            {
                                "resource_type": "BfdHealthMonitoringProfile",
                                "profile_id": "52035bb3-ab02-4a08-9884-18631312e50a"
                            }
                        ]
                    }
                ],
                "not_ready": false
            }
        ],
        "resource_type": "StandardHostSwitchSpec"
    },
    "maintenance_mode": "DISABLED",
    "node_deployment_info": {
        "deployment_type": "VIRTUAL_MACHINE",
        "deployment_config": {
            "vm_deployment_config": {
                "vc_id": "$vcid",
                "compute_id": "$computeid",
                "storage_id": "$storid",
                "management_network_id": "$mgtprtgrp",
                "management_port_subnets": [
                    {
                        "ip_addresses": [
                            "$($Node.IP)"
                        ],
                        "prefix_length": "$EdgeCIDR"
                    }
                ],
                "default_gateway_addresses": [
                    "$EdgeGWIP"
                ],
                "data_network_ids": [
                    "/infra/segments/$EdgeUplinks",
                    "/infra/segments/$EdgeUplinks"
                ],
                "reservation_info": {
                    "memory_reservation": {
                        "reservation_percentage": 0
                    },
                    "cpu_reservation": {
                        "reservation_in_shares": "NORMAL_PRIORITY",
                        "reservation_in_mhz": 0
                    }
                },
                "placement_type": "VsphereDeploymentConfig"
            },
            "form_factor": "SMALL",
            "node_user_settings": {
                "cli_username": "admin",
				"root_password":"$EdgerootPW",
				"cli_password":"$EdgeCLIPW"
            }
        },
        "node_settings": {
            "hostname": "esg-site-b.lab",
            "search_domains": [
                "$EdgeDNSSearch"
            ],
            "ntp_servers": [
                "$EdgeNTPIP"
            ],
            "dns_servers": [
                "$EdgeDNSIP"
            ],
            "enable_ssh": true,
            "allow_ssh_root_login": true
        },
        "resource_type": "EdgeNode",
        "ip_addresses": [
            "$($Node.IP)"
        ]
    }
}
"@
Try {
$response = invoke-restmethod -uri $edgeuri -headers $headers -method POST -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
Sleep 300 # Wait 5 mins for Edge Deployment(s)
}
# ==== CREATE EDGE CLUSTER ===================================================================================================================================
# Get Edge Nodes
$edgeuri = "$baseuri/api/v1/transport-nodes"
Try {
$response = invoke-restmethod -uri $edgeuri -headers $headers -method GET
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
$Edgenodes = $response.results.Where{$_.node_deployment_info.deployment_type -eq "VIRTUAL_MACHINE"}
$memberlist = @()
ForEach ($Edgenode in $Edgenodes){
    $out = new-object psobject
    $out | Add-Member noteproperty "transport_node_id" "$($edgenode.id)"
    $out | Add-Member noteproperty "display_name" "$($edgenode.display_name)"
    $memberlist += $out
}
$memberlistjson = $memberlist | ConvertTo-Json
# Create Edge Cluster
$edcluuri = "$baseuri/api/v1/edge-clusters"
$body = @"
{
    "member_node_type": "EDGE_NODE",
    "resource_type": "EdgeCluster",
    "display_name": "$($NSXTSite)-$($EdgeCluSuffix)",
    "deployment_type": "VIRTUAL_MACHINE",
    "members": $($memberlistjson),
    "cluster_profile_bindings": [
        {
            "resource_type": "EdgeHighAvailabilityProfile",
            "profile_id": "91bcaa06-47a1-11e4-8316-17ffc770799b"
        }
    ]
}
"@
Try {
$response = invoke-restmethod -uri $edcluuri -headers $headers -method POST -body $body
$response
Write-Host ""} 
Catch {ResponseException # Call Function ResponseException to get error response from the exception
}
