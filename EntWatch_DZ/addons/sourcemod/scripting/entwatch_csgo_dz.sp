#pragma semicolon 1
#pragma newdecls required
#pragma dynamic 131072
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <csgocolors_fix>

#include "entwatch/smlib.inc"
#include "entwatch/function.inc"

ArrayList g_ItemConfig;
ArrayList g_ItemList;
class_Scheme g_SchemeConfig;

//-------------------------------------------------------
// Purpose: Plugin settings
//-------------------------------------------------------
ConVar	g_hCvar_TeamOnly,
		g_hCvar_Delay_Use,
		g_hCvar_Scheme,
		g_hCvar_BlockEPick;

//-------------------------------------------------------
// Purpose: Plugin Local settings
//-------------------------------------------------------
bool	g_bTeamOnly = true,
		g_bBlockEPick = true;
int		g_iDelayUse = 3;

//-------------------------------------------------------
// Purpose: Plugin Variables
//-------------------------------------------------------
bool g_bConfigLoaded = false;
bool g_bIsAdmin[MAXPLAYERS+1] = {false,...};

//uncomment the next line if you using DynamicChannels: https://github.com/Vauff/DynamicChannels
//#define DYNAMIC_CHANNELS
#if defined DYNAMIC_CHANNELS
#include <DynamicChannels>
#endif

//Modules can be included as you wish. To do this, comment out or uncomment the corresponding module
#include "entwatch/module_chat.inc"
#include "entwatch/module_hud.inc"
#include "entwatch/module_forwards.inc" //For the include EntWatch.inc to work correctly, use with module_eban
#include "entwatch/module_eban.inc"
#include "entwatch/module_offline_eban.inc" // Need module_eban. Experimental
#include "entwatch/module_natives.inc" //For the include EntWatch.inc to work correctly, use with module_eban
#include "entwatch/module_transfer.inc"
#include "entwatch/module_spawn_item.inc"
#include "entwatch/module_menu.inc"
#include "entwatch/module_glow.inc"
#include "entwatch/module_use_priority.inc"
#include "entwatch/module_extended_logs.inc"
//#include "entwatch/module_clantag.inc"

//#include "entwatch/module_physbox.inc" //Heavy module for the server. Not recommended. Need Collision Hook Ext https://forums.alliedmods.net/showthread.php?t=197815
//#include "entwatch/module_debug.inc"
//End Section Modules

#if defined EW_MODULE_EBAN
ArrayList g_TriggerArray;
#endif

public Plugin myinfo = 
{
	name = "EntWatch",
	author = "DarkerZ[RUS]",
	description = "Notify players about entity interactions.",
	version = "3.DZ.36",
	url = "dark-skill.ru"
};
 
public void OnPluginStart()
{
	g_ItemConfig = new ArrayList(512);
	g_ItemList = new ArrayList(512);
	
	#if defined EW_MODULE_EBAN
	g_TriggerArray = new ArrayList(512);
	#endif
	
	#if defined EW_MODULE_PHYSBOX
	EWM_Physbox_OnPluginStart();
	#endif
	
	//CVARs
	g_hCvar_TeamOnly		= CreateConVar("entwatch_mode_teamonly", "1", "Enable/Disable team only mode.", _, true, 0.0, true, 1.0);
	g_hCvar_Delay_Use		= CreateConVar("entwatch_delay_use", "3", "Change delay before use", _, true, 0.0, true, 60.0);
	g_hCvar_Scheme			= CreateConVar("entwatch_scheme", "classic", "The name of the scheme config.", _);
	g_hCvar_BlockEPick		= CreateConVar("entwatch_blockepick", "1", "Block players from using E key to grab items.", _, true, 0.0, true, 1.0);
	
	//Commands
	RegAdminCmd("sm_ew_reloadconfig", EW_Command_ReloadConfig, ADMFLAG_CONFIG);
	RegAdminCmd("sm_setcooldown", EW_Command_Cooldown, ADMFLAG_BAN);
	RegAdminCmd("sm_setmaxuses", EW_Command_Setmaxuses, ADMFLAG_BAN);
	RegAdminCmd("sm_addmaxuses", EW_Command_Addmaxuses, ADMFLAG_BAN);
	RegAdminCmd("sm_ewsetmode", EW_Command_Setmode, ADMFLAG_BAN);
	RegAdminCmd("sm_ewsetname", EW_Command_Setname, ADMFLAG_BAN);
	RegAdminCmd("sm_ewsetshortname", EW_Command_Setshortname, ADMFLAG_BAN);
	
	//Hook CVARs
	HookConVarChange(g_hCvar_TeamOnly, Cvar_Main_Changed);
	HookConVarChange(g_hCvar_Delay_Use, Cvar_Main_Changed);
	HookConVarChange(g_hCvar_BlockEPick, Cvar_Main_Changed);
	
	//Fix for plugin reload (?)
	g_bTeamOnly = GetConVarBool(g_hCvar_TeamOnly);
	g_iDelayUse = GetConVarInt(g_hCvar_Delay_Use);
	g_bBlockEPick = GetConVarBool(g_hCvar_BlockEPick);
	
	//Hook Events
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	
	//Hook Output Right-Click
	HookEntityOutput("game_ui", "PressedAttack2", Event_GameUI_RightClick);
	
	//Hook Output OutValue
	HookEntityOutput("math_counter", "OutValue", Event_OutValue);
	
	//Load Scheme
	LoadScheme();
	
	#if defined EW_MODULE_EBAN
	EWM_Eban_OnPluginStart();
	#endif
	#if defined EW_MODULE_OFFLINE_EBAN
	EWM_OfflineEban_OnPluginStart();
	#endif
	#if defined EW_MODULE_TRANSFER
	EWM_Transfer_OnPluginStart();
	#endif
	#if defined EW_MODULE_SPAWN
	EWM_Spawn_OnPluginStart();
	#endif
	#if defined EW_MODULE_MENU
	EWM_Menu_OnPluginStart();
	#endif
	#if defined EW_MODULE_HUD
	EWM_Hud_OnPluginStart();
	#endif
	#if defined EW_MODULE_GLOW
	EWM_Glow_OnPluginStart();
	#endif
	#if defined EW_MODULE_DEBUG
	EWM_Debug_OnPluginStart();
	#endif
	#if defined EW_MODULE_USE_PRIORITY
	EWM_Use_Priority_OnPluginStart();
	#endif
	
	#if defined EW_MODULE_CLANTAG
	EWM_Clantag_OnPluginStart();
	#endif
	
	LoadTranslations("EntWatch_DZ.phrases");
	LoadTranslations("common.phrases");
	
	AutoExecConfig(true, "EntWatch_DZ");
	
	#if defined EW_MODULE_FORWARDS
	EWM_Forwards_OnPluginStart();
	#endif
	
	#if defined EW_MODULE_NATIVES
	EWM_Natives_OnPluginStart();
	#endif
}

public void OnPluginEnd()
{
	#if defined EW_MODULE_CLANTAG
	EWM_Clantag_Mass_Reset();
	#endif
}

public void Cvar_Main_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar==g_hCvar_TeamOnly)
		g_bTeamOnly = GetConVarBool(convar);
	else if(convar==g_hCvar_Delay_Use)
		g_iDelayUse = GetConVarInt(convar);
	else if (convar == g_hCvar_BlockEPick)
		g_bBlockEPick = GetConVarBool(convar);
}

public void OnMapStart()
{
	CleanData();
	LoadConfig();
	LoadScheme();
	#if defined EW_MODULE_EBAN
	EWM_Eban_OnMapStart();
	#endif
	#if defined EW_MODULE_GLOW
	EWM_Glow_OnMapStart();
	#endif
	#if defined EW_MODULE_HUD
	EWM_Hud_OnMapStart();
	#endif
}

public void OnMapEnd()
{
	#if defined EW_MODULE_GLOW
	EWM_Glow_OnMapEnd();
	#endif
	
	#if defined EW_MODULE_CLANTAG
	EWM_Clantag_Mass_Reset();
	#endif
}

public Action Event_RoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(g_bConfigLoaded) CPrintToChatAll("%s%t %s%t", g_SchemeConfig.Color_Tag, "EW_Tag", g_SchemeConfig.Color_Warning, "Welcome");
	
	#if defined EW_MODULE_CLANTAG
	EWM_Clantag_Mass_Reset();
	#endif
}

public Action Event_RoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(g_bConfigLoaded) 
	{
		//Unhook Buttons
		for(int i = 0; i < g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			for(int j = 0; j < ItemTest.ButtonsArray.Length; j++)
			{
				int CurrentButton = ItemTest.ButtonsArray.Get(j);
				SDKUnhook(CurrentButton, SDKHook_Use, OnButtonUse);
			}
			SDKUnhook(ItemTest.WeaponID, SDKHook_SpawnPost, OnItemSpawned);
		}
		#if defined EW_MODULE_EBAN
		//Unhook Triggers
		for(int i = 0; i < g_TriggerArray.Length; i++)
		{
			int iEntity = g_TriggerArray.Get(i);
			SDKUnhook(iEntity, SDKHook_Touch, OnTrigger);
			SDKUnhook(iEntity, SDKHook_EndTouch, OnTrigger);
			SDKUnhook(iEntity, SDKHook_StartTouch, OnTrigger);
		}
		#endif
		g_ItemList.Clear();
		#if defined EW_MODULE_EBAN
		g_TriggerArray.Clear();
		#endif
		#if defined EW_MODULE_PHYSBOX
		EWM_Physbox_Event_RoundEnd();
		#endif
	}
}

public Action Event_PlayerTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int team = GetEventInt(hEvent, "team");
	
	if (team != 1) return Plugin_Continue;
	
	EWM_Drop_Forward(hEvent); //Re-use code for death and team changes
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	EWM_Drop_Forward(hEvent); //Re-use code for death and team changes
	return Plugin_Continue;
}

stock void EWM_Drop_Forward(Handle hEvent)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (g_bConfigLoaded)
	{
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.OwnerID == iClient)
			{
				ItemTest.OwnerID = INVALID_ENT_REFERENCE;
				g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				
				#if defined EW_MODULE_GLOW
				EWM_Glow_GlowWeapon(ItemTest, i, false);
				#endif
				
				#if defined EW_MODULE_ELOGS
				EWM_ELogs_PlayerDeath(ItemTest, iClient);
				#endif
				
				if(IsValidEdict(ItemTest.WeaponID) && GetSlotCSGO(ItemTest.WeaponID) != -1)
				{
					if(ItemTest.ForceDrop)
					{
						SDKHooks_DropWeapon(iClient, ItemTest.WeaponID);
						#if defined EW_MODULE_CHAT
						if(ItemTest.Chat) EWM_Chat_PlayerDeath_Drop(ItemTest, iClient);
						#endif
						
						#if defined EW_MODULE_CLANTAG
						EWM_Clantag_Reset(iClient);
						#endif
					}
					else
					{
						if(GetSlotCSGO(ItemTest.WeaponID) == 2)
						{
							#if defined EW_MODULE_CHAT
							if(ItemTest.Chat) EWM_Chat_PlayerDeath(ItemTest, iClient);
							#endif
							
							#if defined EW_MODULE_CLANTAG
							EWM_Clantag_Reset(iClient);
							#endif
							AcceptEntityInput(ItemTest.WeaponID, "Kill");
						}else
						{
							#if defined EW_MODULE_CHAT
							if(ItemTest.Chat) EWM_Chat_PlayerDeath_Drop(ItemTest, iClient);
							#endif
							
							#if defined EW_MODULE_CLANTAG
							EWM_Clantag_Reset(iClient);
							#endif
							
							SDKHooks_DropWeapon(iClient, ItemTest.WeaponID);
						}
					}
				}
			}
		}
	}
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_WeaponDropPost, OnWeaponDrop);
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKHook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
	
	g_bIsAdmin[iClient] = false;
	#if defined EW_MODULE_EBAN
	EWM_Eban_OnClientPutInServer(iClient);
	#endif
	#if defined EW_MODULE_HUD
	if(!AreClientCookiesCached(iClient)) EWM_Hud_LoadDefaultClientSettings(iClient);
	#endif
	#if defined EW_MODULE_USE_PRIORITY
	if(!AreClientCookiesCached(iClient)) EWM_Use_Priority_LoadDefaultClientSettings(iClient);
	#endif
}

public void OnClientCookiesCached(int iClient)
{
	#if defined EW_MODULE_HUD
	EWM_Hud_OnClientCookiesCached(iClient);
	#endif
	#if defined EW_MODULE_USE_PRIORITY
	EWM_Use_Priority_OnClientCookiesCached(iClient);
	#endif
}

public void OnClientPostAdminCheck(int iClient)
{
	if(!IsValidClient(iClient) || !IsClientConnected(iClient) || IsFakeClient(iClient)) return;
	#if defined EW_MODULE_OFFLINE_EBAN
	EWM_OfflineEban_OnClientPostAdminCheck(iClient);
	#endif
	int iFlags = GetUserFlagBits(iClient);
	if(iFlags & ADMFLAG_KICK || iFlags & ADMFLAG_ROOT) g_bIsAdmin[iClient] = true;
}

public void OnClientDisconnect(int iClient)
{
	if(g_bConfigLoaded)
	{
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.OwnerID == iClient)
			{
				ItemTest.OwnerID = INVALID_ENT_REFERENCE;
				g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				
				#if defined EW_MODULE_ELOGS
				EWM_ELogs_Disconnect(ItemTest, iClient);
				#endif
				if(IsValidEdict(ItemTest.WeaponID) && GetSlotCSGO(ItemTest.WeaponID) != -1)
				{
					if(ItemTest.ForceDrop)
					{
						SDKHooks_DropWeapon(iClient, ItemTest.WeaponID);
						#if defined EW_MODULE_CHAT
						if(ItemTest.Chat) EWM_Chat_Disconnect_Drop(ItemTest, iClient);
						#endif
					}
					else
					{
						if(GetSlotCSGO(ItemTest.WeaponID) == 2)
						{
							#if defined EW_MODULE_CHAT
							if(ItemTest.Chat) EWM_Chat_Disconnect(ItemTest, iClient);
							#endif
							
							AcceptEntityInput(ItemTest.WeaponID, "Kill");
						}else
						{
							#if defined EW_MODULE_CHAT
							if(ItemTest.Chat) EWM_Chat_Disconnect_Drop(ItemTest, iClient);
							#endif
							
							SDKHooks_DropWeapon(iClient, ItemTest.WeaponID);
						}
					}
				}
				#if defined EW_MODULE_GLOW
				EWM_Glow_GlowWeapon(ItemTest, i, false);
				#endif
			}
		}
	}
	
	g_bIsAdmin[iClient] = false;
	#if defined EW_MODULE_EBAN
	EWM_Eban_OnClientDisconnect(iClient);
	#endif
	#if defined EW_MODULE_OFFLINE_EBAN
	EWM_OfflineEban_OnClientDisconnect(iClient);
	#endif
	#if defined EW_MODULE_HUD
	EWM_Hud_LoadDefaultClientSettings(iClient);
	#endif
	#if defined EW_MODULE_CLANTAG
	EWM_Clantag_OnClientDisconnect(iClient);
	#endif
	//SDKHooks automatically handles unhooking on disconnect
	/*SDKUnhook(iClient, SDKHook_WeaponDropPost, OnWeaponDrop);
	SDKUnhook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKUnhook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);*/
}

void CleanData()
{
	g_ItemList.Clear();
	#if defined EW_MODULE_EBAN
	g_TriggerArray.Clear();
	#endif
	g_ItemConfig.Clear();
}

stock void LoadConfig()
{
	Handle hKeyValues = CreateKeyValues("entities");
	char sBuffer_map[128], sBuffer_path[PLATFORM_MAX_PATH], sBuffer_path_override[PLATFORM_MAX_PATH], sBuffer_temp[32];

	GetCurrentMap(sBuffer_map, sizeof(sBuffer_map));
	FormatEx(sBuffer_path, sizeof(sBuffer_path), "cfg/sourcemod/entwatch/maps/%s.cfg", sBuffer_map);
	FormatEx(sBuffer_path_override, sizeof(sBuffer_path_override), "cfg/sourcemod/entwatch/maps/%s_override.cfg", sBuffer_map);
	if(FileExists(sBuffer_path_override))
	{
		FileToKeyValues(hKeyValues, sBuffer_path_override);
		LogMessage("Loading %s", sBuffer_path_override);
	}else
	{
		FileToKeyValues(hKeyValues, sBuffer_path);
		LogMessage("Loading %s", sBuffer_path);
	}
	
	KvRewind(hKeyValues);
	if(KvGotoFirstSubKey(hKeyValues))
	{
		do
		{
			class_ItemConfig NewItem;
			KvGetString(hKeyValues, "name", sBuffer_temp, sizeof(sBuffer_temp), "");
			FormatEx(NewItem.Name, sizeof(NewItem.Name), "%s", sBuffer_temp);

			KvGetString(hKeyValues, "shortname", sBuffer_temp, sizeof(sBuffer_temp), "");
			FormatEx(NewItem.ShortName, sizeof(NewItem.ShortName), "%s", sBuffer_temp);

			KvGetString(hKeyValues, "color", sBuffer_temp, sizeof(sBuffer_temp), "");
			FormatEx(NewItem.Color, sizeof(NewItem.Color), "%s", sBuffer_temp);

			NewItem.GlowColor[0]=255;
			NewItem.GlowColor[1]=255;
			NewItem.GlowColor[2]=255;
			NewItem.GlowColor[3]=200;
			
			#if defined EW_MODULE_GLOW
			if(StrEqual(sBuffer_temp,"{green}",false)){NewItem.GlowColor[0]=0;NewItem.GlowColor[1]=255;NewItem.GlowColor[2]=0;}
			else if(StrEqual(sBuffer_temp,"{default}",false)){NewItem.GlowColor[0]=255;NewItem.GlowColor[1]=255;NewItem.GlowColor[2]=255;}
			else if(StrEqual(sBuffer_temp,"{darkred}",false)){NewItem.GlowColor[0]=175;NewItem.GlowColor[1]=0;NewItem.GlowColor[2]=0;}
			else if(StrEqual(sBuffer_temp,"{purple}",false)){NewItem.GlowColor[0]=128;NewItem.GlowColor[1]=0;NewItem.GlowColor[2]=128;}
			else if(StrEqual(sBuffer_temp,"{lightgreen}",false)){NewItem.GlowColor[0]=104;NewItem.GlowColor[1]=238;NewItem.GlowColor[2]=104;}
			else if(StrEqual(sBuffer_temp,"{lime}",false)){NewItem.GlowColor[0]=119;NewItem.GlowColor[1]=234;NewItem.GlowColor[2]=7;}
			else if(StrEqual(sBuffer_temp,"{red}",false)){NewItem.GlowColor[0]=255;NewItem.GlowColor[1]=30;NewItem.GlowColor[2]=30;}
			else if(StrEqual(sBuffer_temp,"{grey}",false)){NewItem.GlowColor[0]=128;NewItem.GlowColor[1]=128;NewItem.GlowColor[2]=128;}
			else if(StrEqual(sBuffer_temp,"{olive}",false)){NewItem.GlowColor[0]=112;NewItem.GlowColor[1]=130;NewItem.GlowColor[2]=56;}
			else if(StrEqual(sBuffer_temp,"{a}",false)){NewItem.GlowColor[0]=192;NewItem.GlowColor[1]=192;NewItem.GlowColor[2]=192;}
			else if(StrEqual(sBuffer_temp,"{lightblue}",false)){NewItem.GlowColor[0]=93;NewItem.GlowColor[1]=130;NewItem.GlowColor[2]=255;}
			else if(StrEqual(sBuffer_temp,"{blue}",false)){NewItem.GlowColor[0]=0;NewItem.GlowColor[1]=0;NewItem.GlowColor[2]=255;}
			else if(StrEqual(sBuffer_temp,"{d}",false)){NewItem.GlowColor[0]=102;NewItem.GlowColor[1]=153;NewItem.GlowColor[2]=204;}
			else if(StrEqual(sBuffer_temp,"{pink}",false)){NewItem.GlowColor[0]=255;NewItem.GlowColor[1]=105;NewItem.GlowColor[2]=180;}
			else if(StrEqual(sBuffer_temp,"{darkorange}",false)){NewItem.GlowColor[0]=240;NewItem.GlowColor[1]=94;NewItem.GlowColor[2]=35;}
			else if(StrEqual(sBuffer_temp,"{orange}",false)){NewItem.GlowColor[0]=255;NewItem.GlowColor[1]=140;NewItem.GlowColor[2]=0;}
			else if(StrEqual(sBuffer_temp,"{white}",false)){NewItem.GlowColor[0]=255;NewItem.GlowColor[1]=255;NewItem.GlowColor[2]=255;}
			else if(StrEqual(sBuffer_temp,"{yellow}",false)){NewItem.GlowColor[0]=199;NewItem.GlowColor[1]=234;NewItem.GlowColor[2]=7;}
			else if(StrEqual(sBuffer_temp,"{magenta}",false)){NewItem.GlowColor[0]=255;NewItem.GlowColor[1]=105;NewItem.GlowColor[2]=180;}
			else if(StrEqual(sBuffer_temp,"{silver}",false)){NewItem.GlowColor[0]=192;NewItem.GlowColor[1]=192;NewItem.GlowColor[2]=192;}
			else if(StrEqual(sBuffer_temp,"{bluegrey}",false)){NewItem.GlowColor[0]=102;NewItem.GlowColor[1]=153;NewItem.GlowColor[2]=204;}
			else if(StrEqual(sBuffer_temp,"{lightred}",false)){NewItem.GlowColor[0]=255;NewItem.GlowColor[1]=90;NewItem.GlowColor[2]=90;}
			else if(StrEqual(sBuffer_temp,"{cyan}",false)){NewItem.GlowColor[0]=0;NewItem.GlowColor[1]=150;NewItem.GlowColor[2]=220;}
			else if(StrEqual(sBuffer_temp,"{gray}",false)){NewItem.GlowColor[0]=128;NewItem.GlowColor[1]=128;NewItem.GlowColor[2]=128;}
			#endif
			
			KvGetString(hKeyValues, "buttonclass", sBuffer_temp, sizeof(sBuffer_temp), "");
			FormatEx(NewItem.ButtonClass, sizeof(NewItem.ButtonClass), "%s", sBuffer_temp);
			
			KvGetString(hKeyValues, "filtername", sBuffer_temp, sizeof(sBuffer_temp), "");
			FormatEx(NewItem.FilterName, sizeof(NewItem.FilterName), "%s", sBuffer_temp);
			
			KvGetString(hKeyValues, "blockpickup", sBuffer_temp, sizeof(sBuffer_temp), "false");
			NewItem.BlockPickup = StrEqual(sBuffer_temp, "true", false);
			
			KvGetString(hKeyValues, "allowtransfer", sBuffer_temp, sizeof(sBuffer_temp), "false");
			NewItem.AllowTransfer = StrEqual(sBuffer_temp, "true", false);
			
			KvGetString(hKeyValues, "forcedrop", sBuffer_temp, sizeof(sBuffer_temp), "false");
			NewItem.ForceDrop = StrEqual(sBuffer_temp, "true", false);
			
			KvGetString(hKeyValues, "chat", sBuffer_temp, sizeof(sBuffer_temp), "false");
			NewItem.Chat = StrEqual(sBuffer_temp, "true", false);
			
			KvGetString(hKeyValues, "chat_uses", sBuffer_temp, sizeof(sBuffer_temp), "false");
			NewItem.Chat_Uses = StrEqual(sBuffer_temp, "true", false);
			
			KvGetString(hKeyValues, "hud", sBuffer_temp, sizeof(sBuffer_temp), "false");
			NewItem.Hud = StrEqual(sBuffer_temp, "true", false);
			
			KvGetString(hKeyValues, "hammerid", sBuffer_temp, sizeof(sBuffer_temp), "0");
			NewItem.HammerID = StringToInt(sBuffer_temp);
			
			KvGetString(hKeyValues, "energyid", sBuffer_temp, sizeof(sBuffer_temp), "0");
			NewItem.EnergyID = StringToInt(sBuffer_temp);
			
			KvGetString(hKeyValues, "mode", sBuffer_temp, sizeof(sBuffer_temp), "0");
			NewItem.Mode = StringToInt(sBuffer_temp);
			
			KvGetString(hKeyValues, "maxuses", sBuffer_temp, sizeof(sBuffer_temp), "0");
			NewItem.MaxUses = StringToInt(sBuffer_temp);
			
			KvGetString(hKeyValues, "cooldown", sBuffer_temp, sizeof(sBuffer_temp), "0");
			NewItem.CoolDown = StringToInt(sBuffer_temp);
			
			if(!StrEqual(NewItem.ButtonClass, "game_ui"))
			{
				KvGetString(hKeyValues, "buttonid", sBuffer_temp, sizeof(sBuffer_temp), "0");
				NewItem.ButtonID = StringToInt(sBuffer_temp);
			}else
			{
				NewItem.ButtonID = -5;
			}
			
			KvGetString(hKeyValues, "trigger", sBuffer_temp, sizeof(sBuffer_temp), "0");
			NewItem.Trigger = StringToInt(sBuffer_temp);
			
			KvGetString(hKeyValues, "pt_spawner", sBuffer_temp, sizeof(sBuffer_temp), "");
			FormatEx(NewItem.Spawner, sizeof(NewItem.Spawner), "%s", sBuffer_temp);
			
			KvGetString(hKeyValues, "physbox", sBuffer_temp, sizeof(sBuffer_temp), "false");
			NewItem.PhysBox = StrEqual(sBuffer_temp, "true", false);
			
			KvGetString(hKeyValues, "use_priority", sBuffer_temp, sizeof(sBuffer_temp), "true");
			NewItem.UsePriority = StrEqual(sBuffer_temp, "true", false);
			
			g_ItemConfig.PushArray(NewItem, sizeof(NewItem));
		} while (KvGotoNextKey(hKeyValues));
		g_bConfigLoaded = true;
	} else {
		g_bConfigLoaded = false;
		LogMessage("Could not load %s", sBuffer_path);
	}
}

stock void LoadScheme()
{
	//SetDefault
	g_SchemeConfig.Color_Tag		= "{green}";
	g_SchemeConfig.Color_Name		= "{default}";
	g_SchemeConfig.Color_SteamID	= "{grey}";
	g_SchemeConfig.Color_Use		= "{lightblue}";
	g_SchemeConfig.Color_Pickup		= "{lime}";
	g_SchemeConfig.Color_Drop		= "{pink}";
	g_SchemeConfig.Color_Disconnect	= "{orange}";
	g_SchemeConfig.Color_Death		= "{orange}";
	g_SchemeConfig.Color_Warning	= "{orange}";
	g_SchemeConfig.Color_Enabled	= "{green}";
	g_SchemeConfig.Color_Disabled	= "{red}";
	g_SchemeConfig.Color_HUD[0]		= 255;
	g_SchemeConfig.Color_HUD[1]		= 255;
	g_SchemeConfig.Color_HUD[2]		= 255;
	g_SchemeConfig.Color_HUD[3]		= 255;
	g_SchemeConfig.Pos_HUD_X		= 0.0;
	g_SchemeConfig.Pos_HUD_Y		= 0.4;
	
	KeyValues KvConfig = CreateKeyValues("EW_Scheme");
	char	ConfigFullPath[PLATFORM_MAX_PATH],
			ConfigFile[16];
	GetConVarString(g_hCvar_Scheme, ConfigFile, sizeof(ConfigFile));
	FormatEx(ConfigFullPath, sizeof(ConfigFullPath), "cfg/sourcemod/entwatch/scheme/%s.cfg", ConfigFile);
	if(!FileToKeyValues(KvConfig, ConfigFullPath))
	{
		CloseHandle(KvConfig);
		LogError("[ERROR] Don't open file to keyvalues: %s", ConfigFullPath);
		return;
	}
	
	char szBuffer[64];
	KvConfig.Rewind();
	
	KvConfig.GetString("color_tag", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Tag, sizeof(g_SchemeConfig.Color_Tag), "%s", szBuffer);
	
	KvConfig.GetString("color_name", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Name, sizeof(g_SchemeConfig.Color_Name), "%s", szBuffer);
	
	KvConfig.GetString("color_steamid", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_SteamID, sizeof(g_SchemeConfig.Color_SteamID), "%s", szBuffer);
	
	KvConfig.GetString("color_use", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Use, sizeof(g_SchemeConfig.Color_Use), "%s", szBuffer);
	
	KvConfig.GetString("color_pickup", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Pickup, sizeof(g_SchemeConfig.Color_Pickup), "%s", szBuffer);
	
	KvConfig.GetString("color_drop", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Drop, sizeof(g_SchemeConfig.Color_Drop), "%s", szBuffer);
	
	KvConfig.GetString("color_disconnect", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Disconnect, sizeof(g_SchemeConfig.Color_Disconnect), "%s", szBuffer);
	
	KvConfig.GetString("color_death", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Death, sizeof(g_SchemeConfig.Color_Death), "%s", szBuffer);
	
	KvConfig.GetString("color_warning", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Warning, sizeof(g_SchemeConfig.Color_Warning), "%s", szBuffer);
	
	KvConfig.GetString("color_enabled", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Enabled, sizeof(g_SchemeConfig.Color_Enabled), "%s", szBuffer);
	
	KvConfig.GetString("color_disabled", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Color_Disabled, sizeof(g_SchemeConfig.Color_Disabled), "%s", szBuffer);
	
	#if defined EW_MODULE_EBAN
	KvConfig.GetString("server_name", szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer,"")) FormatEx(g_SchemeConfig.Server_Name, sizeof(g_SchemeConfig.Server_Name), "%s", szBuffer);
		else FormatEx(g_SchemeConfig.Server_Name, sizeof(g_SchemeConfig.Server_Name), "Server");
	#endif
	#if defined EW_MODULE_HUD
	KvConfig.GetColor4("color_hud", g_SchemeConfig.Color_HUD);
	g_SchemeConfig.Pos_HUD_X = KvConfig.GetFloat("pos_hud_x");
	g_SchemeConfig.Pos_HUD_Y = KvConfig.GetFloat("pos_hud_y");
	#endif
	
	CloseHandle(KvConfig);
}

public bool RegisterItem(class_ItemConfig ItemConfig, int iEntity, int iHammerID)
{
	if (ItemConfig.HammerID && ItemConfig.HammerID == iHammerID)
	{
		//register New Item
		class_ItemList NewItem;
		FormatEx(NewItem.Name,			sizeof(NewItem.Name),			"%s",	ItemConfig.Name);
		FormatEx(NewItem.ShortName,		sizeof(NewItem.ShortName),		"%s",	ItemConfig.ShortName);
		FormatEx(NewItem.Color,			sizeof(NewItem.Color),			"%s",	ItemConfig.Color);
		FormatEx(NewItem.ButtonClass,	sizeof(NewItem.ButtonClass),	"%s",	ItemConfig.ButtonClass);
		FormatEx(NewItem.FilterName,	sizeof(NewItem.FilterName),		"%s",	ItemConfig.FilterName);
		NewItem.BlockPickup = ItemConfig.BlockPickup;
		NewItem.AllowTransfer = ItemConfig.AllowTransfer;
		NewItem.ForceDrop = ItemConfig.ForceDrop;
		NewItem.Chat = ItemConfig.Chat;
		NewItem.Chat_Uses = ItemConfig.Chat_Uses;
		NewItem.Hud = ItemConfig.Hud;
		NewItem.HammerID = ItemConfig.HammerID;
		
		if(ItemConfig.EnergyID==0) NewItem.EnergyID = INVALID_ENT_REFERENCE;
			else NewItem.EnergyID = ItemConfig.EnergyID;
		NewItem.MathID = INVALID_ENT_REFERENCE;
		NewItem.MathValue = -1;
		NewItem.MathValueMax = -1;
		
		NewItem.Mode = ItemConfig.Mode;
		NewItem.MaxUses = ItemConfig.MaxUses;
		NewItem.CoolDown = ItemConfig.CoolDown;
		NewItem.GlowColor[0] = ItemConfig.GlowColor[0];
		NewItem.GlowColor[1] = ItemConfig.GlowColor[1];
		NewItem.GlowColor[2] = ItemConfig.GlowColor[2];
		NewItem.GlowColor[3] = ItemConfig.GlowColor[3];
		
		NewItem.WeaponID = iEntity;
		NewItem.ButtonsArray = new ArrayList();
		
		NewItem.OwnerID = INVALID_ENT_REFERENCE;
		NewItem.CoolDownTime = -1.0;
		if(ItemConfig.ButtonID==0) NewItem.ButtonID = INVALID_ENT_REFERENCE;
			else NewItem.ButtonID = ItemConfig.ButtonID;
		
		NewItem.UpdateTime();
		NewItem.SetDelay(g_iDelayUse);
		NewItem.GlowEnt = INVALID_ENT_REFERENCE;
		
		NewItem.PhysBox = ItemConfig.PhysBox;
		NewItem.UsePriority = ItemConfig.UsePriority;
		NewItem.Team = -1;
		//PrintToServer("[EW]Item Spawned: %s |%i", NewItem.ShortName, iEntity);
		g_ItemList.PushArray(NewItem, sizeof(NewItem));
		
		#if defined EW_MODULE_GLOW
		if(g_bGlow_Spawn)
			for(int i = 0; i<g_ItemList.Length; i++)
			{
				class_ItemList ItemTest;
				g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
				if(ItemTest.WeaponID == iEntity)
				{
					EWM_Glow_GlowWeapon(ItemTest, i, true);
					break;
				}
			}
		#endif
		
		return true;
	}
	return false;
}

public bool RegisterButton(class_ItemList ItemInstance, int iEntity)
{
	if(IsValidEntity(ItemInstance.WeaponID))
	{
		char Item_Weapon_Targetname[64], Item_Weapon_Parent[64];
		Entity_GetTargetName(ItemInstance.WeaponID, Item_Weapon_Targetname, sizeof(Item_Weapon_Targetname));
		Entity_GetParentName(iEntity, Item_Weapon_Parent, sizeof(Item_Weapon_Parent));
		if (!StrEqual(Item_Weapon_Targetname,"") && StrEqual(Item_Weapon_Targetname, Item_Weapon_Parent))
		{
			if(ItemInstance.ButtonID == INVALID_ENT_REFERENCE) ItemInstance.ButtonID = Entity_GetHammerID(iEntity); //Default the first button spawned will be the main button. Need to module use_priority
			SDKHookEx(iEntity, SDKHook_Use, OnButtonUse);
			ItemInstance.ButtonsArray.Push(iEntity);
			return true;
		}
	}
	return false;
}

public bool RegisterMath(class_ItemList ItemInstance, int iEntity)
{
	if (IsValidEntity(ItemInstance.WeaponID))
	{
		if (ItemInstance.EnergyID == Entity_GetHammerID(iEntity))
		{
			char Item_Counter_Targetname[64];
			Entity_GetTargetName(iEntity, Item_Counter_Targetname, sizeof(Item_Counter_Targetname));
			int iTLocCounter = FindCharInString(Item_Counter_Targetname, '&', true);
			if(iTLocCounter == -1)
			{
				ItemInstance.MathID = iEntity;
				int max = RoundFloat(GetEntPropFloat(iEntity, Prop_Data, "m_flMax"));
				int value = GetCounterValue(iEntity);
				if (ItemInstance.Mode == 6) ItemInstance.MathValue = value;
				else if (ItemInstance.Mode == 7) ItemInstance.MathValue = (max - value);
				ItemInstance.MathValueMax = max;
				return true;
			}else
			{
				char Item_Weapon_Targetname[64];
				Entity_GetTargetName(ItemInstance.WeaponID, Item_Weapon_Targetname, sizeof(Item_Weapon_Targetname));
				int iTLocWeapon = FindCharInString(Item_Weapon_Targetname, '&', true);
				if(iTLocWeapon == -1) return false;
				if(strcmp(Item_Counter_Targetname[iTLocCounter+1], Item_Weapon_Targetname[iTLocWeapon+1], false) == 0)
				{
					ItemInstance.MathID = iEntity;
					int max = RoundFloat(GetEntPropFloat(iEntity, Prop_Data, "m_flMax"));
					int value = GetCounterValue(iEntity);
					if (ItemInstance.Mode == 6) ItemInstance.MathValue = value;
					else if (ItemInstance.Mode == 7) ItemInstance.MathValue = (max - value);
					ItemInstance.MathValueMax = max;
					return true;
				}
			}
		}
	}
	return false;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(IsValidEntity(iEntity))
	{
		if(StrContains(sClassname, "weapon_", false) != -1) SDKHook(iEntity, SDKHook_SpawnPost, OnItemSpawned);
		else if(StrEqual(sClassname,"func_button")||StrEqual(sClassname,"func_rot_button")||
			StrEqual(sClassname,"func_door")||StrEqual(sClassname,"func_door_rotating")) SDKHook(iEntity, SDKHook_SpawnPost, OnButtonSpawned);
		else if (StrEqual(sClassname,"math_counter")) SDKHook(iEntity, SDKHook_SpawnPost, OnMathSpawned);
		#if defined EW_MODULE_EBAN
		else if(StrContains(sClassname, "trigger_", false) != -1) SDKHook(iEntity, SDKHook_SpawnPost, OnTriggerSpawned);
		#endif
		#if defined EW_MODULE_PHYSBOX
		else if(StrContains(sClassname, "func_physbox", false) != -1) SDKHook(iEntity, SDKHook_SpawnPost, OnPhysboxSpawned);
		#endif
	}
}

public void OnEntityDestroyed(int iEntity)
{
	if(IsValidEdict(iEntity))
	{
		char sClassname[32];
		GetEdictClassname(iEntity, sClassname, sizeof(sClassname));
		if(StrContains(sClassname, "weapon_", false) != -1)
		{
			for(int i = 0; i < g_ItemList.Length; i++)
			{
				class_ItemList ItemTest;
				g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
				if(ItemTest.WeaponID == iEntity)
				{
					#if defined EW_MODULE_CLANTAG
					EWM_Clantag_Reset(ItemTest.OwnerID);
					#endif
					ItemTest.MathID = INVALID_ENT_REFERENCE;
					ItemTest.WeaponID = INVALID_ENT_REFERENCE;
					ItemTest.OwnerID = INVALID_ENT_REFERENCE;
					ItemTest.GlowEnt = INVALID_ENT_REFERENCE;
					g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				}
			}
		}
		#if defined EW_MODULE_PHYSBOX
		else if(StrContains(sClassname, "func_physbox", false) != -1) EWM_Physbox_OnEntityDestroyed(iEntity);
		#endif
	}
}

public void OnItemSpawned(int iEntity)
{
	if(!IsValidEntity(iEntity) || !g_bConfigLoaded) return;
	
	int iHammerID = Entity_GetHammerID(iEntity);
	if(iHammerID>0)
	{
		for(int i = 0; i<g_ItemConfig.Length; i++)
		{
			class_ItemConfig ItemTest;
			g_ItemConfig.GetArray(i, ItemTest, sizeof(ItemTest));
			if(RegisterItem(ItemTest, iEntity, iHammerID)) return;
		}
	}
}

public void OnMathSpawned(int iEntity)
{
	//In case the math entity spawns just before the weapon entity (?)
	CreateTimer(0.5, Timer_OnMathSpawned, iEntity);
	
}

public Action Timer_OnMathSpawned(Handle timer, int iEntity)
{
	if(!IsValidEntity(iEntity) || !g_bConfigLoaded) return;
	
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		class_ItemList ItemTest;
		g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
		if (RegisterMath(ItemTest, iEntity))
		{
			g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
			return;
		}
	}
}

public void OnButtonSpawned(int iEntity) //Button with parent spawns after weapon entity. With timer button don't register if item spawns with module items_spawn
{
	if(!IsValidEntity(iEntity) || !g_bConfigLoaded) return;
	
	char sClassname[32];
	GetEdictClassname(iEntity, sClassname, sizeof(sClassname));
	if (StrEqual(sClassname,"func_door") || StrEqual(sClassname,"func_door_rotating"))
	{
		int spawnflags = GetEntProp(iEntity, Prop_Data, "m_spawnflags");
		if (!(spawnflags & 256))return; //The entity cannot be pressed so don't register it as a button
	}
	
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		class_ItemList ItemTest;
		g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
		if (RegisterButton(ItemTest,iEntity))
		{
			g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
			return;
		}
	}
}

#if defined EW_MODULE_EBAN
public void OnTriggerSpawned(int iEntity)
{
	//In case the trigger entity spawns just before the weapon entity (?)
	CreateTimer(0.5, Timer_OnTriggerSpawned, iEntity);
}

public Action Timer_OnTriggerSpawned(Handle timer, int iEntity)
{
	if(!IsValidEntity(iEntity) || !g_bConfigLoaded) return;
	
	int iHammerID = Entity_GetHammerID(iEntity);
	if(iHammerID>0)
	{
		for(int i = 0; i<g_ItemConfig.Length; i++)
		{
			class_ItemConfig ItemTest;
			g_ItemConfig.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.Trigger == iHammerID)
			{
				g_TriggerArray.Push(iEntity);
				SDKHookEx(iEntity, SDKHook_Touch, OnTrigger);
				SDKHookEx(iEntity, SDKHook_EndTouch, OnTrigger);
				SDKHookEx(iEntity, SDKHook_StartTouch, OnTrigger);
			}
		}
	}
}

public Action OnTrigger(int iEntity, int iClient)
{
    if (IsValidClient(iClient) && IsClientConnected(iClient)) if (g_EbanClients[iClient].Banned) return Plugin_Handled;

    return Plugin_Continue;
}
#endif

//-------------------------------------------------------
//Purpose: Notify when they use a special weapon
//-------------------------------------------------------
public Action OnButtonUse(int iButton, int iActivator, int iCaller, UseType uType, float fvalue)
{
	if(g_bConfigLoaded && IsValidEdict(iButton))
	{
		//DEBUG SHIT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		//char edebug[32];
		//Entity_GetTargetName(iButton, edebug, sizeof(edebug));
		//PrintToConsoleAll("[EntWatch] PRESS Button %s by %N - ID %i", edebug, iActivator, iActivator);
		
		int iOffset = FindDataMapInfo(iButton, "m_bLocked");
		if (iOffset != -1 && GetEntData(iButton, iOffset, 1)) return Plugin_Handled;

		for(int i = 0; i < g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(IsValidEdict(ItemTest.WeaponID))
			{
				ItemTest.UpdateTime();
				for(int j = 0; j < ItemTest.ButtonsArray.Length; j++)
				{
					if(ItemTest.ButtonsArray.Get(j) == iButton)
					{
						//DEBUG SHIT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
						//PrintToConsoleAll("[EntWatch] DEBUG: Name - %s, WeaponID - %i", ItemTest.Name, ItemTest.WeaponID);
						//PrintToConsoleAll("[EntWatch] DEBUG: Uses - %i", ItemTest.Uses);
						//PrintToConsoleAll("[EntWatch] DEBUG: CooldownTime - %i", ItemTest.CoolDownTime);
						//PrintToConsoleAll("[EntWatch] DEBUG: Owner - %i", ItemTest.OwnerID);
						//if (!IsValidClient(ItemTest.OwnerID))
						//{
						//	LogError("No valid client for %s - %i", ItemTest.Name, ItemTest.OwnerID);
						//}
						//PrintToConsoleAll("[EntWatch] DEBUG: Chat - %s", ItemTest.Chat ? "True" : "False");
						//PrintToConsoleAll("[EntWatch] DEBUG: Mode - %i", ItemTest.Mode);
						//PrintToConsoleAll("[EntWatch] DEBUG: Delay - %i", ItemTest.Delay);
						//PrintToConsoleAll("[EntWatch] DEBUG: ButtonID - %i", ItemTest.ButtonID);
						//PrintToConsoleAll("[EntWatch] DEBUG: iButton - %i", iButton);
						//PrintToConsoleAll("[EntWatch] DEBUG: HammerID of iButton - %i", Entity_GetHammerID(iButton));
						
						
						if(ItemTest.OwnerID != iActivator && ItemTest.OwnerID != iCaller) return Plugin_Handled;
							else if(!(StrEqual(ItemTest.FilterName,""))) DispatchKeyValue(iActivator, "targetname", ItemTest.FilterName);
						
						if(ItemTest.CheckDelay() > 0) return Plugin_Handled;
						
						//Base delay on the wait time of the button (button is locked for this duration)
						int waitTime = RoundToFloor(GetEntPropFloat(iButton, Prop_Data, "m_flWait"));
						
						if(ItemTest.ButtonID != INVALID_ENT_REFERENCE && ItemTest.ButtonID != Entity_GetHammerID(iButton)) return Plugin_Changed;
						
						switch (ItemTest.Mode)
						{
							case 2: 
								if(ItemTest.CheckCoolDown() <= 0)
								{
									#if defined EW_MODULE_ELOGS
									EWM_ELogs_Use(ItemTest, iActivator);
									#endif
									#if defined EW_MODULE_CHAT
									if(ItemTest.Chat || ItemTest.Chat_Uses) EWM_Chat_Use(ItemTest, iActivator);
									#endif
									
									ItemTest.SetDelay(waitTime);
									ItemTest.SetCoolDown(ItemTest.CoolDown);
									g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
									return Plugin_Changed;
								}
							case 3:
								if(ItemTest.Uses < ItemTest.MaxUses)
								{
									#if defined EW_MODULE_ELOGS
									EWM_ELogs_Use(ItemTest, iActivator);
									#endif
									#if defined EW_MODULE_CHAT
									if(ItemTest.Chat || ItemTest.Chat_Uses) EWM_Chat_Use(ItemTest, iActivator);
									#endif
									
									ItemTest.SetDelay(waitTime);
									ItemTest.Uses++;
									g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
									return Plugin_Changed;
								}
							case 4:
								if(ItemTest.Uses < ItemTest.MaxUses && ItemTest.CheckCoolDown() <= 0)
								{
									#if defined EW_MODULE_ELOGS
									EWM_ELogs_Use(ItemTest, iActivator);
									#endif
									#if defined EW_MODULE_CHAT
									if(ItemTest.Chat || ItemTest.Chat_Uses) EWM_Chat_Use(ItemTest, iActivator);
									#endif
									
									ItemTest.SetDelay(waitTime);
									ItemTest.SetCoolDown(ItemTest.CoolDown);
									ItemTest.Uses++;
									g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
									return Plugin_Changed;
								}
							case 5:
								if(ItemTest.CheckCoolDown() <= 0)
								{
									#if defined EW_MODULE_ELOGS
									EWM_ELogs_Use(ItemTest, iActivator);
									#endif
									#if defined EW_MODULE_CHAT
									if(ItemTest.Chat || ItemTest.Chat_Uses) EWM_Chat_Use(ItemTest, iActivator);
									#endif
									
									ItemTest.SetDelay(waitTime);
									ItemTest.Uses++;
									if(ItemTest.Uses >= ItemTest.MaxUses)
									{
										ItemTest.SetCoolDown(ItemTest.CoolDown);
										ItemTest.Uses = 0;
									}
									g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
									return Plugin_Changed;
								}
							case 6,7:
							{
								if(ItemTest.CoolDown > 0)
								{
									if(ItemTest.CheckCoolDown() <= 0)
									{
										#if defined EW_MODULE_ELOGS
										EWM_ELogs_Use(ItemTest, iActivator);
										#endif
										#if defined EW_MODULE_CHAT
										if(ItemTest.Chat || ItemTest.Chat_Uses) EWM_Chat_Use(ItemTest, iActivator);
										#endif
										
										ItemTest.SetDelay(waitTime);
										ItemTest.SetCoolDown(ItemTest.CoolDown);
										g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
									}else return Plugin_Handled;
								}
								return Plugin_Changed;
							}
							default: return Plugin_Changed;
						}
						//~~~~ Is this return needed (?) ~~~~
						return Plugin_Handled;
					}
				}
			}
		}
	}
	return Plugin_Handled;
}

//-------------------------------------------------------
//Purpose: Update item energy from math counter
//-------------------------------------------------------
public Action Event_OutValue(const char[] sOutput, int iCaller, int iActivator, float Delay)
{
	for(int i = 0; i < g_ItemList.Length; i++)
	{
		class_ItemList ItemTest;
		g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
		if (ItemTest.MathID == iCaller)
		{
			int max = RoundFloat(GetEntPropFloat(iCaller, Prop_Data, "m_flMax"));
			int value = GetCounterValue(iCaller);
			if (ItemTest.Mode == 6) ItemTest.MathValue = value;
			else if (ItemTest.Mode == 7) ItemTest.MathValue = (max - value);
			ItemTest.MathValueMax = max;
			g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
			return;
		}
	}
}

//-------------------------------------------------------
//Purpose: Notify when they use a special weapon
//-------------------------------------------------------
public Action Event_GameUI_RightClick(const char[] sOutput, int iCaller, int iActivator, float Delay)
{
	if(g_bConfigLoaded)
	{
		for(int i = 0; i < g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			
			if(ItemTest.ButtonID==-5 && IsValidEdict(ItemTest.WeaponID))
			{
				ItemTest.UpdateTime();
				
				if(ItemTest.OwnerID==iActivator)
				{
					if(!(StrEqual(ItemTest.FilterName,""))) DispatchKeyValue(iActivator, "targetname", ItemTest.FilterName);
					if(ItemTest.CheckDelay() > 0) return Plugin_Handled;
					
					switch (ItemTest.Mode)
					{
						case 2: 
							if(ItemTest.CheckCoolDown() <= 0)
							{
								#if defined EW_MODULE_ELOGS
								EWM_ELogs_Use(ItemTest, iActivator);
								#endif
								#if defined EW_MODULE_CHAT
								if(ItemTest.Chat) EWM_Chat_Use(ItemTest, iActivator);
								#endif
								
								ItemTest.SetCoolDown(ItemTest.CoolDown);
								g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
								return Plugin_Continue;
							}
						case 3:
							if(ItemTest.Uses < ItemTest.MaxUses)
							{
								#if defined EW_MODULE_ELOGS
								EWM_ELogs_Use(ItemTest, iActivator);
								#endif
								#if defined EW_MODULE_CHAT
								if(ItemTest.Chat) EWM_Chat_Use(ItemTest, iActivator);
								#endif
								
								ItemTest.Uses++;
								g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
								return Plugin_Continue;
							}
						case 4:
							if(ItemTest.Uses < ItemTest.MaxUses && ItemTest.CheckCoolDown() <= 0)
							{
								#if defined EW_MODULE_ELOGS
								EWM_ELogs_Use(ItemTest, iActivator);
								#endif
								#if defined EW_MODULE_CHAT
								if(ItemTest.Chat) EWM_Chat_Use(ItemTest, iActivator);
								#endif
								
								ItemTest.SetCoolDown(ItemTest.CoolDown);
								ItemTest.Uses++;
								g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
								return Plugin_Continue;
							}
						case 5:
							if(ItemTest.CheckCoolDown() <= 0)
							{
								#if defined EW_MODULE_ELOGS
								EWM_ELogs_Use(ItemTest, iActivator);
								#endif
								#if defined EW_MODULE_CHAT
								if(ItemTest.Chat) EWM_Chat_Use(ItemTest, iActivator);
								#endif
								
								ItemTest.Uses++;
								if(ItemTest.Uses >= ItemTest.MaxUses)
								{
									ItemTest.SetCoolDown(ItemTest.CoolDown);
									ItemTest.Uses = 0;
								}
								g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
								return Plugin_Continue;
							}
						case 6,7:
						{
							if(ItemTest.CoolDown > 0)
							{
								if(ItemTest.CheckCoolDown() <= 0)
								{
									#if defined EW_MODULE_ELOGS
									EWM_ELogs_Use(ItemTest, iActivator);
									#endif
									#if defined EW_MODULE_CHAT
									if(ItemTest.Chat || ItemTest.Chat_Uses) EWM_Chat_Use(ItemTest, iActivator);
									#endif
									
									ItemTest.SetCoolDown(ItemTest.CoolDown);
									g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
								}else return Plugin_Changed;
							}
							return Plugin_Continue;
						}
						default: return Plugin_Continue;
					}
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}

//-------------------------------------------------------
//Purpose: Notify when they drop a special weapon
//-------------------------------------------------------
public Action OnWeaponDrop(int iClient, int iWeapon)
{
	if(g_bConfigLoaded && IsValidEdict(iWeapon))
	{
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.WeaponID == iWeapon)
			{
				ItemTest.OwnerID = INVALID_ENT_REFERENCE;
				g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				
				#if defined EW_MODULE_GLOW
				EWM_Glow_GlowWeapon(ItemTest, i, false);
				#endif
				
				#if defined EW_MODULE_ELOGS
				EWM_ELogs_Drop(ItemTest, iClient);
				#endif
				#if defined EW_MODULE_CHAT
				if(ItemTest.Chat) EWM_Chat_Drop(ItemTest, iClient);
				#endif
				
				#if defined EW_MODULE_CLANTAG
				EWM_Clantag_Reset(iClient);
				#endif
					
				break;
			}
		}
	}
}

//-------------------------------------------------------
//Purpose: Prevent banned players from picking up special weapons
//-------------------------------------------------------
public Action OnWeaponCanUse(int iClient, int iWeapon)
{
	if (IsFakeClient(iClient)) return Plugin_Handled;
	
	if(g_bConfigLoaded && IsValidEdict(iWeapon))
	{
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.WeaponID == iWeapon)
			{
				#if defined EW_MODULE_EBAN
				if(ItemTest.BlockPickup || g_EbanClients[iClient].Banned || ((GetClientButtons(iClient) & IN_USE) && g_bBlockEPick)) return Plugin_Handled;
				#else
				if(ItemTest.BlockPickup || ((GetClientButtons(iClient) & IN_USE) && g_bBlockEPick)) return Plugin_Handled;
				#endif
				
				return Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}

//-------------------------------------------------------
//Purpose: Notify when they pick up a special weapon
//-------------------------------------------------------
public Action OnWeaponEquip(int iClient, int iWeapon)
{
	if(g_bConfigLoaded && IsValidEdict(iWeapon))
	{
		for(int i = 0; i < g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.WeaponID == iWeapon)
			{
				ItemTest.OwnerID = iClient;
				ItemTest.UpdateTime();
				ItemTest.SetDelay(g_iDelayUse);
				ItemTest.Team = GetClientTeam(iClient);
				
				#if defined EW_MODULE_GLOW
				EWM_Glow_DisableGlow(ItemTest);
				#endif
				
				g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				
				#if defined EW_MODULE_ELOGS
				EWM_ELogs_PickUp(ItemTest, iClient);
				#endif
				#if defined EW_MODULE_CHAT
				if(ItemTest.Chat) EWM_Chat_PickUp(ItemTest, iClient);
				#endif
				
				#if defined EW_MODULE_OFFLINE_EBAN
				EWM_OfflineEban_UpdateItemName(iClient, ItemTest.Name);
				#endif
				
				break;
			}
		}
		#if defined EW_MODULE_PHYSBOX
		EWM_Physbox_Pickedup(iClient, iWeapon);
		#endif
	}
}

// Handlers Commands
public Action EW_Command_ReloadConfig(int iClient, int iArgs)
{	
	#if defined EW_MODULE_CLANTAG
	EWM_Clantag_Mass_Reset();
	#endif
	
	CleanData();
	LoadConfig();
	LoadScheme();

	return Plugin_Handled;
}

public Action EW_Command_Cooldown(int iClient, int iArgs)
{
	if (iArgs != 2)
	{
		CReplyToCommand(iClient, "%s%t %s%t: sm_setcooldown <hammerid> <cooldown>", g_SchemeConfig.Color_Tag, "EW_Tag", g_SchemeConfig.Color_Warning, "Usage");
		return Plugin_Handled;
	}

	char sHammerID[32], sCooldown[10];

	GetCmdArg(1, sHammerID, sizeof(sHammerID));
	GetCmdArg(2, sCooldown, sizeof(sCooldown));

	int iHammerID = StringToInt(sHammerID);
	int iCooldown = StringToInt(sCooldown);
	
	if(iCooldown < 0) iCooldown = 0;

	if (g_bConfigLoaded)
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.HammerID == iHammerID)
			{
				ItemTest.CoolDown = iCooldown;
				g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
			}
		}

	return Plugin_Handled;
}

public Action EW_Command_Setmaxuses(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		CReplyToCommand(iClient, "%s%t %s%t: sm_setmaxuses <hammerid> <maxuses> [<even if over>]", g_SchemeConfig.Color_Tag, "EW_Tag", g_SchemeConfig.Color_Warning, "Usage");
		return Plugin_Handled;
	}

	char sHammerID[32], sMaxUses[10];

	GetCmdArg(1, sHammerID, sizeof(sHammerID));
	GetCmdArg(2, sMaxUses, sizeof(sMaxUses));
	
	bool bOver = false;
	if(iArgs >= 3)
	{
		char sOver[10];
		GetCmdArg(3, sOver, sizeof(sOver));
		int iOver = StringToInt(sOver);
		if(iOver == 1) bOver = true;
	}

	int iHammerID = StringToInt(sHammerID);
	int iMaxUses = StringToInt(sMaxUses);
	
	if(iMaxUses < 0) iMaxUses = 0;

	if (g_bConfigLoaded)
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.HammerID == iHammerID)
			{
				if(ItemTest.MaxUses > ItemTest.Uses || bOver)
				{
					ItemTest.MaxUses = iMaxUses;
					g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				}
			}
		}

	return Plugin_Handled;
}

public Action EW_Command_Addmaxuses(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%s%t %s%t: sm_addmaxuses <hammerid> [<even if over>]", g_SchemeConfig.Color_Tag, "EW_Tag", g_SchemeConfig.Color_Warning, "Usage");
		return Plugin_Handled;
	}

	char sHammerID[32];

	GetCmdArg(1, sHammerID, sizeof(sHammerID));
	
	bool bOver = false;
	if(iArgs >= 2)
	{
		char sOver[10];
		GetCmdArg(2, sOver, sizeof(sOver));
		int iOver = StringToInt(sOver);
		if(iOver == 1) bOver = true;
	}

	int iHammerID = StringToInt(sHammerID);

	if (g_bConfigLoaded)
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.HammerID == iHammerID)
			{
				if(ItemTest.MaxUses > ItemTest.Uses || bOver)
				{
					ItemTest.MaxUses++;
					g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				}
			}
		}

	return Plugin_Handled;
}

public Action EW_Command_Setmode(int iClient, int iArgs)
{
	if (iArgs < 4)
	{
		CReplyToCommand(iClient, "%s%t %s%t: sm_ewsetmode <hammerid> <newmode> <cooldown> <maxuses> [<even if over>]", g_SchemeConfig.Color_Tag, "EW_Tag", g_SchemeConfig.Color_Warning, "Usage");
		return Plugin_Handled;
	}

	char sHammerID[32], sNewMode[10], sCooldown[10], sMaxUses[10];

	GetCmdArg(1, sHammerID, sizeof(sHammerID));
	GetCmdArg(2, sNewMode, sizeof(sNewMode));
	GetCmdArg(3, sCooldown, sizeof(sCooldown));
	GetCmdArg(4, sMaxUses, sizeof(sMaxUses));
	
	bool bOver = false;
	if(iArgs >= 5)
	{
		char sOver[10];
		GetCmdArg(5, sOver, sizeof(sOver));
		int iOver = StringToInt(sOver);
		if(iOver == 1) bOver = true;
	}

	int iHammerID = StringToInt(sHammerID);
	int iNewMode = StringToInt(sNewMode);
	int iCooldown = StringToInt(sCooldown);
	int iMaxUses = StringToInt(sMaxUses);
	
	if(iNewMode < 1 || iNewMode > 7) iNewMode = 1;
	if(iCooldown < 0) iCooldown = 0;
	if(iMaxUses < 0) iMaxUses = 0;

	if (g_bConfigLoaded)
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.HammerID == iHammerID)
			{
				if(ItemTest.MaxUses > ItemTest.Uses || bOver || iNewMode == 7 || iNewMode == 6 || iNewMode == 2 || iNewMode == 1)
				{
					ItemTest.Mode = iNewMode;
					ItemTest.CoolDown = iCooldown;
					ItemTest.MaxUses = iMaxUses;
					g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
				}
			}
		}

	return Plugin_Handled;
}

public Action EW_Command_Setname(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		CReplyToCommand(iClient, "%s%t %s%t: sm_ewsetname <hammerid> <newname>", g_SchemeConfig.Color_Tag, "EW_Tag", g_SchemeConfig.Color_Warning, "Usage");
		return Plugin_Handled;
	}

	char sHammerID[32], sNewName[32];

	GetCmdArg(1, sHammerID, sizeof(sHammerID));
	GetCmdArg(2, sNewName, sizeof(sNewName));

	int iHammerID = StringToInt(sHammerID);

	TrimString(sNewName);
	
	if (g_bConfigLoaded)
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.HammerID == iHammerID)
			{
				FormatEx(ItemTest.Name, sizeof(ItemTest.Name), "%s", sNewName);
				g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
			}
		}

	return Plugin_Handled;
}

public Action EW_Command_Setshortname(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		CReplyToCommand(iClient, "%s%t %s%t: sm_ewsetshortname <hammerid> <newname>", g_SchemeConfig.Color_Tag, "EW_Tag", g_SchemeConfig.Color_Warning, "Usage");
		return Plugin_Handled;
	}

	char sHammerID[32], sNewName[32];

	GetCmdArg(1, sHammerID, sizeof(sHammerID));
	GetCmdArg(2, sNewName, sizeof(sNewName));

	int iHammerID = StringToInt(sHammerID);

	TrimString(sNewName);
	
	if (g_bConfigLoaded)
		for(int i = 0; i<g_ItemList.Length; i++)
		{
			class_ItemList ItemTest;
			g_ItemList.GetArray(i, ItemTest, sizeof(ItemTest));
			if(ItemTest.HammerID == iHammerID)
			{
				FormatEx(ItemTest.ShortName, sizeof(ItemTest.ShortName), "%s", sNewName);
				g_ItemList.SetArray(i, ItemTest, sizeof(ItemTest));
			}
		}

	return Plugin_Handled;
}
