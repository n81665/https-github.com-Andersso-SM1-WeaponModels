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
 *
 * *Retrieving the offsets from game-binary (Linux)
 *
 * Animating_StudioHdr:
 *  1. StudioHdr offset can be retrieved from CBaseAnimating::GetModelPtr()
 *  2. m_hLightingOrigin offset can be retrieved on runtime using the SM API, or
 *     in ServerClassInit<DT_BaseAnimating::ignored>() and check the param stack on the SendProp init of m_hLightingOrigin
 *  3. And lastly: offset = m_pStudioHdr - m_hLightingOrigin
 *
 *  One last thing, GetModelPtr() returns a CStudioHdr object, which actually acts like a kind of wrapper of the studiohdr_t object.
 *  What we actually want is the pointer of the studiohdr_t object. And lucky we are, it's located as the first member of the
 *  CStudioHdr class. This means that we don't need any extra offset to get the pointer from memory.
 *  
 * Some useful references:
 * CStudioHdr: https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/public/studio.h#L2351
 * studiohdr_t: https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/public/studio.h#L2062
 * 
 * StudioHdrStruct_SequenceCount:
 *  I believe this struct is ancient, and is never expected to change.
 *
 * Animating_GetSequenceActivity:
 *  This function does not reference any strings or anything that makes the function easily searchable.
 *  However, CAI_ScriptedSequence::StartSequence() calls this function, and is referencing following string: "%s: unknown scripted sequence \"%s\"\n"
 *  The function itself should then be the first function referenced after the string.
 */

Handle g_hSDKCall_Entity_UpdateTransmitState; // UpdateTransmitState will stop the view model from transmitting if EF_NODRAW flag is present
Handle g_hSDKCall_Animating_GetSequenceActivity;
// Handle g_hSDKCall_Animating_SequenceDuration;

int g_iOffset_Animating_StudioHdr;
int g_iOffset_StudioHdrStruct_SequenceCount;
int g_iOffset_VirtualModelStruct_SequenceVector_Size;

int g_iOffset_EntityEffects;
int g_iOffset_EntityModelIndex;
int g_iOffset_EntityOwnerEntity;

int g_iOffset_WeaponOwner;
int g_iOffset_WeaponWorldModelIndex;

int g_iOffset_CharacterWeapons;

int g_iOffset_PlayerViewModel;
int g_iOffset_PlayerActiveWeapon;

int g_iOffset_ViewModelOwner;
int g_iOffset_ViewModelWeapon;
int g_iOffset_ViewModelSequence;
int g_iOffset_ViewModelPlaybackRate;
int g_iOffset_ViewModelIndex;

int g_iOffset_ViewModelIgnoreOffsAcc;
int g_iOffset_EconItemDefinitionIndex;

// See https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/public/studio.h#L2371
enum StudioHdrClass
{
	StudioHdrClass_StudioHdrStruct = 0,
	StudioHdrClass_VirualModelStruct = 4
}

void InitGameConfOffset(Handle gameConf, int &offsetDest, const char[] keyName)
{
	if ((offsetDest = GameConfGetOffset(gameConf, keyName)) == -1)
	{
		SetFailState("Failed to get offset: \"%s\"!", keyName);
	}
}

void InitSendPropOffset(int &offsetDest, const char[] serverClass, const char[] propName, bool failOnError = true)
{
	if ((offsetDest = FindSendPropInfo(serverClass, propName)) < 1 && failOnError)
	{
		SetFailState("Failed to find offset: \"%s\"!", propName);
	}
}

void WeaponModels_EntityDataInit()
{
	Handle gameConf = LoadGameConfigFile("plugin.weaponmodels");

	if (gameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(gameConf, SDKConf_Virtual, "Entity_UpdateTransmitState");

		if (!(g_hSDKCall_Entity_UpdateTransmitState = EndPrepSDKCall()))
		{
			SetFailState("Failed to load SDK call \"UpdateTransmitState\"!");
		}

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "Animating_GetSequenceActivity");

		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

		if (!(g_hSDKCall_Animating_GetSequenceActivity = EndPrepSDKCall()))
		{
			SetFailState("Failed to load SDK call \"Animating_GetSequenceActivity\"!");
		}

		// float CBaseAnimating::SequenceDuration( CStudioHdr *pStudioHdr, int iSequence )
		// See https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/server/baseanimating.cpp#L938
		// StartPrepSDKCall(SDKCall_Entity);
		// PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "Animating_SequenceDuration");

		// PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // CStudioHdr *pStudioHdr
		// PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int iSequence
		// PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);

		// if (!(g_hSDKCall_Animating_SequenceDuration = EndPrepSDKCall()))
		// {
		// 	SetFailState("Failed to load SDK call \"Animating_SequenceDuration\"!");
		// }

		InitGameConfOffset(gameConf, g_iOffset_Animating_StudioHdr, "Animating_StudioHdr");
		InitGameConfOffset(gameConf, g_iOffset_StudioHdrStruct_SequenceCount, "StudioHdrStruct_SequenceCount");
		InitGameConfOffset(gameConf, g_iOffset_VirtualModelStruct_SequenceVector_Size, "VirtualModelStruct_SequenceVector_Size");

		CloseHandle(gameConf);
	}
	else
	{
		SetFailState("Failed to load game conf");
	}
	
	InitSendPropOffset(g_iOffset_EntityEffects, "CBaseEntity", "m_fEffects");
	InitSendPropOffset(g_iOffset_EntityModelIndex, "CBaseEntity", "m_nModelIndex");
	InitSendPropOffset(g_iOffset_EntityOwnerEntity, "CBaseEntity", "m_hOwnerEntity");
	
	InitSendPropOffset(g_iOffset_WeaponOwner, "CBaseCombatWeapon", "m_hOwner");
	InitSendPropOffset(g_iOffset_WeaponWorldModelIndex, "CBaseCombatWeapon", "m_iWorldModelIndex");
	
	InitSendPropOffset(g_iOffset_CharacterWeapons, "CBaseCombatCharacter", "m_hMyWeapons");

	InitSendPropOffset(g_iOffset_PlayerViewModel, "CBasePlayer", "m_hViewModel");
	InitSendPropOffset(g_iOffset_PlayerActiveWeapon, "CBasePlayer", "m_hActiveWeapon");

	InitSendPropOffset(g_iOffset_ViewModelOwner, "CBaseViewModel", "m_hOwner");
	InitSendPropOffset(g_iOffset_ViewModelWeapon, "CBaseViewModel", "m_hWeapon");
	InitSendPropOffset(g_iOffset_ViewModelSequence, "CBaseViewModel", "m_nSequence");
	InitSendPropOffset(g_iOffset_ViewModelPlaybackRate, "CBaseViewModel", "m_flPlaybackRate");
	InitSendPropOffset(g_iOffset_ViewModelIndex, "CBaseViewModel", "m_nViewModelIndex");
	
	InitSendPropOffset(g_iOffset_ViewModelIgnoreOffsAcc, "CBaseViewModel", "m_bShouldIgnoreOffsetAndAccuracy", false);
	InitSendPropOffset(g_iOffset_EconItemDefinitionIndex, "CEconEntity", "m_iItemDefinitionIndex", false);

	int lightingOriginOffset;
	InitSendPropOffset(lightingOriginOffset, "CBaseAnimating", "m_hLightingOrigin");

	// StudioHdr offset in gameconf is only relative to the offset of m_hLightingOrigin, in order to make the offset more resilient to game updates
	g_iOffset_Animating_StudioHdr += lightingOriginOffset;
}

int GetPlayerViewModel(int client, int index)
{
	return GetEntDataEnt2(client, g_iOffset_PlayerViewModel + (index * 4));
}

void SetPlayerViewModel(int client, int index, int viewModel)
{
	SetEntDataEnt2(client, g_iOffset_PlayerViewModel + (index * 4), viewModel, true);
}

void SetEntityVisibility(int entity, bool show)
{
	int flags = GetEntData(entity, g_iOffset_EntityEffects);

	SetEntData(entity, g_iOffset_EntityEffects, show ? flags & ~EF_NODRAW : flags | EF_NODRAW, _, true);
}

bool GetEntityVisibility(int entity)
{
	int flags = GetEntData(entity, g_iOffset_EntityEffects);

	return !(flags & EF_NODRAW);
}

// This function simulates the equivalent function in the SDK
// The game has two methods for getting the sequence count:
// 1. Local sequence count if the model has sequences built in the model itself
// 2. Virtual model sequence count if the model inherits the sequences from a different model, also known as an include model
int Animating_GetSequenceCount(int animating)
{
	Address studioHdrClass = view_as<Address>(GetEntData(animating, g_iOffset_Animating_StudioHdr));
	
	if (studioHdrClass == Address_Null)
	{
		return -1;
	}
	
	Address studioHdrStruct = view_as<Address>(LoadFromAddress(studioHdrClass + view_as<Address>(StudioHdrClass_StudioHdrStruct), NumberType_Int32));
	
	if (studioHdrStruct != Address_Null)
	{
		int localSequenceCount = LoadFromAddress(studioHdrStruct + view_as<Address>(g_iOffset_StudioHdrStruct_SequenceCount), NumberType_Int32);
		
		if (localSequenceCount != 0)
		{
			return localSequenceCount;
		}
	}
	
	Address virtualModelStruct = view_as<Address>(LoadFromAddress(studioHdrClass + view_as<Address>(StudioHdrClass_VirualModelStruct), NumberType_Int32));
	
	if (virtualModelStruct != Address_Null)
	{
		return LoadFromAddress(virtualModelStruct + view_as<Address>(g_iOffset_VirtualModelStruct_SequenceVector_Size), NumberType_Int32);
	}
	
	return -1;
}

// This function is far to advanced to be cloned
int Animating_GetSequenceActivity(int animating, int sequence)
{
	return SDKCall(g_hSDKCall_Animating_GetSequenceActivity, animating, sequence);
}

// Address Animating_GetStudioHdrClass(int animating)
// {
// 	return view_as<Address>(GetEntData(animating, g_iOffset_Animating_StudioHdr));
// }

// float Animating_GetSequenceDuration(int animating, int sequence)
// {
// 	Address studioHdr = Animating_GetStudioHdrClass(animating);
// 	return SDKCall(g_hSDKCall_Animating_SequenceDuration, animating, studioHdr, sequence);
// }

// Address StudioHdrClass_GetStudioHdrStruct(Address studioHdrClass)
// {
// 	return studioHdrClass != Address_Null ? view_as<Address>(LoadFromAddress(studioHdrClass, NumberType_Int32)) : Address_Null;
// }

// int StudioHdrGetSequenceCount(Address studioHdrStruct)
// {
// 	return LoadFromAddress(studioHdrStruct + view_as<Address>(g_iOffset_StudioHdrStruct_SequenceCount), NumberType_Int32);
// }

// enum StudioAnimDesc
// {
// 	StudioAnimDesc_Fps = 8,
// 	StudioAnimDesc_NumFrames = 16,
// 	StudioAnimDesc_NumMovements = 20,
// }

// int Animating_GetNumMovements(int animating, int sequence)
// {
// 	Address studioHdrStruct = StudioHdrClass_GetStudioHdrStruct(Animating_GetStudioHdrClass(animating));
	
// 	Address studioAnimDesc = GetLocalAnimDescription(studioHdrStruct, sequence);
	
// 	return StudioAnimDesc_GetValue(studioAnimDesc, StudioAnimDesc_NumMovements);
// }

// Address GetLocalAnimDescription(Address studioHdrStruct, int sequence)
// {
// 	if (sequence < 0 || sequence >= StudioHdrGetSequenceCount(studioHdrStruct))
// 	{
// 		sequence = 0;
// 	}
	
// 	// 	return (mstudioanimdesc_t *)(((byte *)this) + localanimindex) + i;
// 	return studioHdrStruct + view_as<Address>(LoadFromAddress(studioHdrStruct + view_as<Address>(184), NumberType_Int32) + (sequence * 4));
// }

// any StudioAnimDesc_GetValue(Address studioAnimDesc, StudioAnimDesc type, NumberType size = NumberType_Int32)
// {
// 	return LoadFromAddress(studioAnimDesc + view_as<Address>(type), size);
// }