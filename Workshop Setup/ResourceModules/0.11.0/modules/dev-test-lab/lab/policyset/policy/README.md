# DevTest Lab Policy Sets Policies `[Microsoft.DevTestLab/labs/policysets/policies]`

This module deploys a DevTest Lab Policy Sets Policy.

DevTest lab policies are used to modify the lab settings such as only allowing certain VM Size SKUs, marketplace image types, number of VMs allowed per user and other settings.

## Navigation

- [Resource Types](#Resource-Types)
- [Parameters](#Parameters)
- [Outputs](#Outputs)
- [Cross-referenced modules](#Cross-referenced-modules)

## Resource Types

| Resource Type | API Version |
| :-- | :-- |
| `Microsoft.DevTestLab/labs/policysets/policies` | [2018-09-15](https://learn.microsoft.com/en-us/azure/templates/Microsoft.DevTestLab/2018-09-15/labs/policysets/policies) |

## Parameters

**Required parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`evaluatorType`](#parameter-evaluatortype) | string | The evaluator type of the policy (i.e. AllowedValuesPolicy, MaxValuePolicy). |
| [`factName`](#parameter-factname) | string | The fact name of the policy. |
| [`name`](#parameter-name) | string | The name of the policy. |
| [`threshold`](#parameter-threshold) | string | The threshold of the policy (i.e. a number for MaxValuePolicy, and a JSON array of values for AllowedValuesPolicy). |

**Conditional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`labName`](#parameter-labname) | string | The name of the parent lab. Required if the template is used in a standalone deployment. |

**Optional parameters**

| Parameter | Type | Description |
| :-- | :-- | :-- |
| [`description`](#parameter-description) | string | The description of the policy. |
| [`enableDefaultTelemetry`](#parameter-enabledefaulttelemetry) | bool | Enable telemetry via a Globally Unique Identifier (GUID). |
| [`factData`](#parameter-factdata) | string | The fact data of the policy. |
| [`policySetName`](#parameter-policysetname) | string | The name of the parent policy set. |
| [`status`](#parameter-status) | string | The status of the policy. |
| [`tags`](#parameter-tags) | object | Tags of the resource. |

### Parameter: `description`

The description of the policy.
- Required: No
- Type: string
- Default: `''`

### Parameter: `enableDefaultTelemetry`

Enable telemetry via a Globally Unique Identifier (GUID).
- Required: No
- Type: bool
- Default: `True`

### Parameter: `evaluatorType`

The evaluator type of the policy (i.e. AllowedValuesPolicy, MaxValuePolicy).
- Required: Yes
- Type: string
- Allowed: `[AllowedValuesPolicy, MaxValuePolicy]`

### Parameter: `factData`

The fact data of the policy.
- Required: No
- Type: string
- Default: `''`

### Parameter: `factName`

The fact name of the policy.
- Required: Yes
- Type: string
- Allowed: `[EnvironmentTemplate, GalleryImage, LabPremiumVmCount, LabTargetCost, LabVmCount, LabVmSize, ScheduleEditPermission, UserOwnedLabPremiumVmCount, UserOwnedLabVmCount, UserOwnedLabVmCountInSubnet]`

### Parameter: `labName`

The name of the parent lab. Required if the template is used in a standalone deployment.
- Required: Yes
- Type: string

### Parameter: `name`

The name of the policy.
- Required: Yes
- Type: string

### Parameter: `policySetName`

The name of the parent policy set.
- Required: No
- Type: string
- Default: `'default'`

### Parameter: `status`

The status of the policy.
- Required: No
- Type: string
- Default: `'Enabled'`
- Allowed: `[Disabled, Enabled]`

### Parameter: `tags`

Tags of the resource.
- Required: No
- Type: object
- Default: `{object}`

### Parameter: `threshold`

The threshold of the policy (i.e. a number for MaxValuePolicy, and a JSON array of values for AllowedValuesPolicy).
- Required: Yes
- Type: string


## Outputs

| Output | Type | Description |
| :-- | :-- | :-- |
| `name` | string | The name of the policy. |
| `resourceGroupName` | string | The name of the resource group the policy was created in. |
| `resourceId` | string | The resource ID of the policy. |

## Cross-referenced modules

_None_
