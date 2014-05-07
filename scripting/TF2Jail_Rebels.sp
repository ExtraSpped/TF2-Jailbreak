#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <tf2_stocks>
#include <morecolors>
#include <smlib>
#include <jackofdesigns>
#include <autoexecconfig>

//TF2Jail Includes
#include <tf2jail>

#define PLUGIN_NAME     "[TF2] TF2Jail - Rebels System"
#define PLUGIN_AUTHOR   "Keith Warren(Jack of Designs)"
#define PLUGIN_DESCRIPTION	"Forces prisoners to become rebels when/if they attack guards."
#define PLUGIN_CONTACT  "http://www.jackofdesigns.com/"

new Handle:JB_ConVars[4] = {INVALID_HANDLE, ...};

new bool:cv_Rebels = true, Float:cv_RebelsTime = 30.0, String:Particle_Rebellion[100];

new bool:g_IsRebel[MAXPLAYERS + 1];

new Handle:hTimer_RebelTimers[MAXPLAYERS+1];
new Handle:hTimer_ParticleTimer[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

public OnPluginStart()
{
	File_LoadTranslations("common.phrases");
	File_LoadTranslations("TF2Jail.phrases");
	
	AutoExecConfig_SetFile("TF2Jail");
	
	JB_ConVars[0] = AutoExecConfig_CreateConVar("tf2jail_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD);
	JB_ConVars[1] = AutoExecConfig_CreateConVar("sm_tf2jail_rebelling_enable", "1", "Enable the Rebel system: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[2] = AutoExecConfig_CreateConVar("sm_tf2jail_rebelling_time", "30.0", "Rebel timer: (1.0 - 60.0, 0 = always)", FCVAR_PLUGIN, true, 1.0, true, 60.0);
	JB_ConVars[3] = AutoExecConfig_CreateConVar("sm_tf2jail_particle_rebellion", "medic_radiusheal_red_volume", "Name of the Particle for Rebellion (0 = Disabled)", FCVAR_PLUGIN);
	
	AutoExecConfig_ExecuteFile();
	
	for (new i = 0; i < sizeof(JB_ConVars); i++)
	{
		HookConVarChange(JB_ConVars[i], HandleCvars);
	}
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_hurt", PlayerHurt);
	HookEvent("teamplay_round_win", RoundEnd);

	AddMultiTargetFilter("@rebels", RebelsGroup, "All Rebels.", false);
	AddMultiTargetFilter("@!rebels", NotRebelsGroup, "All but the Rebels.", false);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		Format(error, err_max, "This plugin only works for Team Fortress 2");
		return APLRes_Failure;
	}
	
	CreateNative("TF2Jail_IsRebel", Native_IsRebel);
	CreateNative("TF2Jail_MarkRebel", Native_MarkRebel);
	
	RegPluginLibrary("tf2jail");

	return APLRes_Success;
}

public OnConfigsExecuted()
{
	cv_Rebels = GetConVarBool(JB_ConVars[1]);
	cv_RebelsTime = GetConVarFloat(JB_ConVars[2]);
	GetConVarString(JB_ConVars[3], Particle_Rebellion, sizeof(Particle_Rebellion));
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
		cv_Rebels = bool:iNewValue;
		if (iNewValue == 0)
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && g_IsRebel[i])
				{
					g_IsRebel[i] = false;
				}
			}
		}
	}
	else if (cvar == JB_ConVars[2])
	{
		cv_RebelsTime = StringToFloat(newValue);
	}
	else if (cvar == JB_ConVars[3])
	{
		GetConVarString(JB_ConVars[3], Particle_Rebellion, sizeof(Particle_Rebellion));
	}
}

public OnMapEnd()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			hTimer_RebelTimers[i] = INVALID_HANDLE;
		}
	}
}

public OnClientDisconnect(client)
{
	if (IsValidClient(client))
	{
		g_IsRebel[client] = false;
	}
}

public PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		g_IsRebel[client] = false;
	}
}

public PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!cv_Rebels) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new client_attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (IsValidClient(client) && IsValidClient(client_attacker))
	{
		if (client_attacker != client)
		{
			if (GetClientTeam(client_attacker) == _:TFTeam_Red && GetClientTeam(client) == _:TFTeam_Blue && !g_IsRebel[client_attacker])
			{
				MarkRebel(client_attacker);
			}
		}
	}
}

public RoundEnd(Handle:hEvent, const String:strName[], bool:bBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			hTimer_RebelTimers[i] = INVALID_HANDLE;
		}
	}
}

MarkRebel(client)
{
	g_IsRebel[client] = true;
	
	ClearTimer(hTimer_ParticleTimer[client]);
	hTimer_ParticleTimer[client] = CreateTimer(2.0, Timer_RebelParticle, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	CPrintToChatAll("%s %t", JTAG_COLORED, "prisoner has rebelled", client);
	if (cv_RebelsTime >= 1.0)
	{
		new time = RoundFloat(cv_RebelsTime);
		CPrintToChat(client, "%s %t", JTAG_COLORED, "rebel timer start", time);
		hTimer_RebelTimers[client] = CreateTimer(cv_RebelsTime, RemoveRebel, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	TF2Jail_Log("%N has been marked as a Rebeller.", client);
}

public Action:Timer_RebelParticle(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		CreateParticle(Particle_Rebellion, 3.0, client, ATTACH_NORMAL);
	}
	else
	{
		ClearTimer(hTimer_ParticleTimer[client]);
	}
}

public Action:RemoveRebel(Handle:hTimer, any:userid)
{
	new client = GetClientOfUserId(userid);
	hTimer_RebelTimers[client] = INVALID_HANDLE;
	
	if (IsValidClient(client) && GetClientTeam(client) != 1 && IsPlayerAlive(client))
	{
		g_IsRebel[client] = false;
		CPrintToChat(client, "%s %t", JTAG_COLORED, "rebel timer end");
		ClearTimer(hTimer_ParticleTimer[client]);
		TF2Jail_Log("%N is no longer a Rebeller.", client);
	}
}

public bool:RebelsGroup(const String:strPattern[], Handle:hClients)
{
	for (new i = 1; i <= MaxClients; i ++)
	{
		if (IsValidClient(i) && g_IsRebel[i])
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

public bool:NotRebelsGroup(const String:strPattern[], Handle:hClients)
{
	for (new i = 1; i <= MaxClients; i ++)
	{
		if (IsValidClient(i) && !g_IsRebel[i])
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

public Native_IsRebel(Handle:plugin, numParams)
{
	if (!cv_Rebels)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Rebel System is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (g_IsRebel[client])
	{
		return true;
	}
	else
	{
		return false;
	}
}

public Native_MarkRebel(Handle:plugin, numParams)
{
	if (!cv_Rebels)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Rebel System is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (!g_IsRebel[client])
	{
		MarkRebel(client);
	}
	else
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is already a Rebel.", client);
	}
}