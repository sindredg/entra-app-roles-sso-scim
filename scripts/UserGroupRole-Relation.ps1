$sp    = Get-MgServicePrincipal -Filter "displayName eq 'app-grafana-lab'"
$app   = Get-MgApplication      -Filter "displayName eq 'app-grafana-lab'"
$roles = @{}; $app.AppRoles | ForEach-Object { $roles[$_.Id.ToString()] = $_.Value }

# 1. group -> role assignments
$assignments = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id
$assignments | Select-Object PrincipalDisplayName, PrincipalType,
  @{n='Role';e={$roles[$_.AppRoleId.ToString()]}} | Format-Table

# 2. effective user -> role (expands group members)
foreach ($a in $assignments | Where-Object PrincipalType -eq 'Group') {
  Get-MgGroupMember -GroupId $a.PrincipalId | ForEach-Object {
    [pscustomobject]@{ User = $_.AdditionalProperties.displayName
                       Via  = $a.PrincipalDisplayName
                       Role = $roles[$a.AppRoleId.ToString()] }
  }
}