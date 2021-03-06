/**
 * =============================================================================
 * Custom Weapon Models
 *
 * Copyright (C) 2015 Andersso
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

void WeaponModels_ApiInit()
{
	RegPluginLibrary("weaponmodels");

	CreateNative("WeaponModels_AddWeaponByClassName", Native_AddWeaponByClassName);
	CreateNative("WeaponModels_AddWeaponByItemDefIndex", Native_AddWeaponByItemDefIndex);
	CreateNative("WeaponModels_RemoveWeaponModel", Native_RemoveWeaponModel);
}

public int Native_AddWeaponByClassName(Handle plugin, int numParams)
{
	char className[CLASS_NAME_MAX_LENGTH];
	GetNativeString(1, className, sizeof(className));

	int weaponIndex = -1;

	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		// Check if class-name is already used
		if (g_WeaponModelInfo[i].Status != WeaponModelInfoStatus_Free && StrEqual(g_WeaponModelInfo[i].ClassName, className, false))
		{
			if (CheckForwardCleanup(i))
			{
				// If the forward handle is cleaned up, it also means that the index is no longer used
				weaponIndex = i;

				break;
			}

			return -1;
		}
	}

	if (weaponIndex == -1 && (weaponIndex = GetFreeWeaponInfoIndex()) == -1)
	{
		return -1;
	}

	char viewModel[PLATFORM_MAX_PATH + 1];
	char worldModel[PLATFORM_MAX_PATH + 1];
	GetNativeString(2, viewModel, sizeof(viewModel));
	GetNativeString(3, worldModel, sizeof(worldModel));

	g_WeaponModelInfo[weaponIndex].DefIndex = -1;

	strcopy(g_WeaponModelInfo[weaponIndex].ClassName, CLASS_NAME_MAX_LENGTH, className);

	AddWeapon(weaponIndex, viewModel, worldModel, plugin, GetNativeCell(4));

	return weaponIndex;
}

public int Native_AddWeaponByItemDefIndex(Handle plugin, int numParams)
{
	int itemDefIndex = GetNativeCell(1);

	if (itemDefIndex < 0)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Item definition index was invalid");
	}

	int weaponIndex = -1;

	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		// Check if definition index is already used
		if (g_WeaponModelInfo[i].Status != WeaponModelInfoStatus_Free && g_WeaponModelInfo[i].DefIndex == itemDefIndex)
		{
			if (CheckForwardCleanup(i))
			{
				// If the forward handle is cleaned up, it also means that the index is no longer used
				weaponIndex = i;

				break;
			}

			// FIXME: What is this?
			return -1;
		}
	}

	if (weaponIndex == -1 && (weaponIndex = GetFreeWeaponInfoIndex()) == -1)
	{
		return -1;
	}

	g_WeaponModelInfo[weaponIndex].DefIndex = itemDefIndex;

	char viewModel[PLATFORM_MAX_PATH + 1];
	char worldModel[PLATFORM_MAX_PATH + 1];
	
	GetNativeString(2, viewModel, sizeof(viewModel));
	GetNativeString(3, worldModel, sizeof(worldModel));

	AddWeapon(weaponIndex, viewModel, worldModel, plugin, GetNativeCell(4));

	return weaponIndex;
}

void AddWeapon(int weaponIndex, const char[] viewModel, const char[] worldModel, Handle plugin, Function _function) // <- SP-Compiler error
{
	Handle forwardHandle = CreateForward(ET_Single, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell);

	AddToForward(forwardHandle, plugin, _function);

	g_WeaponModelInfo[weaponIndex].SequenceCount = -1;
	g_WeaponModelInfo[weaponIndex].Forward = forwardHandle;

	strcopy(g_WeaponModelInfo[weaponIndex].ViewModel, PLATFORM_MAX_PATH + 1, viewModel);
	strcopy(g_WeaponModelInfo[weaponIndex].WorldModel, PLATFORM_MAX_PATH + 1, worldModel);

	PrecacheWeaponInfo(weaponIndex);

	g_WeaponModelInfo[weaponIndex].Status = WeaponModelInfoStatus_API;
}

bool CheckForwardCleanup(int weaponIndex)
{
	Handle forwardHandle = g_WeaponModelInfo[weaponIndex].Forward;

	if (forwardHandle != INVALID_HANDLE)
	{
		forwardHandle.Close();

		return true;
	}

	return false;
}

int GetFreeWeaponInfoIndex()
{
	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		if (g_WeaponModelInfo[i].Status == WeaponModelInfoStatus_Free)
		{
			return i;
		}
	}

	return -1;
}

public int Native_RemoveWeaponModel(Handle plugin, int numParams)
{
	int weaponIndex = GetNativeCell(1);

	if (weaponIndex < 0 || weaponIndex >= MAX_CUSTOM_WEAPONS)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Weapon index was invalid");
	}

	g_WeaponModelInfo[weaponIndex].Forward.Close();

	if (!g_bEconomyWeapons)
	{
		CleanUpSwapWeapon(weaponIndex);
	}
	
	g_WeaponModelInfo[weaponIndex].Status = WeaponModelInfoStatus_Free;

	return 0;
}

bool ExecuteForward(int weaponIndex, int client, int weapon, const char[] className, int itemDefIndex = -1)
{
	Handle forwardHandle = g_WeaponModelInfo[weaponIndex].Forward;

	// Clean-up, if required
	if (!GetForwardFunctionCount(forwardHandle))
	{
		CloseHandle(forwardHandle);

		g_WeaponModelInfo[weaponIndex].Status = WeaponModelInfoStatus_Free;

		return false;
	}

	Call_StartForward(g_WeaponModelInfo[weaponIndex].Forward);

	Call_PushCell(weaponIndex);
	Call_PushCell(client);
	Call_PushCell(weapon);
	Call_PushString(className);
	Call_PushCell(itemDefIndex);

	bool result;
	Call_Finish(result);

	return result;
}