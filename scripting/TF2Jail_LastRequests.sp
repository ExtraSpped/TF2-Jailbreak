#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <adminmenu>
#include <tf2_stocks>
#include <morecolors>
#include <smlib>
#include <autoexecconfig>
#include <jackofdesigns>

//TF2Jail Includes
#include <tf2jail/tf2jail_core>
#include <tf2jail/tf2jail_lastrequests>

#undef REQUIRE_PLUGIN
#tryinclude <roundtimer>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME     "[TF2] TF2Jail - Last Request"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_DESCRIPTION	"Allows Prisoners to receive Last Requests."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"

new Handle:JB_ConVars[9] = {INVALID_HANDLE, ...};
new bool:cv_LRSEnabled = true, bool:cv_LRSAutomatic = true, bool:cv_LRSLockWarden = true, cv_FreedayLimit = 3,
String:Particle_Freeday[100], bool:cv_FreedayTeleports = true, bool:cv_RemoveFreedayOnLR = true,
bool:cv_RemoveFreedayOnLastGuard = true;

new bool:g_bIsLRInUse = false, bool:g_bFreedayTeleportSet = false, bool:g_bLRConfigActive = true,
bool:g_bLateLoad = false, bool:g_bActiveRound = false;

new bool:g_IsFreeday[MAXPLAYERS + 1], bool:g_IsFreedayActive[MAXPLAYERS + 1];

new CustomClient = -1, LR_Pending = -1, LR_Current = -1, FreedayLimit = 0;

new Float:free_pos[3];

new String:LRConfig_File[PLATFORM_MAX_PATH], String:CustomLR[12];

new Handle:LastRequestName;

new Handle:hTimer_ParticleTimer[MAXPLAYERS+1];

new Handle:Forward_OnLastRequestExecute;

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

public OnPluginStart()
{
	File_LoadTranslations("common.phrases");
	File_LoadTranslations("TF2Jail.phrases");
	
	AutoExecConfig_SetFile("TF2Jail_LastRequests");
	
	JB_ConVars[0] = AutoExecConfig_CreateConVar("tf2jail_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD);
	JB_ConVars[1] = AutoExecConfig_CreateConVar("sm_tf2jail_lastrequest_enable", "1", "Status of the LR System: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[2] = AutoExecConfig_CreateConVar("sm_tf2jail_lastrequest_automatic", "1", "Automatically grant last request to last prisoner alive: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[3] = AutoExecConfig_CreateConVar("sm_tf2jail_lastrequest_lock_warden", "1", "Lock Wardens during last request rounds: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[4] = AutoExecConfig_CreateConVar("sm_tf2jail_freeday_limit", "3", "Max number of freedays for the lr: (1.0 - 16.0)", FCVAR_PLUGIN, true, 1.0, true, 16.0);
	JB_ConVars[5] = AutoExecConfig_CreateConVar("sm_tf2jail_particle_freeday", "eyeboss_team_sparks_red", "Name of the Particle for Freedays (0 = Disabled)", FCVAR_PLUGIN);
	JB_ConVars[6] = AutoExecConfig_CreateConVar("sm_tf2jail_freeday_teleport", "1", "Status of teleporting: (1 = enable, 0 = disable) (Disables all functionality regardless of configs)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[7] = AutoExecConfig_CreateConVar("sm_tf2jail_freeday_removeonlr", "1", "Remove Freedays on Last Request: (1 = enable, 0 = disable)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[8] = AutoExecConfig_CreateConVar("sm_tf2jail_freeday_removeonlastguard", "1", "Remove Freedays on Last Guard: (1 = enable, 0 = disable)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	AutoExecConfig_ExecuteFile();
	
	for (new i = 0; i < sizeof(JB_ConVars); i++)
	{
		HookConVarChange(JB_ConVars[i], HandleCvars);
	}
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_hurt", PlayerHurt);
	HookEvent("player_changeclass", ChangeClass, EventHookMode_Pre);
	HookEvent("player_death", PlayerDeath);
	HookEvent("teamplay_round_start", RoundStart);
	HookEvent("arena_round_start", ArenaRoundStart);
	HookEvent("teamplay_round_win", RoundEnd);
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	RegConsoleCmd("sm_givelr", GiveLR);
	RegConsoleCmd("sm_givelastrequest", GiveLR);
	RegConsoleCmd("sm_removelr", RemoveLR);
	RegConsoleCmd("sm_removelastrequest", RemoveLR);
	RegConsoleCmd("sm_currentlr", CurrentLR);
	RegConsoleCmd("sm_currentlastrequests", CurrentLR);
	RegConsoleCmd("sm_lrlist", ListLRs);
	RegConsoleCmd("sm_lrslist", ListLRs);
	RegConsoleCmd("sm_lrs", ListLRs);
	RegConsoleCmd("sm_lastrequestlist", ListLRs);
	
	RegAdminCmd("sm_denylr", AdminDenyLR, ADMFLAG_GENERIC);
	RegAdminCmd("sm_denylastrequest", AdminDenyLR, ADMFLAG_GENERIC);
	RegAdminCmd("sm_forcelr", AdminForceLR, ADMFLAG_GENERIC);
	RegAdminCmd("sm_givefreeday", AdminGiveFreeday, ADMFLAG_GENERIC);
	RegAdminCmd("sm_removefreeday", AdminRemoveFreeday, ADMFLAG_GENERIC);
	
	LastRequestName = CreateHudSynchronizer();
	
	AddMultiTargetFilter("@freedays", FreedaysGroup, "All Freedays.", false);
	AddMultiTargetFilter("@!freedays", NotFreedaysGroup, "All but the Freedays.", false);
	
	BuildPath(Path_SM, LRConfig_File, sizeof(LRConfig_File), "configs/tf2jail/lastrequests.cfg");
	
	AutoExecConfig_CleanFile();
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("TF2Jail_IsFreeday", Native_IsFreeday);
	CreateNative("TF2Jail_GiveFreeday", Native_GiveFreeday);
	CreateNative("TF2Jail_IsLRRound", Native_IsLRRound);
	CreateNative("TF2Jail_LockWardenLR", Native_LockWardenLR);
	CreateNative("TF2Jail_SetFreedayPos", Native_SetFreedayPos);
	
	Forward_OnLastRequestExecute = CreateGlobalForward("TF2Jail_OnLastRequestExecute", ET_Event, Param_String);
	
	RegPluginLibrary("tf2jail");
	
	g_bLateLoad = late;
	return APLRes_Success;
}

public OnPluginEnd()
{
	OnMapEnd();
}

public OnConfigsExecuted()
{
	cv_LRSEnabled = GetConVarBool(JB_ConVars[1]);
	cv_LRSAutomatic = GetConVarBool(JB_ConVars[2]);
	cv_LRSLockWarden = GetConVarBool(JB_ConVars[3]);
	cv_FreedayLimit = GetConVarInt(JB_ConVars[4]);
	GetConVarString(JB_ConVars[5], Particle_Freeday, sizeof(Particle_Freeday));
	cv_FreedayTeleports = GetConVarBool(JB_ConVars[6]);
	cv_RemoveFreedayOnLR = GetConVarBool(JB_ConVars[7]);
	cv_RemoveFreedayOnLastGuard = GetConVarBool(JB_ConVars[8]);
	
	if (g_bLateLoad) {}
}


public HandleCvars (Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue, true)) return;

	new iNewValue = StringToInt(newValue);

	if (cvar == JB_ConVars[0])
	{
		SetConVarString(JB_ConVars[0], PLUGIN_VERSION);
	}
	else if (cvar == JB_ConVars[1])
	{
		cv_LRSEnabled = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[2])
	{
		cv_LRSAutomatic = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[3])
	{
		cv_LRSLockWarden = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[4])
	{
		cv_FreedayLimit = iNewValue;
	}
	else if (cvar == JB_ConVars[5])
	{
		GetConVarString(JB_ConVars[5], Particle_Freeday, sizeof(Particle_Freeday));
	}
	else if (cvar == JB_ConVars[6])
	{
		cv_FreedayTeleports = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[7])
	{
		cv_RemoveFreedayOnLR = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[8])
	{
		cv_RemoveFreedayOnLastGuard = bool:iNewValue;
	}
}

public OnMapEnd()
{
	if (cv_LRSEnabled)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				g_IsFreeday[i] = false;
				
				hTimer_ParticleTimer[i] = INVALID_HANDLE;
				
				ClearSyncHud(i, LastRequestName);
			}
		}

		LR_Current = -1;
	}
}

public OnClientDisconnect(client)
{
	if (IsValidClient(client))
	{
		g_IsFreeday[client] = false;
	}
}

public PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client))
	{
		switch (GetClientTeam(client))
		{
		case TFTeam_Red:
			{
				if (g_IsFreeday[client])
				{
					GiveFreeday(client);
				}
			}
		}
	}
}

public PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new client_attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (IsValidClient(client) && IsValidClient(client_attacker))
	{
		if (client_attacker != client)
		{
			if (g_IsFreedayActive[client_attacker])
			{
				RemoveFreeday(client_attacker);
			}
		}
	}
}

public Action:ChangeClass(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_IsFreedayActive[client])
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		new flags = GetEntityFlags(client)|FL_NOTARGET;
		SetEntityFlags(client, flags);
	}
}

public PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(client))
	{
		new red_count = Team_GetClientCount(_:TFTeam_Red, CLIENTFILTER_ALIVE);
		new blue_count = Team_GetClientCount(_:TFTeam_Blue, CLIENTFILTER_ALIVE);
		
		if (cv_LRSAutomatic && g_bLRConfigActive)
		{
			if (red_count == 1)
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == _:TFTeam_Red)
					{
						LastRequestStart(i);
						TF2Jail_Log("%N has received last request for being the last prisoner alive.", i);
					}
				}
			}
		}
		
		if (cv_RemoveFreedayOnLastGuard)
		{
			if (blue_count == 1)
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (g_IsFreedayActive[i])
					{
						RemoveFreeday(i);
					}
				}
			}
		}

		if (g_IsFreedayActive[client])
		{
			RemoveFreeday(client);
			TF2Jail_Log("%N was an active freeday on round.", client);
		}
		
		ClearTimer(hTimer_ParticleTimer[client]);
	}
}

public RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{	
	g_bIsLRInUse = false;
	g_bActiveRound = true;
}

public ArenaRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (LR_Current != -1)
	{
		new Handle:LastRequestConfig = CreateKeyValues("TF2Jail_LastRequests");
		FileToKeyValues(LastRequestConfig, LRConfig_File);
		
		new String:buffer[255], String:number[255];
		if (KvGotoFirstSubKey(LastRequestConfig))
		{
			do
			{
				IntToString(LR_Current, number, sizeof(number));
				KvGetSectionName(LastRequestConfig, buffer, sizeof(buffer));
				
				if (StrEqual(buffer, number))
				{
					if (StrEqual(CustomLR, ""))
					{
						new String:LR_Name[255];
						KvGetString(LastRequestConfig, "Name", LR_Name, sizeof(LR_Name));
						SetHudTextParams(-1.0, 0.9, 99999.0, 255,0,0, 255);
						for (new i = 1; i <= MaxClients; i++)
						{
							if (IsClientInGame(i) && !IsFakeClient(i))
							{
								ShowSyncHudText(i, LastRequestName, "Last Request: %s", LR_Name);
							}
						}
					}
					
					new String:Handler[64];
					if (KvGetString(LastRequestConfig, "Handler", Handler, sizeof(Handler)))
					{
						Call_StartForward(Forward_OnLastRequestExecute);
						Call_PushString(Handler);
						Call_Finish();
					}
					
					new bool:IsFreedayRound = false, String:ServerCommands[255];
					
					if (KvGetString(LastRequestConfig, "Execute_Cmd", ServerCommands, sizeof(ServerCommands)))
					{
						if (!StrEqual(ServerCommands, ""))
						{							
							TF2Jail_ServerCommand(ServerCommands);
						}
					}
					
					if (KvJumpToKey(LastRequestConfig, "Parameters"))
					{
						if (KvGetNum(LastRequestConfig, "IsFreedayType", 0) != 0)
						{
							IsFreedayRound = true;
						}

						if (KvGetNum(LastRequestConfig, "OpenCells", 0) == 1)
						{
							TF2Jail_ControlDoors(OPEN);
						}
						
						if (KvGetNum(LastRequestConfig, "VoidFreekills", 0) == 1)
						{
							TF2Jail_VoidFreekills(true);
						}
						
						if (KvGetNum(LastRequestConfig, "TimerStatus", 1) == 0)
						{
							RoundTimer_Stop();
						}
						
						if (KvGetNum(LastRequestConfig, "LockWarden", 0) == 1)
						{
							TF2Jail_LockWarden();
						}
						
						if (KvJumpToKey(LastRequestConfig, "KillWeapons"))
						{
							for (new i = 1; i < MaxClients; i++)
							{
								if (IsValidClient(i) && IsPlayerAlive(i))
								{
									switch (GetClientTeam(i))
									{
									case TFTeam_Red:
										{
											if (KvGetNum(LastRequestConfig, "Red", 0) == 1)
											{
												TF2Jail_StripAllWeapons(i);
											}
										}
									case TFTeam_Blue:
										{
											if (KvGetNum(LastRequestConfig, "Blue", 0) == 1)
											{
												TF2Jail_StripAllWeapons(i);
											}
										}
									}
									
									if (KvGetNum(LastRequestConfig, "Warden", 0) == 1 && TF2Jail_IsWarden(i))
									{
										TF2Jail_StripAllWeapons(i);
									}
								}
							}
							KvGoBack(LastRequestConfig);
						}
						
						if (KvJumpToKey(LastRequestConfig, "FriendlyFire"))
						{
							if (KvGetNum(LastRequestConfig, "Status", 0) == 1)
							{
								new Float:TimeFloat = KvGetFloat(LastRequestConfig, "Timer", 1.0);
								if (TimeFloat >= 0.1)
								{
									TF2Jail_StartFFTimer(TimeFloat);
								}
								else
								{
									TF2Jail_Log("[ERROR] Timer is set to a value below 0.1! Timer could not be created.");
								}
							}
							KvGoBack(LastRequestConfig);
						}
						KvGoBack(LastRequestConfig);
					}
					
					decl String:ActiveAnnounce[255];
					if (KvGetString(LastRequestConfig, "Activated", ActiveAnnounce, sizeof(ActiveAnnounce)))
					{
						if (IsFreedayRound)
						{
							decl String:ClientName[32];
							for (new i = 1; i <= MaxClients; i++)
							{
								if (g_IsFreedayActive[i])
								{
									GetClientName(i, ClientName, sizeof(ClientName));
									ReplaceString(ActiveAnnounce, sizeof(ActiveAnnounce), "%M", ClientName, true);
									Format(ActiveAnnounce, sizeof(ActiveAnnounce), "%s %s", JTAG_COLORED, ActiveAnnounce);
									CPrintToChatAll(ActiveAnnounce);
								}
							}
							FreedayForAll(false);
						}
						else
						{
							Format(ActiveAnnounce, sizeof(ActiveAnnounce), "%s %s", JTAG_COLORED, ActiveAnnounce);
							CPrintToChatAll(ActiveAnnounce);
						}
					}
				}
			} while (KvGotoNextKey(LastRequestConfig));
		}
		CloseHandle(LastRequestConfig);
	}
	
	if (!StrEqual(CustomLR, ""))
	{
		SetHudTextParams(-1.0, 0.9, 99999.0, 255,0,0, 255);
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowSyncHudText(i, LastRequestName, "Last Request: %s", CustomLR);
			}
		}
		CustomLR[0] = '\0';
	}
}

public RoundEnd(Handle:hEvent, const String:strName[], bool:bBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{			
			if (g_IsFreedayActive[i])
			{
				RemoveFreeday(i);
			}
			
			TF2Jail_UnlockWarden();
			
			ClearSyncHud(i, LastRequestName);
		}
	}
	
	
	FreedayLimit = 0;
	
	if (LR_Current != -1)
	{
		new Handle:LastRequestConfig = CreateKeyValues("TF2Jail_LastRequests");
		FileToKeyValues(LastRequestConfig, LRConfig_File);
		
		new String:buffer[255], String:number[255];
		if (KvGotoFirstSubKey(LastRequestConfig))
		{
			do
			{
				IntToString(LR_Current, number, sizeof(number));
				KvGetSectionName(LastRequestConfig, buffer, sizeof(buffer));
				
				if (StrEqual(buffer, number))
				{
					new String:ServerCommands[255];
					if (KvGetString(LastRequestConfig, "Ending_Cmd", ServerCommands, sizeof(ServerCommands)))
					{
						if (!StrEqual(ServerCommands, ""))
						{							
							TF2Jail_ServerCommand(ServerCommands);
						}
					}
				}
			} while (KvGotoNextKey(LastRequestConfig));
		}
		CloseHandle(LastRequestConfig);
	}
	
	LR_Current = -1;
	if (LR_Pending != -1)
	{
		LR_Current = LR_Pending;
		LR_Pending = -1;
	}
	
	g_bActiveRound = false;
}

public Action:Command_Say(client, const String:command[], args)
{
	if (client == CustomClient)
	{
		strcopy(CustomLR, sizeof(CustomLR), command);
		CPrintToChat(client, "Next round LR set to: %s", JTAG_COLORED, CustomLR);
		CustomClient = -1;
	}
	return Plugin_Continue;
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

public Action:AdminForceLR(client, args)
{
	if (!g_bLRConfigActive)
	{
		CReplyToCommand(client, "%s %t", JTAG, "last request config invalid");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Last Request Self");
		LastRequestStart(client);
		TF2Jail_Log("Admin %N has given his/herself last request using admin.", client);
	}
	else
	{
		decl String:arg[64];
		GetCmdArgString(arg, sizeof(arg));

		new target = FindTarget(client, arg, true, false);
		if (target != -1 || target != client)
		{
			CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Last Request", target);
			LastRequestStart(target, false);
			TF2Jail_Log("Admin %N has gave %N a Last Request by admin.", client, target);
		}
	}
	
	return Plugin_Handled;
}

public Action:AdminDenyLR(client, args)
{
	if (g_bLRConfigActive)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				if (g_IsFreeday[i])
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "admin removed freeday");
					g_IsFreeday[i] = false;
				}
				
				if (g_IsFreedayActive[i])
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "admin removed freeday active");
					g_IsFreedayActive[i] = false;
				}
				
				ClearSyncHud(i, LastRequestName);
			}
		}
		
		g_bIsLRInUse = false;
		
		LR_Pending = -1;
		LR_Current = -1;
		
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Deny Last Request");
		TF2Jail_Log("Admin %N has denied all currently queued last requests and reset the last request system.", client);
	}
	else
	{
		CReplyToCommand(client, "%s %t", JTAG, "last request config invalid");
	}
	return Plugin_Handled;
}

public Action:AdminGiveFreeday(client, args)
{
	if (g_bLRConfigActive)
	{
		if (IsValidClient(client))
		{
			GiveFreedaysMenu(client);
		}
		else
		{
			CReplyToCommand(client, "%s %t", JTAG, "Command is in-game only");
		}
	}
	else
	{
		CReplyToCommand(client, "%s %t", JTAG, "last request config invalid");
	}
	return Plugin_Handled;
}

GiveFreedaysMenu(client)
{
	if(!IsVoteInProgress())
	{
		new Handle:menu = CreateMenu(MenuHandle_FreedayAdmins, MENU_ACTIONS_ALL);
		SetMenuTitle(menu,"Choose a Player");
		AddTargetsToMenu2(menu, 0, COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY);
		DisplayMenu(menu, client, 20);
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Give Freeday Menu");
		TF2Jail_Log("Admin %N is giving someone a freeday...", client);
	}
}

public MenuHandle_FreedayAdmins(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu, item, info, sizeof(info));

			new target = GetClientOfUserId(StringToInt(info));
			if (IsValidClient(target))
			{
				GiveFreeday(target);
				TF2Jail_Log("%N has given %N a Freeday.", target, client);
			}
			else
			{
				PrintToChat(client, "Client is not valid.");
			}
			GiveFreedaysMenu(client);
		}
	case MenuAction_End: CloseHandle(menu);
	}
}

public Action:AdminRemoveFreeday(client, args)
{
	if (g_bLRConfigActive)
	{
		if (IsValidClient(client))
		{
			RemoveFreedaysMenu(client);
		}
		else
		{
			CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
		}
	}
	else
	{
		CReplyToCommand(client, "%s %t", JTAG, "last request config invalid");
	}
	return Plugin_Handled;
}

RemoveFreedaysMenu(client)
{
	if(!IsVoteInProgress())
	{
		new Handle:menu = CreateMenu(MenuHandle_RemoveFreedays, MENU_ACTIONS_ALL);
		SetMenuTitle(menu,"Choose a Player");
		AddTargetsToMenu2(menu, 0, COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY);
		DisplayMenu(menu, client, 20);
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Remove Freeday Menu");
		TF2Jail_Log("Admin %N is removing someone's freeday status...", client);
	}
}

public MenuHandle_RemoveFreedays(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu, item, info, sizeof(info));

			new target = GetClientOfUserId(StringToInt(info));
			if (IsValidClient(target))
			{
				RemoveFreeday(target);
				TF2Jail_Log("%N has removed %N's Freeday.", target, client);
			}
			else
			{
				PrintToChat(client, "Client is not valid.");
			}
			RemoveFreedaysMenu(client);
		}
	case MenuAction_End: CloseHandle(menu);
	}
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

public Action:GiveLR(client, args)
{	
	if (!cv_LRSEnabled)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "lr system disabled");
		return Plugin_Handled;
	}
	else if (!g_bLRConfigActive)
	{
		CReplyToCommand(client, "%s %t", JTAG, "last request config invalid");
		return Plugin_Handled;
	}
	
	if (IsValidClient(client))
	{
		if (TF2Jail_IsWarden(client))
		{
			if (!g_bIsLRInUse)
			{
				if (!IsVoteInProgress())
				{
					new Handle:menu = CreateMenu(MenuHandle_GiveLR, MENU_ACTIONS_ALL);
					SetMenuTitle(menu,"Choose a Player:");
					AddTargetsToMenu2(menu, 0, COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY);
					DisplayMenu(menu, client, 20);
					TF2Jail_Log("%N is giving someone a last request...", client);
				}
			}
			else
			{
				CPrintToChat(client, "%s %t", JTAG_COLORED, "last request in use");
			}
		}
		else
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
		}
	}
	else
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public MenuHandle_GiveLR(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			new String:info[32];
			GetMenuItem(menu, item, info, sizeof(info));
			new iUserid = GetClientOfUserId(StringToInt(info));
			
			if (IsValidClient(iUserid) && TF2Jail_WardenActive())
			{
				decl String:Name[32];
				GetClientName(iUserid, Name, sizeof(Name));
				
				if (GetClientTeam(iUserid) != _:TFTeam_Red)
				{
					PrintToChat(client,"You cannot give LR to a guard or spectator!");
				}
				else
				{
					LastRequestStart(iUserid);
					CPrintToChatAll("%s %t", JTAG_COLORED, "last request given", TF2Jail_GetWarden(), iUserid);
					TF2Jail_Log("%N has given %N a Last Request as warden.", client, iUserid);
				}
			}
		}
	case MenuAction_End: CloseHandle(menu);
	}
}

public Action:CurrentLR(client, args)
{
	if (LR_Current != -1)
	{
		new String:number[255];
		new Handle:LastRequestConfig = CreateKeyValues("TF2Jail_LastRequests");
		if (FileToKeyValues(LastRequestConfig, LRConfig_File))
		{
			IntToString(LR_Current, number, sizeof(number));
			if (KvGotoFirstSubKey(LastRequestConfig))
			{
				decl String:ID[64], String:Name[255];
				do
				{
					KvGetSectionName(LastRequestConfig, ID, sizeof(ID));    
					KvGetString(LastRequestConfig, "Name", Name, sizeof(Name));
					if (StrEqual(ID, number))
					{
						CPrintToChat(client, "%s %s is the current last request queued.", JTAG_COLORED, Name);
					}
				}
				while (KvGotoNextKey(LastRequestConfig));
			}
		}
		CloseHandle(LastRequestConfig);
	}
	else
	{
		CPrintToChat(client, "%s No current last requests queued.", JTAG_COLORED);
	}
	return Plugin_Handled;
}

public Action:ListLRs(client, args)
{
	if (IsVoteInProgress()) return Plugin_Handled;

	new Handle:LRMenu_Handle = CreateMenu(MenuHandle_ListLRs);
	SetMenuTitle(LRMenu_Handle, "Last Requests List");

	ParseLastRequests(client, LRMenu_Handle);

	SetMenuExitButton(LRMenu_Handle, true);
	DisplayMenu(LRMenu_Handle, client, 30 );
	return Plugin_Handled;
}

public MenuHandle_ListLRs(Handle:menu, MenuAction:action, client, item)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			
		}
	case MenuAction_End: CloseHandle(menu);
	}
}

public Action:RemoveLR(client, args)
{
	if (!client)
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!TF2Jail_IsWarden(client))
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
		return Plugin_Handled;
	}
	
	g_bIsLRInUse = false;
	g_IsFreeday[client] = false;
	g_IsFreedayActive[client] = false;
	CPrintToChat(client, "%s %t", JTAG_COLORED, "warden removed lr");
	TF2Jail_Log("Warden %N has cleared all last requests currently queued.", client);

	return Plugin_Handled;
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

LastRequestStart(client, bool:Timer = true)
{
	if (IsVoteInProgress()) return;

	new Handle:LRMenu_Handle = CreateMenu(MenuHandle_LR);
	SetMenuTitle(LRMenu_Handle, "Last Request Menu");

	ParseLastRequests(client, LRMenu_Handle);

	SetMenuExitButton(LRMenu_Handle, true);
	DisplayMenu(LRMenu_Handle, client, 30 );
	
	CPrintToChat(client, "%s %t", JTAG_COLORED, "warden granted lr");
	g_bIsLRInUse = true;
	
	if (!Timer)
	{
		RoundTimer_Stop();
	}
}

public MenuHandle_LR(Handle:menu, MenuAction:action, client, item)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			if (g_bActiveRound)
			{
				new Handle:LastRequestConfig = CreateKeyValues("TF2Jail_LastRequests");
				FileToKeyValues(LastRequestConfig, LRConfig_File);

				if (KvGotoFirstSubKey(LastRequestConfig))
				{
					new String:buffer[255];
					new String:choice[255];
					GetMenuItem(menu, item, choice, sizeof(choice));
					do
					{
						KvGetSectionName(LastRequestConfig, buffer, sizeof(buffer));
						if (StrEqual(buffer, choice))
						{
							decl String:Custom[25];
							KvGetString(LastRequestConfig, "Handler", Custom, sizeof(Custom));
							if (StrEqual(Custom, "LR_Custom"))
							{
								decl String:QueueAnnounce[255], String:ClientName[32];
								if (KvGetString(LastRequestConfig, "Queue_Announce", QueueAnnounce, sizeof(QueueAnnounce)))
								{
									GetClientName(client, ClientName, sizeof(ClientName));
									ReplaceString(QueueAnnounce, sizeof(QueueAnnounce), "%M", ClientName, true);
									Format(QueueAnnounce, sizeof(QueueAnnounce), "%s %s", JTAG_COLORED, QueueAnnounce);
									CPrintToChatAll(QueueAnnounce);
								}
								
								CPrintToChat(client, "%s %t", JTAG_COLORED, "custom last request message");
								CustomClient = client;
							}
							else
							{
								new bool:ActiveRound = false;
								if (KvJumpToKey(LastRequestConfig, "Parameters"))
								{
									if (KvGetNum(LastRequestConfig, "ActiveRound", 0) == 1)
									{
										ActiveRound = true;
									}
									KvGoBack(LastRequestConfig);
								}
								
								if (ActiveRound)
								{
									new String:Handler[64];
									if (KvGetString(LastRequestConfig, "Handler", Handler, sizeof(Handler)))
									{
										Call_StartForward(Forward_OnLastRequestExecute);
										Call_PushString(Handler);
										Call_Finish();
									}
									
									decl String:Active[255], String:ClientName[32];
									if (KvGetString(LastRequestConfig, "Activated", Active, sizeof(Active)))
									{
										GetClientName(client, ClientName, sizeof(ClientName));
										ReplaceString(Active, sizeof(Active), "%M", ClientName, true);
										Format(Active, sizeof(Active), "%s %s", JTAG_COLORED, Active);
										CPrintToChatAll(Active);
									}
									
									new String:ServerCommands[255];
									if (KvGetString(LastRequestConfig, "Execute_Cmd", ServerCommands, sizeof(ServerCommands)))
									{
										if (!StrEqual(ServerCommands, ""))
										{							
											TF2Jail_ServerCommand(ServerCommands);
										}
									}
									
									if (KvJumpToKey(LastRequestConfig, "Parameters"))
									{
										switch (KvGetNum(LastRequestConfig, "IsFreedayType", 0))
										{
										case 1:
											{
												GiveFreeday(client);
											}
										case 2:
											{
												FreedayforClientsMenu(client, true, true);
											}
										case 3:
											{
												FreedayForAll(false);
											}
										}
										
										if (KvGetNum(LastRequestConfig, "IsSuicide", 0) == 1)
										{
											ForcePlayerSuicide(client);
										}
										
										if (KvJumpToKey(LastRequestConfig, "KillWeapons"))
										{
											for (new i = 1; i < MaxClients; i++)
											{
												if (IsValidClient(i) && IsPlayerAlive(i))
												{
													switch (GetClientTeam(i))
													{
													case TFTeam_Red:
														{
															if (KvGetNum(LastRequestConfig, "Red", 0) == 1)
															{
																TF2Jail_StripAllWeapons(i);
															}
														}
													case TFTeam_Blue:
														{
															if (KvGetNum(LastRequestConfig, "Blue", 0) == 1)
															{
																TF2Jail_StripAllWeapons(i);
															}
														}
													}
													
													if (KvGetNum(LastRequestConfig, "Warden", 0) == 1 && TF2Jail_IsWarden(i))
													{
														TF2Jail_StripAllWeapons(i);
													}
												}
											}
											KvGoBack(LastRequestConfig);
										}
										
										if (KvJumpToKey(LastRequestConfig, "FriendlyFire"))
										{
											if (KvGetNum(LastRequestConfig, "Status", 0) == 1)
											{
												new Float:TimeFloat = KvGetFloat(LastRequestConfig, "Timer", 1.0);
												if (TimeFloat >= 0.1)
												{
													TF2Jail_StartFFTimer(TimeFloat);
												}
												else
												{
													TF2Jail_Log("[ERROR] Timer is set to a value below 0.1! Timer could not be created.");
												}
											}
											KvGoBack(LastRequestConfig);
										}
										KvGoBack(LastRequestConfig);
									}
									LR_Current = StringToInt(choice);
								}
								else
								{
									new bool:FreedayCheck = true;
									if (KvJumpToKey(LastRequestConfig, "Parameters"))
									{
										switch (KvGetNum(LastRequestConfig, "IsFreedayType", 0))
										{
										case 1:
											{
												g_IsFreeday[client] = true;
												FreedayCheck = false;
											}
										case 2:
											{
												FreedayforClientsMenu(client, false, true);
												FreedayCheck = false;
											}
										case 3:
											{
												FreedayForAll(true);
											}
										}
										KvGoBack(LastRequestConfig);
									}
									
									decl String:QueueAnnounce[255], String:ClientName[32];
									if (KvGetString(LastRequestConfig, "Queue_Announce", QueueAnnounce, sizeof(QueueAnnounce)))
									{
										GetClientName(client, ClientName, sizeof(ClientName));
										ReplaceString(QueueAnnounce, sizeof(QueueAnnounce), "%M", ClientName, true);
										Format(QueueAnnounce, sizeof(QueueAnnounce), "%s %s", JTAG_COLORED, QueueAnnounce);
										CPrintToChatAll(QueueAnnounce);
									}
									
									if (FreedayCheck)
									{
										LR_Pending = StringToInt(choice);
									}
								}
							}
						}
					}while (KvGotoNextKey(LastRequestConfig));
				}
				CloseHandle(LastRequestConfig);
			}
			
			if (cv_RemoveFreedayOnLR)
			{
				for (new i = 1; i <= MaxClients; i++)
				{
					if (g_IsFreedayActive[i])
					{
						RemoveFreeday(i);
					}
				}
				CPrintToChatAll("%s %t", JTAG_COLORED, "last request freedays removed");
			}
		}
	case MenuAction_Cancel:
		{
			if (g_bActiveRound)
			{
				g_bIsLRInUse = false;
				CPrintToChatAll("%s %t", JTAG_COLORED, "last request closed");
			}
			else
			{
				g_bIsLRInUse = false;
			}
		}
	case MenuAction_End: CloseHandle(menu), g_bIsLRInUse = false;
	}
}

FreedayforClientsMenu(client, bool:active = false, bool:rep = false)
{
	if (IsVoteInProgress()) return;

	if (rep) CPrintToChatAll("%s %t", JTAG_COLORED, "lr freeday picking clients", client);
	
	if (active)
	{
		new Handle:menu1 = CreateMenu(MenuHandle_FreedayForClientsActive, MENU_ACTIONS_ALL);
		SetMenuTitle(menu1, "Choose a Player");
		SetMenuExitBackButton(menu1, false);
		AddTargetsToMenu2(menu1, 0, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY);
		DisplayMenu(menu1, client, MENU_TIME_FOREVER);
	}
	else
	{
		new Handle:menu2 = CreateMenu(MenuHandle_FreedayForClients, MENU_ACTIONS_ALL);
		SetMenuTitle(menu2, "Choose a Player");
		SetMenuExitBackButton(menu2, false);
		AddTargetsToMenu2(menu2, 0, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY);
		DisplayMenu(menu2, client, MENU_TIME_FOREVER);
	}
}

public MenuHandle_FreedayForClientsActive(Handle:menu2, MenuAction:action, client, item)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu2, item, info, sizeof(info));
			
			new target = GetClientOfUserId(StringToInt(info));
			
			if (IsValidClient(client))
			{
				if (!IsValidClient(target))
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "Player no longer available");
					FreedayforClientsMenu(client, true);
				}
				else if (g_IsFreedayActive[target])
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "freeday currently queued", target);
					FreedayforClientsMenu(client, true);
				}
				else
				{
					if (FreedayLimit < cv_FreedayLimit)
					{
						GiveFreeday(client);
						FreedayLimit++;
						CPrintToChatAll("%s %t", JTAG_COLORED, "lr freeday picked clients", client, target);
						FreedayforClientsMenu(client, true);
					}
					else
					{
						CPrintToChatAll("%s %t", JTAG_COLORED, "lr freeday picked clients maxed", client);
					}
				}
			}
		}
	case MenuAction_Cancel:
		{
			LastRequestStart(client);
		}
	case MenuAction_End: CloseHandle(menu2);
	}
}

public MenuHandle_FreedayForClients(Handle:menu2, MenuAction:action, client, item)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu2, item, info, sizeof(info));
			
			new target = GetClientOfUserId(StringToInt(info));
			
			if (IsValidClient(client) && !IsClientInKickQueue(client))
			{
				if (target == 0)
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "Player no longer available");
					FreedayforClientsMenu(client);
				}
				else if (g_IsFreeday[target])
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "freeday currently queued", target);
					FreedayforClientsMenu(client);
				}
				else
				{
					if (FreedayLimit < cv_FreedayLimit)
					{
						g_IsFreeday[target] = true;
						FreedayLimit++;
						CPrintToChatAll("%s %t", JTAG_COLORED, "lr freeday picked clients", client, target);
						FreedayforClientsMenu(client);
					}
					else
					{
						CPrintToChatAll("%s %t", JTAG_COLORED, "lr freeday picked clients maxed", client);
					}
				}
			}
		}
	case MenuAction_Cancel:
		{
			LastRequestStart(client);
		}
	case MenuAction_End: CloseHandle(menu2);
	}
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

GiveFreeday(client)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	CPrintToChat(client, "%s %t", JTAG_COLORED, "lr freeday message");
	new flags = GetEntityFlags(client)|FL_NOTARGET;
	SetEntityFlags(client, flags);
	ServerCommand("sm_evilbeam #%d", GetClientUserId(client));
	if (cv_FreedayTeleports && g_bFreedayTeleportSet) TeleportEntity(client, free_pos, NULL_VECTOR, NULL_VECTOR);
	
	ClearTimer(hTimer_ParticleTimer[client]);
	hTimer_ParticleTimer[client] = CreateTimer(2.0, Timer_FreedayParticle, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	g_IsFreeday[client] = false;
	g_IsFreedayActive[client] = true;
	TF2Jail_Log("%N has been given a Freeday.", client);
}

FreedayForAll(bool:active = false)
{
	if (active)
	{
		TF2Jail_ControlDoors(OPEN);
	}
	else
	{
		
	}
}

RemoveFreeday(client)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 2);
	CPrintToChatAll("%s %t", JTAG_COLORED, "lr freeday lost", client);
	PrintCenterTextAll("%t", "lr freeday lost center", client);
	new flags = GetEntityFlags(client)&~FL_NOTARGET;
	SetEntityFlags(client, flags);
	ServerCommand("sm_evilbeam #%d", GetClientUserId(client));
	g_IsFreedayActive[client] = false;
	ClearTimer(hTimer_ParticleTimer[client]);
	TF2Jail_Log("%N is no longer a Freeday.", client);
}

ParseLastRequests(client, Handle:menu)
{
	new Handle:LastRequestConfig = CreateKeyValues("TF2Jail_LastRequests");
	
	if (FileToKeyValues(LastRequestConfig, LRConfig_File))
	{
		if (KvGotoFirstSubKey(LastRequestConfig))
		{
			decl String:LR_ID[64];
			decl String:LR_NAME[255];
			do
			{
				KvGetSectionName(LastRequestConfig, LR_ID, sizeof(LR_ID));    
				KvGetString(LastRequestConfig, "Name", LR_NAME, sizeof(LR_NAME));
				
				if (KvJumpToKey(LastRequestConfig, "Parameters"))
				{
					new bool:VIPCheck = false;
					if (KvGetNum(LastRequestConfig, "IsVIPOnly", 0) == 1)
					{
						VIPCheck = true;
						Format(LR_NAME, sizeof(LR_NAME), "%s [VIP Only]", LR_NAME);
					}
					
					switch (KvGetNum(LastRequestConfig, "Disabled", 0))
					{
					case 0:
					{
						if (VIPCheck)
						{
							if (TF2Jail_IsVIP(client))
							{
								AddMenuItem(menu, LR_ID, LR_NAME);
							}
							else
							{
								AddMenuItem(menu, LR_ID, LR_NAME, ITEMDRAW_DISABLED);
							}
						}
						else
						{
							AddMenuItem(menu, LR_ID, LR_NAME);
						}
					}
					case 1:	AddMenuItem(menu, LR_ID, LR_NAME, ITEMDRAW_DISABLED);
					}
					KvGoBack(LastRequestConfig);
				}
			}
			while (KvGotoNextKey(LastRequestConfig));
			g_bLRConfigActive = true;
		}
	}
	else
	{
		g_bLRConfigActive = false;
	}
	CloseHandle(LastRequestConfig);
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

public Action:Timer_FreedayParticle(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		CreateParticle(Particle_Freeday, 3.0, client, ATTACH_NORMAL);
	}
	else
	{
		ClearTimer(hTimer_ParticleTimer[client]);
	}
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

public bool:FreedaysGroup(const String:strPattern[], Handle:hClients)
{
	for (new i = 1; i <= MaxClients; i ++)
	{
		if (IsValidClient(i) && g_IsFreeday[i] || IsValidClient(i) && g_IsFreedayActive[i])
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

public bool:NotFreedaysGroup(const String:strPattern[], Handle:hClients)
{
	for (new i = 1; i <= MaxClients; i ++)
	{
		if (IsValidClient(i) && !g_IsFreeday[i] || IsValidClient(i) && !g_IsFreedayActive[i])
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

public Native_IsFreeday(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (g_IsFreeday[client] || g_IsFreedayActive[client])
	{
		return true;
	}
	else
	{
		return false;
	}
}

public Native_GiveFreeday(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (g_IsFreedayActive[client])
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is already a Freeday.", client);
	}
	else
	{
		if (g_IsFreeday[client])
		{
			g_IsFreeday[client] = false;
		}
		GiveFreeday(client);
	}
}

public Native_IsLRRound(Handle:plugin, numParams)
{
	if (LR_Current != -1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

//Callbacks
public Native_LockWardenLR(Handle:plugin, numParams)
{
	return cv_LRSLockWarden;
}

public Native_SetFreedayPos(Handle:plugin, numParams)
{
	g_bFreedayTeleportSet = GetNativeCell(1);
	free_pos[0] = Float:GetNativeCell(2);
	free_pos[1] = Float:GetNativeCell(3);
	free_pos[2] = Float:GetNativeCell(4);
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/