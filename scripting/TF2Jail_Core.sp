/*
	**
	* =============================================================================
	* TF2 Jailbreak Plugin Set (TF2Jail)
	*
	* Created and developed by Keith Warren (Jack of Designs).
	* =============================================================================
	*
	* This program is free software: you can redistribute it and/or modify
	* it under the terms of the GNU General Public License as published by
	* the Free Software Foundation, either version 3 of the License, or
	* (at your option) any later version.
	*
	* This program is distributed in the hope that it will be useful,
	* but WITHOUT ANY WARRANTY; without even the implied warranty of
	* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	* GNU General Public License for more details.
	*
	* You should have received a copy of the GNU General Public License
	* along with this program. If not, see <http://www.gnu.org/licenses/>.
	*
	**
*/

#pragma semicolon 1

//Required Includes
#include <sourcemod>
#include <adminmenu>
#include <tf2_stocks>
#include <morecolors>
#include <smlib>
#include <autoexecconfig>
#include <jackofdesigns>

//TF2Jail Include
#include <tf2jail/tf2jail_core>

#undef REQUIRE_EXTENSIONS
#tryinclude <sdkhooks>
#tryinclude <steamtools>
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#tryinclude <tf2jail/tf2jail_lastrequests>
#tryinclude <tf2jail/tf2jail_rebels>
#tryinclude <sourcebans>
#tryinclude <sourcecomms>
#tryinclude <basecomm>
#tryinclude <clientprefs>
#tryinclude <voiceannounce_ex>
#tryinclude <roundtimer>
//#tryinclude <updater>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME	"[TF2] Jailbreak - Core"
#define PLUGIN_AUTHOR	"Keith Warren(Jack of Designs)"
#define PLUGIN_DESCRIPTION	"Jailbreak for Team Fortress 2. The core of all the modules!"
#define PLUGIN_CONTACT	"http://www.jackofdesigns.com/"
#define WARDEN_MODEL	"models/jailbreak/warden/warden_v2"

#if defined _updater_included
#define UPDATE_URL         "https://raw.github.com/JackofDesigns/TF2-Jailbreak/Beta/updater.txt"
#endif

//ConVar Handles, Globals, etc..
new Handle:JB_ConVars[55] = {INVALID_HANDLE, ...};
new bool:cv_Enabled = true, bool:cv_Advertise = true, bool:cv_Cvars = true, cv_Logging = 2, bool:cv_Balance = true, Float:cv_BalanceRatio = 0.5,
bool:cv_RedMelee = true, bool:cv_Warden = false, bool:cv_WardenAuto = false, bool:cv_WardenModel = true, bool:cv_WardenForceSoldier = true,
bool:cv_WardenFF = true, bool:cv_WardenCC = true, bool:cv_WardenRequest = true, cv_WardenLimit = 0, bool:cv_DoorControl = true, Float:cv_DoorOpenTimer = 60.0,
cv_RedMute = 2, Float:cv_RedMuteTime = 15.0, cv_BlueMute = 2, bool:cv_DeadMute = true, bool:cv_MicCheck = true, bool:cv_MicCheckType = true,
cv_Criticals = 1, cv_Criticalstype = 2, Float:cv_WVotesNeeded = 0.60, cv_WVotesMinPlayers = 0, cv_WVotesPostAction = 0, cv_WVotesPassedLimit = 3,
bool:cv_Freekillers = true, Float:cv_FreekillersTime = 6.0, cv_FreekillersKills = 6, Float:cv_FreekillersWave = 60.0, cv_FreekillersAction = 2, String:BanMsg[255],
String:BanMsgDC[255], cv_FreekillersBantime = 60, cv_FreekillersBantimeDC = 120, bool:cv_1stDayFreeday = true, bool:cv_DemoCharge = true,
bool:cv_DoubleJump = true, bool:cv_Airblast = true, String:Particle_Freekiller[100], cv_WardenVoice = 1, bool:cv_WardenWearables = true,
cv_WardenStabProtection = 0,bool:cv_KillPointServerCommand = true, bool:cv_PrefStatus = false, cv_WardenTimer = 20, bool:cv_AdminFlags = false,
bool:cv_PrefBlue = false, bool:cv_PrefWarden = false, bool:cv_ConsoleSpew = false, cv_BuildingsManage;

//Plugins/Extension bools
new bool:e_voiceannounce_ex = false, bool:e_sourcebans = false, bool:e_steamtools = false,
bool:e_clientprefs = false, bool:e_tf2jail_lastrequests = false, bool:e_tf2jail_rebels;

//Global Bools
new bool:g_IsMapCompatible = false, bool:g_CellsOpened = false, bool:g_1stRoundFreeday = false, bool:g_VoidFreekills = false,
bool:g_bIsWardenLocked = false, bool:g_bOneGuardLeft = false, bool:g_bActiveRound = false,
bool:g_bLateLoad = false, bool:g_bAdminLockWarden = false;

//Player Array Bools
new bool:g_ScoutsBlockedDoubleJump[MAXPLAYERS+1], bool:g_PyrosDisableAirblast[MAXPLAYERS+1], bool:g_IsMuted[MAXPLAYERS+1], 
bool:g_IsFreekiller[MAXPLAYERS + 1], bool:g_HasTalked[MAXPLAYERS+1], bool:g_LockedFromWarden[MAXPLAYERS+1],
bool:g_bRolePreference_Blue[MAXPLAYERS+1], bool:g_bRolePreference_Warden[MAXPLAYERS+1], bool:g_HasModel[MAXPLAYERS+1],
bool:g_Voted[MAXPLAYERS+1] = {false, ...};

//Global Integers
new Warden = -1, g_Voters = 0, g_Votes = 0,
g_VotesNeeded = 0, g_VotesPassed = 0, WardenLimit = 0;

//Player Array Integers
new g_FirstKill[MAXPLAYERS + 1], g_Killcount[MAXPLAYERS + 1], g_HasBeenWarden[MAXPLAYERS + 1];

//Global Strings
new String:GCellNames[32], String:GCellOpener[32], String:DoorList[][] = {"func_door", "func_door_rotating", "func_movelinear"};

//Native Forward Handles
new Handle:Forward_WardenCreated,Handle:Forward_WardenRemoved;

//Global Handles
new Handle:WardenName, Handle:g_hRolePref_Blue,
Handle:g_hRolePref_Warden, Handle:JB_HudHandler;

//Engine ConVar Handles
new Handle:JB_EngineConVars[3] = {INVALID_HANDLE, ...};

//Timer Handles
new Handle:hTimer_Advertisement, Handle:hTimer_FreekillingData, Handle:hTimer_OpenCells,
Handle:hTimer_FriendlyFireEnable, Handle:hTimer_WardenLock;

//Player Array Handles
new Handle:hTimer_ParticleTimers[MAXPLAYERS+1];

//Enumeration Structures
enum WardenMenuAccept
{
	Open = 0,
	FriendlyFire,
	Collision
};

enum CommsList
{
	None = 0,
	Basecomms,
	Sourcecomms
};

new CommsList:EnumCommsList;
new WardenMenuAccept:EnumWardenMenu;

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
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
	Jail_Log("%s Jailbreak is now loading...", JTAG);
	File_LoadTranslations("common.phrases");
	File_LoadTranslations("TF2Jail.phrases");
	
	AutoExecConfig_SetFile("TF2Jail");

	JB_ConVars[0] = AutoExecConfig_CreateConVar("tf2jail_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD);
	JB_ConVars[1] = AutoExecConfig_CreateConVar("sm_tf2jail_enable", "1", "Status of the plugin: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[2] = AutoExecConfig_CreateConVar("sm_tf2jail_advertisement", "1", "Display plugin creator advertisement: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[3] = AutoExecConfig_CreateConVar("sm_tf2jail_set_variables", "1", "Set default cvars: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[4] = AutoExecConfig_CreateConVar("sm_tf2jail_logging", "2", "Status and the type of logging: (0 = disabled, 1 = regular logging, 2 = logging to TF2Jail logs.)", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	JB_ConVars[5] = AutoExecConfig_CreateConVar("sm_tf2jail_auto_balance", "1", "Should the plugin autobalance teams: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[6] = AutoExecConfig_CreateConVar("sm_tf2jail_balance_ratio", "0.5", "Ratio for autobalance: (Example: 0.5 = 2:4)", FCVAR_PLUGIN, true, 0.1, true, 1.0);
	JB_ConVars[7] = AutoExecConfig_CreateConVar("sm_tf2jail_melee", "1", "Strip Red Team of weapons: (1 = strip weapons, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[8] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_enable", "1", "Allow Wardens: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[9] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_auto", "1", "Automatically assign a random Wardens on round start: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[10] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_model", "1", "Does Wardens have a model: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[11] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_forcesoldier", "1", "Force Wardens to be Soldier class: (1 = yes, 0 = no)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[12] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_friendlyfire", "1", "Allow Wardens to manage friendly fire: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[13] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_collision", "1", "Allow Wardens to manage collision: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[14] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_request", "0", "Require admin acceptance for cvar changes: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[15] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_limit", "3", "Number of allowed Wardens per user per map: (1.0 - 12.0) (0.0 = unlimited)", FCVAR_PLUGIN, true, 0.0, true, 12.0);
	JB_ConVars[16] = AutoExecConfig_CreateConVar("sm_tf2jail_door_controls", "1", "Allow Wardens and Admins door control: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[17] = AutoExecConfig_CreateConVar("sm_tf2jail_cell_timer", "60", "Time after Arena round start to open doors: (1.0 - 60.0) (0.0 = off)", FCVAR_PLUGIN, true, 0.0, true, 60.0);
	JB_ConVars[18] = AutoExecConfig_CreateConVar("sm_tf2jail_mute_red", "2", "Mute Red team: (2 = mute prisoners alive and all dead, 1 = mute prisoners on round start based on redmute_time, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	JB_ConVars[19] = AutoExecConfig_CreateConVar("sm_tf2jail_mute_red_time", "15", "Mute time for redmute: (1.0 - 60.0)", FCVAR_PLUGIN, true, 1.0, true, 60.0);
	JB_ConVars[20] = AutoExecConfig_CreateConVar("sm_tf2jail_mute_blue", "2", "Mute Blue players: (2 = always except Wardens, 1 = while Wardens is active, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	JB_ConVars[21] = AutoExecConfig_CreateConVar("sm_tf2jail_mute_dead", "1", "Mute Dead players: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[22] = AutoExecConfig_CreateConVar("sm_tf2jail_microphonecheck_enable", "1", "Check blue clients for microphone: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[23] = AutoExecConfig_CreateConVar("sm_tf2jail_microphonecheck_type", "1", "Block blue team or Wardens if no microphone: (1 = Blue, 0 = Wardens only)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[24] = AutoExecConfig_CreateConVar("sm_tf2jail_criticals", "1", "Which team gets crits: (0 = off, 1 = blue, 2 = red, 3 = both)", FCVAR_PLUGIN, true, 0.0, true, 3.0);
	JB_ConVars[25] = AutoExecConfig_CreateConVar("sm_tf2jail_criticals_type", "2", "Type of crits given: (1 = mini, 2 = full)", FCVAR_PLUGIN, true, 1.0, true, 2.0);
	JB_ConVars[26] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_veto_votesneeded", "0.60", "Percentage of players required for fire Wardens vote: (default 0.60 - 60%) (0.05 - 1.0)", 0, true, 0.05, true, 1.00);
	JB_ConVars[27] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_veto_minplayers", "0", "Minimum amount of players required for fire Wardens vote: (0 - MaxPlayers)", 0, true, 0.0, true, float(MAXPLAYERS));
	JB_ConVars[28] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_veto_postaction", "0", "Fire Wardens instantly on vote success or next round: (0 = instant, 1 = Next round)", _, true, 0.0, true, 1.0);
	JB_ConVars[29] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_veto_passlimit", "3", "Limit to Wardens fired by players via votes: (1 - 10, 0 = unlimited)", FCVAR_PLUGIN, true, 0.0, true, 10.0);
	JB_ConVars[30] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_enable", "1", "Enable the Freekill system: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[31] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_seconds", "6.0", "Time in seconds minimum for freekill flag on mark: (1.0 - 60.0)", FCVAR_PLUGIN, true, 1.0, true, 60.0);
	JB_ConVars[32] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_kills", "6", "Number of kills required to flag for freekilling: (1.0 - MaxPlayers)", FCVAR_PLUGIN, true, 1.0, true, float(MAXPLAYERS));
	JB_ConVars[33] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_wave", "60.0", "Time in seconds until client is banned for being marked: (1.0 - 60.0)", FCVAR_PLUGIN, true, 1.0, true, 60.0);
	JB_ConVars[34] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_action", "2", "Action towards marked freekiller: (2 = Ban client based on cvars, 1 = Slay the client, 0 = remove mark on timer)", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	JB_ConVars[35] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_ban_reason", "You have been banned for freekilling.", "Message to give the client if they're marked as a freekiller and banned.", FCVAR_PLUGIN);
	JB_ConVars[36] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_ban_reason_dc", "You have been banned for freekilling and disconnecting.", "Message to give the client if they're marked as a freekiller/disconnected and banned.", FCVAR_PLUGIN);
	JB_ConVars[37] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_duration", "60", "Time banned after timer ends: (0 = permanent)", FCVAR_PLUGIN, true, 0.0);
	JB_ConVars[38] = AutoExecConfig_CreateConVar("sm_tf2jail_freekilling_duration_dc", "120", "Time banned if disconnected after timer ends: (0 = permanent)", FCVAR_PLUGIN, true, 0.0);
	JB_ConVars[39] = AutoExecConfig_CreateConVar("sm_tf2jail_1stdayfreeday", "1", "Status of the 1st day freeday: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[40] = AutoExecConfig_CreateConVar("sm_tf2jail_democharge", "1", "Allow demomen to charge: (1 = enable, 0 = disable)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[41] = AutoExecConfig_CreateConVar("sm_tf2jail_doublejump", "1", "Deny scouts to double jump: (1 = enable, 0 = disable)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[42] = AutoExecConfig_CreateConVar("sm_tf2jail_airblast", "1", "Deny pyros to airblast: (1 = enable, 0 = disable)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[43] = AutoExecConfig_CreateConVar("sm_tf2jail_particle_freekiller", "ghost_firepit", "Name of the Particle for Freekillers (0 = Disabled)", FCVAR_PLUGIN);
	JB_ConVars[44] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_voice", "1", "Voice management for Wardens: (0 = disabled, 1 = unmute, 2 = warning)", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	JB_ConVars[45] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_wearables", "1", "Strip Wardens wearables: (1 = enable, 0 = disable)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[46] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_stabprotection", "1", "Give Wardens backstab protection: (2 = Always, 1 = Once, 0 = Disabled)", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	JB_ConVars[47] = AutoExecConfig_CreateConVar("sm_tf2jail_point_servercommand", "1", "Kill 'point_servercommand' entities: (1 = Kill on Spawn, 0 = Disable)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[48] = AutoExecConfig_CreateConVar("sm_tf2jail_preference_enable", "0", "Allow clients to choose their preferred teams/roles: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[49] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_timer", "20", "Time in seconds after Warden is unset or lost to lock Warden: (0 = Disabled, NON-FLOAT VALUE)", FCVAR_PLUGIN);
	JB_ConVars[50] = AutoExecConfig_CreateConVar("sm_tf2jail_warden_flags", "0", "Lock Warden to a command access flag: (1 = enable, 0 = disable) (Command Access: TF2Jail_WardenOverride)", FCVAR_PLUGIN);
	JB_ConVars[51] = AutoExecConfig_CreateConVar("sm_tf2jail_preference_blue", "0", "Enable the preference for Blue if preferences are enabled: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[52] = AutoExecConfig_CreateConVar("sm_tf2jail_preference_warden", "0", "Enable the preference for Blue if preferences are enabled: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[53] = AutoExecConfig_CreateConVar("sm_tf2jail_console_prints_status", "1", "Enable console messages and information: (1 = on, 0 = off)", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	JB_ConVars[54] = AutoExecConfig_CreateConVar("sm_tf2jail_buildings_manage", "1", "Allow Engineers to build on the following teams: (0 = None, 1 = Blue, 2 = Red, 3 = Both)", FCVAR_PLUGIN, true, 0.0, true, 3.0);
	
	AutoExecConfig_ExecuteFile();
	
	for (new i = 0; i < sizeof(JB_ConVars); i++)
	{
		HookConVarChange(JB_ConVars[i], HandleCvars);
	}
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("teamplay_round_start", RoundStart);
	HookEvent("arena_round_start", ArenaRoundStart);
	HookEvent("teamplay_round_win", RoundEnd);
	HookEvent("post_inventory_application", RegeneratePlayer);
	AddCommandListener(InterceptBuild, "build");

	RegConsoleCmd("sm_fire", Command_FireWarden);
	RegConsoleCmd("sm_firewarden", Command_FireWarden);
	RegConsoleCmd("sm_w", BecomeWarden);
	RegConsoleCmd("sm_warden", BecomeWarden);
	RegConsoleCmd("sm_uw", ExitWarden);
	RegConsoleCmd("sm_unwarden", ExitWarden);
	RegConsoleCmd("sm_wmenu", WardenMenuC);
	RegConsoleCmd("sm_wardenmenu", WardenMenuC);
	RegConsoleCmd("sm_open", OnOpenCommand);
	RegConsoleCmd("sm_close", OnCloseCommand);
	RegConsoleCmd("sm_wff", WardenFriendlyFire);
	RegConsoleCmd("sm_wcc", WardenCollision);
	RegConsoleCmd("sm_cw", CurrentWarden);
	RegConsoleCmd("sm_currentwarden", CurrentWarden);

	RegAdminCmd("sm_rw", AdminRemoveWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_removewarden", AdminRemoveWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_pardon", AdminPardonFreekiller, ADMFLAG_GENERIC);
	RegAdminCmd("sm_opencells", AdminOpenCells, ADMFLAG_GENERIC);
	RegAdminCmd("sm_closecells", AdminCloseCells, ADMFLAG_GENERIC);
	RegAdminCmd("sm_lockcells", AdminLockCells, ADMFLAG_GENERIC);
	RegAdminCmd("sm_unlockcells", AdminUnlockCells, ADMFLAG_GENERIC);
	RegAdminCmd("sm_forcewarden", AdminForceWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_jailreset", AdminResetPlugin, ADMFLAG_GENERIC);
	RegAdminCmd("sm_compatible", AdminMapCompatibilityCheck, ADMFLAG_GENERIC);
	RegAdminCmd("sm_allow", AdminAcceptWardenChange, ADMFLAG_GENERIC);
	RegAdminCmd("sm_cancel", AdminCancelWardenChange, ADMFLAG_GENERIC);
	RegAdminCmd("sm_debugging", AdminDebugging, ADMFLAG_GENERIC);
	RegAdminCmd("sm_lw", LockWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_lockwarden", LockWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_ulw", UnlockWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_unlockwarden", UnlockWarden, ADMFLAG_GENERIC);
	
	JB_EngineConVars[0] = FindConVar("mp_friendlyfire");
	JB_EngineConVars[1] = FindConVar("tf_avoidteammates_pushaway");
	JB_EngineConVars[2] = FindConVar("sv_gravity");
	
	WardenName = CreateHudSynchronizer();
	
	AddMultiTargetFilter("@warden", WardenGroup, "The Warden.", false);
	AddMultiTargetFilter("@!warden", NotWardenGroup, "All but the Warden.", false);
		
	AutoExecConfig_CleanFile();
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		Format(error, err_max, "This plugin only works for Team Fortress 2");
		return APLRes_Failure;
	}
	
	MarkNativeAsOptional("Steam_SetGameDescription");
	
	CreateNative("TF2Jail_WardenActive", Native_ExistWarden);
	CreateNative("TF2Jail_IsWarden", Native_IsWarden);
	CreateNative("TF2Jail_WardenSet", Native_SetWarden);
	CreateNative("TF2Jail_WardenUnset", Native_RemoveWarden);
	CreateNative("TF2Jail_IsFreekiller", Native_IsFreekiller);
	CreateNative("TF2Jail_MarkFreekiller", Native_MarkFreekill);
	CreateNative("TF2Jail_StripToMelee", Native_StripToMelee);
	CreateNative("TF2Jail_StripAllWeapons", Native_StripAllWeapons);
	CreateNative("TF2Jail_LockWarden", Native_LockWarden);
	CreateNative("TF2Jail_UnlockWarden", Native_UnlockWarden);
	CreateNative("TF2Jail_Log", Native_Logging);
	CreateNative("TF2Jail_IsVIP", Native_IsVIP);
	CreateNative("TF2Jail_ServerCommand", Native_ServerCommand);
	CreateNative("TF2Jail_ControlDoors", Native_ControlDoors);
	CreateNative("TF2Jail_VoidFreekills", Native_VoidFreekills);
	CreateNative("TF2Jail_StartFFTimer", Native_StartFFTimer);
	CreateNative("TF2Jail_GetWarden", Native_GetWarden);
	
	Forward_WardenCreated = CreateGlobalForward("Warden_OnWardenCreated", ET_Ignore, Param_Cell);
	Forward_WardenRemoved = CreateGlobalForward("Warden_OnWardenRemoved", ET_Ignore, Param_Cell);
	
	RegPluginLibrary("tf2jail");

	g_bLateLoad = late;
	return APLRes_Success;
}

public OnAllPluginsLoaded()
{
	e_steamtools = LibraryExists("SteamTools");
	e_voiceannounce_ex = LibraryExists("voiceannounce_ex");
	e_sourcebans = LibraryExists("sourcebans");
	e_clientprefs = LibraryExists("clientprefs");
	e_tf2jail_lastrequests = LibraryExists("TF2Jail_LastRequests");
	
	if (LibraryExists("sourcecomms"))
	{
		EnumCommsList = Sourcecomms;
	}
	else if (LibraryExists("basecomm"))
	{
		EnumCommsList = Basecomms;
	}
	else
	{
		EnumCommsList = None;
	}
	
	#if defined _updater_included
	if (LibraryExists("updater")) Updater_AddPlugin(UPDATE_URL);
	#endif
	
	#if defined _jackofdesigns_included
	Jack_OnAllPluginsLoaded();
	#endif
}

public OnLibraryAdded(const String:name[])
{
	e_steamtools = StrEqual(name, "SteamTools", false);
	e_sourcebans = StrEqual(name, "sourcebans");
	e_voiceannounce_ex = StrEqual(name, "voiceannounce_ex");
	e_clientprefs = StrEqual(name, "clientprefs");
	e_tf2jail_lastrequests = StrEqual(name, "TF2Jail_LastRequests");

	if (StrEqual(name, "sourcecomms"))
	{
		EnumCommsList = Sourcecomms;
	}
	else if (StrEqual(name, "basecomm"))
	{
		EnumCommsList = Basecomms;
	}
	
	#if defined _jackofdesigns_included
	Jack_OnLibraryAdded(name);
	#endif
}

public OnLibraryRemoved(const String:name[])
{
	e_steamtools = StrEqual(name, "SteamTools", false);
	e_sourcebans = StrEqual(name, "sourcebans");
	e_voiceannounce_ex = StrEqual(name, "voiceannounce_ex");
	e_clientprefs = StrEqual(name, "clientprefs");
	e_tf2jail_lastrequests = StrEqual(name, "TF2Jail_LastRequests");
	
	if (StrEqual(name, "sourcecomms") || StrEqual(name, "basecomm"))
	{
		EnumCommsList = None;
	}
	
	#if defined _jackofdesigns_included
	Jack_OnLibraryRemoved(name);
	#endif
}

public OnPluginEnd()
{
	OnMapEnd();
}

public OnConfigsExecuted()
{
	cv_Enabled = GetConVarBool(JB_ConVars[1]);
	cv_Advertise = GetConVarBool(JB_ConVars[2]);
	cv_Cvars = GetConVarBool(JB_ConVars[3]);
	cv_Logging = GetConVarInt(JB_ConVars[4]);
	cv_Balance = GetConVarBool(JB_ConVars[5]);
	cv_BalanceRatio = GetConVarFloat(JB_ConVars[6]);
	cv_RedMelee = GetConVarBool(JB_ConVars[7]);
	cv_Warden = GetConVarBool(JB_ConVars[8]);
	cv_WardenAuto = GetConVarBool(JB_ConVars[9]);
	cv_WardenModel = GetConVarBool(JB_ConVars[10]);
	cv_WardenForceSoldier = GetConVarBool(JB_ConVars[11]);
	cv_WardenFF = GetConVarBool(JB_ConVars[12]);
	cv_WardenCC = GetConVarBool(JB_ConVars[13]);
	cv_WardenRequest = GetConVarBool(JB_ConVars[14]);
	cv_WardenLimit = GetConVarInt(JB_ConVars[15]);
	cv_DoorControl = GetConVarBool(JB_ConVars[16]);
	cv_DoorOpenTimer = GetConVarFloat(JB_ConVars[17]);
	cv_RedMute = GetConVarInt(JB_ConVars[18]);
	cv_RedMuteTime = GetConVarFloat(JB_ConVars[19]);
	cv_BlueMute = GetConVarInt(JB_ConVars[20]);
	cv_DeadMute = GetConVarBool(JB_ConVars[21]);
	cv_MicCheck = GetConVarBool(JB_ConVars[22]);
	cv_MicCheckType = GetConVarBool(JB_ConVars[23]);
	cv_Criticals = GetConVarInt(JB_ConVars[24]);
	cv_Criticalstype = GetConVarInt(JB_ConVars[25]);
	cv_WVotesNeeded = GetConVarFloat(JB_ConVars[26]);
	cv_WVotesMinPlayers = GetConVarInt(JB_ConVars[27]);
	cv_WVotesPostAction = GetConVarInt(JB_ConVars[28]);
	cv_WVotesPassedLimit = GetConVarInt(JB_ConVars[29]);
	cv_Freekillers = GetConVarBool(JB_ConVars[30]);
	cv_FreekillersTime = GetConVarFloat(JB_ConVars[31]);
	cv_FreekillersKills = GetConVarInt(JB_ConVars[32]);
	cv_FreekillersWave = GetConVarFloat(JB_ConVars[33]);
	cv_FreekillersAction = GetConVarInt(JB_ConVars[34]);
	GetConVarString(JB_ConVars[35], BanMsg, sizeof(BanMsg));
	GetConVarString(JB_ConVars[36], BanMsgDC, sizeof(BanMsgDC));
	cv_FreekillersBantime = GetConVarInt(JB_ConVars[37]);
	cv_FreekillersBantimeDC = GetConVarInt(JB_ConVars[38]);
	cv_1stDayFreeday = GetConVarBool(JB_ConVars[39]);
	cv_DemoCharge = GetConVarBool(JB_ConVars[40]);
	cv_DoubleJump = GetConVarBool(JB_ConVars[41]);
	cv_Airblast = GetConVarBool(JB_ConVars[42]);
	GetConVarString(JB_ConVars[43], Particle_Freekiller, sizeof(Particle_Freekiller));
	cv_WardenVoice = GetConVarInt(JB_ConVars[44]);
	cv_WardenWearables = GetConVarBool(JB_ConVars[45]);
	cv_WardenStabProtection = GetConVarInt(JB_ConVars[46]);
	cv_KillPointServerCommand = GetConVarBool(JB_ConVars[47]);
	cv_PrefStatus = GetConVarBool(JB_ConVars[48]);
	cv_WardenTimer = GetConVarInt(JB_ConVars[49]);
	cv_AdminFlags = GetConVarBool(JB_ConVars[50]);
	cv_PrefBlue = GetConVarBool(JB_ConVars[51]);
	cv_PrefWarden = GetConVarBool(JB_ConVars[52]);
	cv_ConsoleSpew = GetConVarBool(JB_ConVars[53]);
	cv_BuildingsManage = GetConVarInt(JB_ConVars[54]);
	
	if (cv_Enabled)
	{
		if (cv_Cvars)
		{
			ConvarsSet(true);
		}

		if (e_steamtools)
		{
			decl String:gameDesc[64];
			Format(gameDesc, sizeof(gameDesc), "%s v%s", PLUGIN_NAME, PLUGIN_VERSION);
			Steam_SetGameDescription(gameDesc);
		}

		if (g_bLateLoad)
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsClientConnected(i))
				{
					OnClientConnected(i);
				}
						
				if (!AreClientCookiesCached(i))
				{
					OnClientCookiesCached(i);
				}
				
				if (IsClientInGame(i))
				{
					OnClientPutInServer(i);
				}
			}
			g_1stRoundFreeday = false;
			g_bLateLoad = false;
		}
		
		ResetVotes();
		ParseConfigs();
		
		if (e_clientprefs && cv_PrefStatus)
		{
			SetCookieMenuItem(TF2Jail_Preferences, 0, "TF2Jail Preferences");
			
			if (cv_PrefBlue)
			{
				g_hRolePref_Blue = RegClientCookie("TF2Jail_RolePreference_Blue", "Sets the preferred role of the client. (Blue)", CookieAccess_Private);
			}
			
			if (cv_PrefWarden)
			{
				g_hRolePref_Warden = RegClientCookie("TF2Jail_RolePreference_Warden", "Sets the preferred role of the client. (Warden)", CookieAccess_Private);
			}
		}
		
		Jail_Log("%s Jailbreak has successfully loaded.", JTAG);
	}
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
		cv_Enabled = bool:iNewValue;
		switch (iNewValue)
		{
		case 0:
			{
				CPrintToChatAll("%s %t", JTAG_COLORED, "plugin disabled");
				if (e_steamtools)
				{
					Steam_SetGameDescription("Team Fortress");
				}
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						if (cv_WardenModel && IsWarden(i))
						{
							RemoveModel(i);
						}
					}
				}
			}
		case 1:
			{
				CPrintToChatAll("%s %t", JTAG_COLORED, "plugin enabled");
				if (e_steamtools)
				{
					decl String:gameDesc[64];
					Format(gameDesc, sizeof(gameDesc), "%s v%s", PLUGIN_NAME, PLUGIN_VERSION);
					Steam_SetGameDescription(gameDesc);
				}
				for (new i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						if (cv_WardenModel && IsWarden(i))
						{
							decl String:s[PLATFORM_MAX_PATH];
							Format(s, PLATFORM_MAX_PATH, "%s.mdl", WARDEN_MODEL);
							SetModel(i, s);
						}
					}
				}
			}
		}
	}
	else if (cvar == JB_ConVars[2])
	{
		cv_Advertise = bool:iNewValue;
		ClearTimer(hTimer_Advertisement);
		if (cv_Advertise)
		{
			StartAdvertisement();
		}
	}
	else if (cvar == JB_ConVars[3])
	{
		cv_Cvars = bool:iNewValue;
		ConvarsSet(cv_Cvars ? true : false);
	}
	else if (cvar == JB_ConVars[4])
	{
		cv_Logging = iNewValue;
	}
	else if (cvar == JB_ConVars[5])
	{
		cv_Balance = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[6])
	{
		cv_BalanceRatio = StringToFloat(newValue);
	}
	else if (cvar == JB_ConVars[7])
	{
		cv_RedMelee = bool:iNewValue;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i))
			{
				new team = GetClientTeam(i);
				switch (iNewValue)
				{
				case 0:
					{
						if (team == _:TFTeam_Red)
						{
							TF2_RegeneratePlayer(i);
						}
					}
				case 1: CreateTimer(0.1, ManageWeapons, GetClientUserId(i));
				}
			}
		}
	}
	else if (cvar == JB_ConVars[8])
	{
		cv_Warden = bool:iNewValue;
		if (cv_Warden)
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && IsWarden(i))
				{
					WardenUnset(i);
				}
			}
		}
	}
	else if (cvar == JB_ConVars[9])
	{
		cv_WardenAuto = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[10])
	{
		cv_WardenModel = bool:iNewValue;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsWarden(i))
			{
				if (cv_WardenModel)
				{
					decl String:s[PLATFORM_MAX_PATH];
					Format(s, PLATFORM_MAX_PATH, "%s.mdl", WARDEN_MODEL);
					SetModel(i, s);
				}
				else
				{
					RemoveModel(i);
				}
			}
		}
	}
	else if (cvar == JB_ConVars[11])
	{
		cv_WardenForceSoldier = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[12])
	{
		cv_WardenFF = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[13])
	{
		cv_WardenCC = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[14])
	{
		cv_WardenRequest = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[15])
	{
		cv_WardenLimit = iNewValue;
	}
	else if (cvar == JB_ConVars[16])
	{
		cv_DoorControl = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[17])
	{
		cv_DoorOpenTimer = StringToFloat(newValue);
	}
	else if (cvar == JB_ConVars[18])
	{
		cv_RedMute = iNewValue;
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i))
			{
				if (GetClientTeam(i) == _:TFTeam_Red)
				{
					switch (iNewValue)
					{
					case 0:	UnmutePlayer(i);
					case 1:	if (g_CellsOpened) MutePlayer(i);
					case 2:	if (g_bActiveRound) MutePlayer(i);
					}
				}
			}
		}
	}
	else if (cvar == JB_ConVars[19])
	{
		cv_RedMuteTime = StringToFloat(newValue);
	}
	else if (cvar == JB_ConVars[20])
	{
		cv_BlueMute = iNewValue;

		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i))
			{
				if (GetClientTeam(i) == _:TFTeam_Blue)
				{
					switch (iNewValue)
					{
					case 0:	UnmutePlayer(i);
					case 1:	MutePlayer(i);
					case 2:	if (!IsWarden(i)) MutePlayer(i);
					}
				}
			}
		}
	}
	else if (cvar == JB_ConVars[21])
	{
		cv_DeadMute = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[22])
	{
		cv_MicCheck = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[23])
	{
		cv_MicCheckType = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[24])
	{
		cv_Criticals = iNewValue;
	}
	else if (cvar == JB_ConVars[25])
	{
		cv_Criticalstype = iNewValue;
	}
	else if (cvar == JB_ConVars[26])
	{
		cv_WVotesNeeded = StringToFloat(newValue);
	}
	else if (cvar == JB_ConVars[27]) 
	{
		cv_WVotesMinPlayers = iNewValue;
	}
	else if (cvar == JB_ConVars[28]) 
	{
		cv_WVotesPostAction = iNewValue;
	}
	else if (cvar == JB_ConVars[29]) 
	{
		cv_WVotesPassedLimit = iNewValue;
	}
	else if (cvar == JB_ConVars[30])
	{
		cv_Freekillers = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[31])
	{
		cv_FreekillersTime = StringToFloat(newValue);
	}
	else if (cvar == JB_ConVars[32])
	{
		cv_FreekillersKills = iNewValue;
	}
	else if (cvar == JB_ConVars[33])
	{
		cv_FreekillersWave = StringToFloat(newValue);
	}
	else if (cvar == JB_ConVars[34])
	{
		cv_FreekillersAction = iNewValue;
	}
	else if (cvar == JB_ConVars[35])
	{
		GetConVarString(JB_ConVars[35], BanMsg, sizeof(BanMsg));
	}
	else if (cvar == JB_ConVars[36])
	{
		GetConVarString(JB_ConVars[36], BanMsgDC, sizeof(BanMsgDC));
	}
	else if (cvar == JB_ConVars[37])
	{
		cv_FreekillersBantime = iNewValue;
	}
	else if (cvar == JB_ConVars[38])
	{
		cv_FreekillersBantimeDC = iNewValue;
	}
	else if (cvar == JB_ConVars[39])
	{
		cv_1stDayFreeday = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[40])
	{
		cv_DemoCharge = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[41])
	{
		cv_DoubleJump = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[42])
	{
		cv_Airblast = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[43])
	{
		GetConVarString(JB_ConVars[43], Particle_Freekiller, sizeof(Particle_Freekiller));
	}
	else if (cvar == JB_ConVars[44])
	{
		cv_WardenVoice = iNewValue;
	}
	else if (cvar == JB_ConVars[45])
	{
		cv_WardenWearables = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[46])
	{
		cv_WardenStabProtection = iNewValue;
	}
	else if (cvar == JB_ConVars[47])
	{
		cv_KillPointServerCommand = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[48])
	{
		cv_PrefStatus = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[49])
	{
		cv_WardenTimer = iNewValue;
	}
	else if (cvar == JB_ConVars[50])
	{
		cv_AdminFlags = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[51])
	{
		cv_PrefBlue = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[52])
	{
		cv_PrefWarden = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[53])
	{
		cv_ConsoleSpew = bool:iNewValue;
	}
	else if (cvar == JB_ConVars[54])
	{
		cv_BuildingsManage = iNewValue;
	}
}

#if defined _updater_included
public Action:Updater_OnPluginChecking() Jail_Log("%s Checking if TF2Jail requires an update...", JTAG);
public Action:Updater_OnPluginDownloading() Jail_Log("%s New version has been found, downloading new files...", JTAG);
public Updater_OnPluginUpdated() Jail_Log("%s Download complete, updating files...", JTAG);
public Updater_OnPluginUpdating() Jail_Log("%s Updates complete! You may now reload the plugin or wait for map change/server restart.", JTAG);
#endif

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
public OnMapStart()
{
	if (!cv_Enabled) return;
	
	if (cv_Advertise) StartAdvertisement();
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			g_HasBeenWarden[i] = 0;
		}
	}
	
	if (cv_WardenModel)
	{
		decl String:s[PLATFORM_MAX_PATH];
		Format(s, PLATFORM_MAX_PATH, "%s.mdl", WARDEN_MODEL);
		if (PrecacheModel(s, true))
		{
			new String:extensions[][] = { ".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd", ".phy" };
			new String:extensionsb[][] = { ".vtf", ".vmt" };
			decl i;
			for (i = 0; i < sizeof(extensions); i++)
			{
				Format(s, PLATFORM_MAX_PATH, "%s%s", WARDEN_MODEL, extensions[i]);
				if (FileExists(s, true)) AddFileToDownloadsTable(s);
			}
			
			for (i = 0; i < sizeof(extensionsb); i++)
			{
				Format(s, PLATFORM_MAX_PATH, "materials/models/jailbreak/warden/NineteenEleven%s", extensionsb[i]);
				if (FileExists(s, true)) AddFileToDownloadsTable(s);
				
				Format(s, PLATFORM_MAX_PATH, "materials/models/jailbreak/warden/warden_body%s", extensionsb[i]);
				if (FileExists(s, true)) AddFileToDownloadsTable(s);
				
				Format(s, PLATFORM_MAX_PATH, "materials/models/jailbreak/warden/warden_hat%s", extensionsb[i]);
				if (FileExists(s, true)) AddFileToDownloadsTable(s);
				
				Format(s, PLATFORM_MAX_PATH, "materials/models/jailbreak/warden/warden_head%s", extensionsb[i]);
				if (FileExists(s, true)) AddFileToDownloadsTable(s);
			}
		}
		else
		{
			Jail_Log("Error precaching model, please check configurations and file integrity.");
			cv_WardenModel = false;
		}
	}
	
	PrecacheSound("ui/system_message_alert.wav", true);
	
	g_1stRoundFreeday = true;
	g_VotesNeeded = 0;
	WardenLimit = 0;
	
	ResetVotes();
}

public OnMapEnd()
{
	if (!cv_Enabled) return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			g_HasTalked[i] = false;
			g_IsMuted[i] = false;
			g_LockedFromWarden[i] = false;
			g_HasBeenWarden[i] = 0;
			
			if (IsWarden(i))
			{
				RemoveModel(i);
			}
			
			hTimer_ParticleTimers[i] = INVALID_HANDLE;
		}
	}

	g_bActiveRound = false;
	g_bAdminLockWarden = false;
	WardenLimit = 0;
	ResetVotes();
	
	ConvarsSet(false);
	
	hTimer_Advertisement = INVALID_HANDLE;
	hTimer_FreekillingData = INVALID_HANDLE;
	hTimer_OpenCells = INVALID_HANDLE;
	hTimer_FriendlyFireEnable = INVALID_HANDLE;
	hTimer_WardenLock = INVALID_HANDLE;
}

public OnClientConnected(client)
{
	if (!cv_Enabled) return;
	
	g_Voted[client] = false;
	g_Voters++;
	g_VotesNeeded = RoundToFloor(float(g_Voters) * cv_WVotesNeeded);
}

public OnClientCookiesCached(client)
{
	if (!cv_Enabled) return;
	
	if (IsValidClient(client))
	{
		decl String:value[8];
		
		if (cv_PrefStatus)
		{
			GetClientCookie(client, g_hRolePref_Blue, value, sizeof(value));
			g_bRolePreference_Blue[client] = (value[0] != '\0' && StringToInt(value));
			if(StrEqual(value, ""))
			{
				SetClientCookie(client, g_hRolePref_Blue, "1");
			}
			
			GetClientCookie(client, g_hRolePref_Warden, value, sizeof(value));
			g_bRolePreference_Warden[client] = (value[0] != '\0' && StringToInt(value));
			if(StrEqual(value, ""))
			{
				SetClientCookie(client, g_hRolePref_Warden, "1");
			}
		}
	}
}

public OnClientPutInServer(client)
{
	if (!cv_Enabled) return;
	
	g_IsMuted[client] = false;
	SDKHook(client, SDKHook_OnTakeDamage, PlayerTakeDamage);
}

public Action:PlayerTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (!cv_Enabled) return Plugin_Continue;
	
	if (IsValidClient(client) && IsValidClient(attacker))
	{
		if (attacker > 0 && attacker <= MaxClients)
		{
			switch (GetClientTeam(attacker))
			{
			case TFTeam_Red:
				{
					switch (cv_Criticals)
					{
					case 2, 3:
						{
							switch (cv_Criticalstype)
							{
							case 1: damagetype |= DMG_SLOWBURN;
							case 2: damagetype |= DMG_CRIT;
							}
							return Plugin_Changed;
						}
					}
				}
			case TFTeam_Blue:
				{
					switch (cv_Criticals)
					{
					case 1, 3:
						{
							switch (cv_Criticalstype)
							{
							case 1: damagetype |= DMG_SLOWBURN;
							case 2: damagetype |= DMG_CRIT;
							}
							return Plugin_Changed;
						}
					}
				}
			}
			if (cv_WardenStabProtection == 2)
			{
				if (IsWarden(client))
				{
					decl String:szClassName[64];
					GetEntityClassname(GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon"), szClassName, sizeof(szClassName));
					if (StrEqual(szClassName, "tf_weapon_knife") && (damagetype & DMG_CRIT == DMG_CRIT))
					{
						return Plugin_Handled;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public OnClientPostAdminCheck(client)
{
	if (!cv_Enabled) return;
	
	CreateTimer(4.0, Timer_Welcome, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientDisconnect(client)
{
	if (!cv_Enabled) return;

	if (IsValidClient(client))
	{
		if (g_Voted[client])
		{
			g_Votes--;
		}
		
		g_Voters--;
		g_VotesNeeded = RoundToFloor(float(g_Voters) * cv_WVotesNeeded);
		
		if (g_Votes && g_Voters && g_Votes >= g_VotesNeeded)
		{
			if (cv_WVotesPostAction == 1)
			{
				return;
			}
			FireWardenCall();
		}

		if (IsWarden(client))
		{
			CPrintToChatAll("%s %t", JTAG_COLORED, "warden disconnected");
			PrintCenterTextAll("%t", "warden disconnected center");
			Warden = -1;
		}
		
		g_HasTalked[client] = false;
		g_IsMuted[client] = false;
		g_ScoutsBlockedDoubleJump[client] = false;
		g_PyrosDisableAirblast[client] = false;
		g_Killcount[client] = 0;
		g_FirstKill[client] = 0;
		
		ClearTimer(hTimer_ParticleTimers[client]);
	}
}

public PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!cv_Enabled) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client))
	{
		new TFClassType:class = TF2_GetPlayerClass(client);
		
		switch (GetClientTeam(client))
		{
		case TFTeam_Red:
			{
				switch (class)
				{
				case TFClass_Spy:
					{
						if (TF2_IsPlayerInCondition(client, TFCond_Cloaked))
						{
							TF2_RemoveCondition(client, TFCond_Cloaked);
						}
					}
				case TFClass_Scout:
					{
						if (cv_DoubleJump)
						{
							AddAttribute(client, "no double jump", 1.0);
							g_ScoutsBlockedDoubleJump[client] = true;
						}
					}
				case TFClass_Pyro:
					{
						if (cv_Airblast)
						{
							AddAttribute(client, "airblast disabled", 1.0);
							g_PyrosDisableAirblast[client] = true;
						}
					}
				case TFClass_DemoMan:
					{
						if (cv_DemoCharge)
						{
							new ent = -1;
							while ((ent = FindEntityByClassnameSafe(ent, "tf_wearable_demoshield")) != -1)
							{
								AcceptEntityInput(ent, "kill");
							}
						}
					}
				}
				if (cv_RedMute != 0)
				{
					MutePlayer(client);
				}
			}
		case TFTeam_Blue:
			{
				#if defined _voiceannounce_ex_included_
				if (e_voiceannounce_ex && cv_MicCheck)
				{
					if (cv_MicCheckType)
					{
						if (!g_HasTalked[client] && !Client_HasAdminFlags(client, ADMFLAG_RESERVATION))
						{
							ChangeClientTeam(client, _:TFTeam_Red);
							TF2_RespawnPlayer(client);
							CPrintToChat(client, "%s %t", JTAG_COLORED, "microphone unverified");
						}
					}
				}
				#endif
				
				if (cv_BlueMute == 2)
				{
					MutePlayer(client);
				}
			}
		}
	}
}

public PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!cv_Enabled) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new client_killer = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (IsValidClient(client))
	{
		if (IsValidClient(client_killer))
		{
			if (client_killer != client)
			{
				if (cv_Freekillers)
				{
					if (GetClientTeam(client_killer) == _:TFTeam_Blue)
					{
						if ((g_FirstKill[client_killer] + cv_FreekillersTime) >= GetTime())
						{
							if (++g_Killcount[client_killer] == cv_FreekillersKills)
							{
								if (!g_VoidFreekills)
								{
									MarkFreekiller(client_killer);
								}
								else
								{
									CPrintToChatAll("%s %t", JTAG_COLORED, "freekiller flagged while void", client_killer);
								}
							}
						}
						else
						{
							g_Killcount[client_killer] = 1;
							g_FirstKill[client_killer] = GetTime();
						}
					}
				}
			}
		}
		
		if (!g_bOneGuardLeft)
		{
			if (Team_GetClientCount(_:TFTeam_Blue, CLIENTFILTER_ALIVE) == 1)
			{
				g_VoidFreekills = true;
				g_bOneGuardLeft = true;
				PrintCenterTextAll("%t", "last guard");
			}
		}

		if (cv_DeadMute)
		{
			MutePlayer(client);
		}
		
		if (g_PyrosDisableAirblast[client])
		{
			RemoveAttribute(client, "airblast disabled");
			g_PyrosDisableAirblast[client] = false;
		}
		
		if (g_ScoutsBlockedDoubleJump[client])
		{
			RemoveAttribute(client, "no double jump");
			g_ScoutsBlockedDoubleJump[client] = false;
		}
				
		if (IsWarden(client))
		{
			WardenUnset(client);
			PrintCenterTextAll("%t", "warden killed", client);
		}
		
		ClearTimer(hTimer_ParticleTimers[client]);
	}
}

public RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!cv_Enabled) return;

	if (cv_1stDayFreeday && g_1stRoundFreeday)
	{
		DoorHandler(OPEN);
		PrintCenterTextAll("1st round freeday");
		SetHudTextParams(-1.0, 0.9, 99999.0, 255,0,0, 255);
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowSyncHudText(i, JB_HudHandler, "1st Day Freeday");
			}
		}
		g_1stRoundFreeday = false;
		Jail_Log("1st day freeday has been activated.");
	}
	
	if (g_IsMapCompatible)
	{
		if (!StrEqual(GCellOpener, ""))
		{
			new CellHandler = Entity_FindByName(GCellOpener, "func_button");
			if (Entity_IsValid(CellHandler))
			{
				if (cv_DoorControl)
				{
					Entity_Lock(CellHandler);
					Jail_Log("Door Controls: Disabled - Cell Opener is locked.");
				}
				else
				{
					Entity_UnLock(CellHandler);
					Jail_Log("Door Controls: Enabled - Cell Opener is unlocked.");
				}
			}
			else
			{
				Jail_Log("[ERROR] Entity name not found for Cell Door Opener! Please verify integrity of the config and the map.");
			}
		}
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && g_HasModel[i])
		{
			RemoveModel(i);
		}
	}
	
	Warden = -1;
	g_bActiveRound = true;
}

public ArenaRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!cv_Enabled) return;
	
	g_bIsWardenLocked = false;
	
	if (cv_Balance)
	{
		new Float:Ratio;
		for (new i = 1; i <= MaxClients; i++)
		{
			Ratio = Float:GetTeamClientCount(_:TFTeam_Blue)/Float:GetTeamClientCount(_:TFTeam_Red);
			if (Ratio <= cv_BalanceRatio || GetTeamClientCount(_:TFTeam_Red) == 2)
			{
				break;
			}
			if (IsValidClient(i) && GetClientTeam(i) == _:TFTeam_Blue)
			{
				if (cv_PrefStatus && g_bRolePreference_Blue[i])
				{
					continue;
				}

				ChangeClientTeam(i, _:TFTeam_Red);
				TF2_RespawnPlayer(i);
				CPrintToChat(i, "%s %t", JTAG_COLORED, "moved for balance");
				
				if (g_HasModel[i])
				{
					RemoveModel(i);
				}
				
				Jail_Log("%N has been moved to prisoners team for balance.", i);
			}
		}
	}
	
	if (g_IsMapCompatible && cv_DoorOpenTimer != 0.0)
	{
		new autoopen = RoundFloat(cv_DoorOpenTimer);
		CPrintToChatAll("%s %t", JTAG_COLORED, "cell doors open start", autoopen);
		hTimer_OpenCells = CreateTimer(cv_DoorOpenTimer, Open_Doors, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
		g_CellsOpened = true;
		Jail_Log("Cell doors have been auto opened via automatic timer if they exist.");
	}

	switch(cv_RedMute)
	{
	case 0:
		{
			CPrintToChatAll("%s %t", JTAG_COLORED, "red mute system disabled");
			Jail_Log("Mute system has been disabled this round, nobody has been muted.");
		}
	case 1:
		{
			new time = RoundFloat(cv_RedMuteTime);
			CPrintToChatAll("%s %t", JTAG_COLORED, "red team muted temporarily", time);
			CreateTimer(cv_RedMuteTime, UnmuteReds, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
			Jail_Log("Red team has been temporarily muted and will wait %s seconds to be unmuted.", time);
		}
	case 2:
		{
			CPrintToChatAll("%s %t", JTAG_COLORED, "red team muted");
			Jail_Log("Red team has been muted permanently this round.");
		}
	}
	
	FindRandomWarden();
}

public RoundEnd(Handle:hEvent, const String:strName[], bool:bBroadcast)
{
	if (!cv_Enabled) return;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			UnmutePlayer(i);

			if (g_ScoutsBlockedDoubleJump[i])
			{
				RemoveAttribute(i, "no double jump");
				g_ScoutsBlockedDoubleJump[i] = false;
			}
			else if (g_PyrosDisableAirblast[i])
			{
				RemoveAttribute(i, "airblast disabled");
				g_PyrosDisableAirblast[i] = false;
			}
			
			ClearSyncHud(i, JB_HudHandler);
		}
	}
	
	SetConVarBool(JB_EngineConVars[0], false);
	SetConVarBool(JB_EngineConVars[1], false);
	
	g_bIsWardenLocked = true;
	g_bOneGuardLeft = false;
	g_bActiveRound = false;
	g_VoidFreekills = false;
	
	ClearTimer(hTimer_OpenCells);
	ClearTimer(hTimer_WardenLock);
	ClearTimer(hTimer_FriendlyFireEnable);
	
	CloseAllMenus();
}

public RegeneratePlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, ManageWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public OnEntityCreated(entity, const String:classname[])
{
	if (!cv_Enabled) return;
	
	if (IsValidEntity(entity))
	{
		if (StrContains(classname, "tf_ammo_pack", false) != -1)
		{
			AcceptEntityInput(entity, "Kill");
		}
		
		if (cv_KillPointServerCommand)
		{
			if (StrContains(classname, "point_servercommand", false) != -1)
			{
				if (cv_KillPointServerCommand)
				{
					//AcceptEntityInput(entity, "Kill");
				}
			}
		}
	}
}

public Action:InterceptBuild(client, const String:command[], args)
{
	if (!cv_Enabled) return Plugin_Continue;
		
	if (IsValidClient(client))
	{
		switch (GetClientTeam(client))
		{
		case TFTeam_Red:
			{
				switch (cv_BuildingsManage)
				{
				case 2, 3: return Plugin_Handled;
				}
			}
		case TFTeam_Blue:
			{
				switch (cv_BuildingsManage)
				{
				case 1, 3: return Plugin_Handled;
				}
			}
		}
	}
	return Plugin_Continue;
}

#if defined _voiceannounce_ex_included_
public bool:OnClientSpeakingEx(client)
{
	if (!cv_Enabled) return false;
	
	if (e_voiceannounce_ex && cv_MicCheck && !g_HasTalked[client])
	{
		g_HasTalked[client] = true;
		CPrintToChat(client, "%s %t", JTAG_COLORED, "microphone verified");
		return true;
	}
	return false;
}
#endif

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
public Action:Command_FireWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;

	if (IsValidClient(client))
	{
		if (cv_WVotesPassedLimit != 0)
		{
			if (WardenLimit < cv_WVotesPassedLimit)
			{
				AttemptFireWarden(client);
			}
			else
			{
				PrintToChat(client, "You are not allowed to vote again, the warden fire limit has been reached.");
			}
		}
		else
		{
			AttemptFireWarden(client);
		}
	}
	else
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
	}
	return Plugin_Handled;
}

AttemptFireWarden(client)
{
	if (GetClientCount(true) < cv_WVotesMinPlayers)
	{
		CReplyToCommand(client, "%s %t", JTAG, "fire warden minimum players not met");
		return;			
	}

	if (g_Voted[client])
	{
		CReplyToCommand(client, "%s %t", JTAG, "fire warden already voted", g_Votes, g_VotesNeeded);
		return;
	}

	new String:name[64];
	GetClientName(client, name, sizeof(name));
	g_Votes++;
	g_Voted[client] = true;

	CPrintToChatAll("%s %t", JTAG_COLORED, "fire warden requested", name, g_Votes, g_VotesNeeded);

	if (g_Votes >= g_VotesNeeded)
	{
		FireWardenCall();
	}
}

FireWardenCall()
{
	if (Warden != -1)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsWarden(i))
			{
				WardenUnset(i);
				g_LockedFromWarden[i] = true;
			}
		}
		ResetVotes();
		g_VotesPassed++;
		WardenLimit++;
	}
}

ResetVotes()
{
	g_Votes = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		g_Voted[i] = false;
	}
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
public Action:AdminMapCompatibilityCheck(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (!StrEqual(GCellNames, ""))
	{
		new cell_door = Entity_FindByName(GCellNames, "func_door");
		switch (Entity_IsValid(cell_door))
		{
		case false: CReplyToCommand(client, "%s %t", JTAG, "Map Compatibility Cell Doors Undetected");
		case true: CReplyToCommand(client, "%s %t", JTAG, "Map Compatibility Cell Doors Detected");
		}
	}
	
	if (!StrEqual(GCellOpener, ""))
	{
		new open_cells = Entity_FindByName(GCellOpener, "func_button");		
		switch (Entity_IsValid(open_cells))
		{
		case false: CReplyToCommand(client, "%s %t", JTAG, "Map Compatibility Cell Opener Undetected");
		case true: CReplyToCommand(client, "%s %t", JTAG, "Map Compatibility Cell Opener Detected");
		}
	}

	CShowActivity2(client, JTAG_COLORED, "%t", "Admin Scan Map Compatibility");
	Jail_Log("Admin %N has checked the map for compatibility.", client);
	return Plugin_Handled;
}

public Action:AdminResetPlugin(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		g_ScoutsBlockedDoubleJump[i] = false;
		g_PyrosDisableAirblast[i] = false;
		g_IsMuted[i] = false;
		g_IsFreekiller[i] = false;
		g_HasTalked[i] = false;
		g_LockedFromWarden[i] = false;
		g_HasModel[i] = false;

		g_FirstKill[i] = 0;
		g_Killcount[i] = 0;
		g_HasBeenWarden[i] = 0;
	}
	
	g_CellsOpened = false;
	g_1stRoundFreeday = false;
	g_VoidFreekills = false;
	g_bIsWardenLocked = false;
	g_bOneGuardLeft = false;
	g_bLateLoad = false;

	Warden = -1;
	WardenLimit = 0;

	EnumWardenMenu = Open;
	
	ParseConfigs();

	CShowActivity2(client, JTAG_COLORED, "%t", "Admin Reset Plugin");
	Jail_Log("Admin %N has reset the plugin of all it's bools, integers and floats.", client);

	return Plugin_Handled;
}

public Action:AdminOpenCells(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (g_IsMapCompatible)
	{
		DoorHandler(OPEN);
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Open Cells");
		Jail_Log("Admin %N has opened the cells using admin.", client);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "incompatible map");
	}

	return Plugin_Handled;
}

public Action:AdminCloseCells(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (g_IsMapCompatible)
	{
		DoorHandler(CLOSE);
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Close Cells");
		Jail_Log("Admin %N has closed the cells using admin.", client);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "incompatible map");
	}

	return Plugin_Handled;
}

public Action:AdminLockCells(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (g_IsMapCompatible)
	{
		DoorHandler(LOCK);
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Lock Cells");
		Jail_Log("Admin %N has locked the cells using admin.", client);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG, "incompatible map");
	}
	
	return Plugin_Handled;
}

public Action:AdminUnlockCells(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;

	if (g_IsMapCompatible)
	{
		DoorHandler(UNLOCK);
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Unlock Cells");
		Jail_Log("Admin %N has unlocked the cells using admin.", client);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "incompatible map");
	}

	return Plugin_Handled;
}

public Action:AdminForceWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (Warden != -1)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden current", Warden);
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		FindWardenRandom(client);
	}
	else
	{
		new String:arg1[64];
		GetCmdArgString(arg1, sizeof(arg1));

		new target = FindTarget(client, arg1);
		if (target != -1 || target <= 2 || target != client)
		{
			if (cv_PrefStatus)
			{
				if (Team_GetClientCount(_:TFTeam_Blue, CLIENTFILTER_ALIVE) != 1)
				{
					if (g_bRolePreference_Warden[target])
					{
						WardenSet(target);
						CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Warden", target);
						Jail_Log("Admin %N has forced a %N Warden.", client, target);
					}
					else
					{
						CPrintToChat(client, "%s %t", JTAG_COLORED, "Admin Force Warden Not Preferred", target);
						Jail_Log("Client %N has their preference set to prisoner only, finding another client...", target);
					}
				}
				else
				{
					WardenSet(target);
					CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Warden", target);
					Jail_Log("Admin %N has forced a %N Warden.", client, target);
				}
			}
			else
			{
				WardenSet(target);
				CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Warden", target);
				Jail_Log("Admin %N has forced a %N Warden.", client, target);
			}
		}
	}
	return Plugin_Handled;
}

FindWardenRandom(client)
{
	new Random = Client_GetRandom(CLIENTFILTER_TEAMTWO|CLIENTFILTER_ALIVE);
	if (IsValidClient(Random))
	{
		if (cv_PrefStatus)
		{
			if (Team_GetClientCount(_:TFTeam_Blue, CLIENTFILTER_ALIVE) != 1)
			{
				if (g_bRolePreference_Warden[Random])
				{
					WardenSet(Random);
					CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Warden Random", Random);
					Jail_Log("Admin %N has given %N Warden by Force.", client, Random);
				}
				else
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "Admin Force Random Warden Not Preferred", Random);
					Jail_Log("Client %N has their preference set to prisoner only, finding another client...", Random);
					FindWardenRandom(client);
				}
			}
			else
			{
				WardenSet(Random);
				CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Warden Random", Random);
				Jail_Log("Admin %N has given %N Warden by Force.", client, Random);
			}
		}
		else
		{
			WardenSet(Random);
			CShowActivity2(client, JTAG_COLORED, "%t", "Admin Force Warden Random", Random);
			Jail_Log("Admin %N has given %N Warden by Force.", client, Random);
		}
	}
}

public Action:AdminPardonFreekiller(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (cv_Freekillers)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (g_IsFreekiller[i])
			{
				TF2_RegeneratePlayer(i);
				ServerCommand("sm_beacon #%d", GetClientUserId(i));
				g_IsFreekiller[i] = false;
				ClearTimer(hTimer_FreekillingData);
				ClearTimer(hTimer_ParticleTimers[i]);
			}
		}
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Pardon Freekillers");
		Jail_Log("Admin %N has pardoned all currently marked Freekillers.", client);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "freekillers system disabled");
	}
	return Plugin_Handled;
}

public Action:AdminAcceptWardenChange(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;

	switch (EnumWardenMenu)
	{
	case Open:
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "no current requests");
		}
	case FriendlyFire:
		{
			SetConVarBool(JB_EngineConVars[0], true);
			CShowActivity2(client, JTAG_COLORED, "%t", "Admin Accept Request FF", Warden);
			CPrintToChatAll("%s %t", JTAG_COLORED, "friendlyfire enabled");
			Jail_Log("Admin %N has accepted %N's request to enable Friendly Fire.", client, Warden);
		}
	case Collision:
		{
			SetConVarBool(JB_EngineConVars[1], true);
			CShowActivity2(client, JTAG_COLORED, "%t", "Admin Accept Request CC", Warden);
			CPrintToChatAll("%s %t", JTAG_COLORED, "collision enabled");
			Jail_Log("Admin %N has accepted %N's request to enable Collision.", client, Warden);
		}
	}
	return Plugin_Handled;
}

public Action:AdminCancelWardenChange(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;

	switch (EnumWardenMenu)
	{
	case Open:
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "no active warden commands");
		}
	case FriendlyFire:
		{
			SetConVarBool(JB_EngineConVars[0], false);
			CShowActivity2(client, JTAG_COLORED, "%t", "Admin Cancel Active FF");
			CPrintToChatAll("%s %t", JTAG_COLORED, "friendlyfire disabled");
			Jail_Log("Admin %N has cancelled %N's request for Friendly Fire.", client, Warden);
		}
	case Collision:
		{
			SetConVarBool(JB_EngineConVars[1], false);
			CShowActivity2(client, JTAG_COLORED, "%t", "Admin Cancel Active CC");
			CPrintToChatAll("%s %t", JTAG_COLORED, "collision disabled");
			Jail_Log("Admin %N has cancelled %N's request for Collision.", client, Warden);
		}
	}
	EnumWardenMenu = Open;
	
	return Plugin_Handled;
}

public Action:AdminDebugging(client, args)
{
	return Plugin_Handled;
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
public Action:BecomeWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (!cv_Warden)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden disabled");
		return Plugin_Handled;
	}
	
	if (g_1stRoundFreeday || g_bIsWardenLocked)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden locked");
		return Plugin_Handled;
	}
	
	#if defined _tf2jail_lastrequests_included
	if (e_tf2jail_lastrequests && TF2Jail_LockWardenLR())
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden locked lr round");
		return Plugin_Handled;
	}
	#endif
	
	if (Warden != -1)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden current", Warden);
		return Plugin_Handled;
	}
	
	if (g_bAdminLockWarden)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden locked admin");
		return Plugin_Handled;
	}
	
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		if (cv_WardenLimit != 0)
		{
			if (g_HasBeenWarden[client] >= cv_WardenLimit && GetClientTeam(client) == _:TFTeam_Blue)
			{	
				CPrintToChat(client, "%s %t", JTAG_COLORED, "warden limit reached", client, cv_WardenLimit);
				return Plugin_Handled;
			}
		}
		
		#if defined _voiceannounce_ex_included_
		if (cv_MicCheck && !cv_MicCheckType && !g_HasTalked[client])
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "microphone check warden block");
			return Plugin_Handled;
		}
		#endif
		
		if (g_LockedFromWarden[client])
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "voted off of warden");
			return Plugin_Handled;
		}
		
		if (GetClientTeam(client) != _:TFTeam_Blue)
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "guards only");
			return Plugin_Handled;
		}
		
		if (cv_PrefStatus && g_bRolePreference_Warden[client])
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "preference set against guards or warden");
			return Plugin_Handled;
		}

		if (cv_AdminFlags && !IsVIP(client))
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "warden incorrect flags");
			return Plugin_Handled;
		}
		
		WardenSet(client);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "dead warden");
	}
	return Plugin_Handled;
}

public Action:CurrentWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (Warden != -1)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden current", Warden);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "no warden current", Warden);
	}
	return Plugin_Handled;
}

public Action:WardenMenuC(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (IsValidClient(client))
	{
		if (IsWarden(client))
		{
			WardenMenu(client);
		}
		else
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
		}
	}
	else
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
	}

	return Plugin_Handled;
}

WardenMenu(client)
{
	if (!IsVoteInProgress())
	{
		new Handle:menu = CreateMenu(MenuHandle_WardenMenu);
		SetMenuTitle(menu, "Available Warden Commands:");
		AddMenuItem(menu, "1", "Open Cells");
		AddMenuItem(menu, "2", "Close Cells");
		AddMenuItem(menu, "3", "Toggle Friendlyfire");
		AddMenuItem(menu, "4", "Toggle Collision");
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 30);
	}
}

public MenuHandle_WardenMenu(Handle:menu, MenuAction:action, client, item)
{
	switch (action)
	{
	case MenuAction_Select:
		{
			switch (item)
			{
			case 0: FakeClientCommandEx(client, "say /open");
			case 1: FakeClientCommandEx(client, "say /close");
			case 2: FakeClientCommandEx(client, "say /wff");
			case 3: FakeClientCommandEx(client, "say /wcc");
			}
		}
	case MenuAction_End: CloseHandle(menu);
	}
}

public Action:WardenFriendlyFire(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (!client)
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
		return Plugin_Handled;
	}

	if (!cv_WardenFF)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden friendly fire manage disabled");
		return Plugin_Handled;
	}
	
	if (client != Warden)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
		return Plugin_Handled;
	}

	if (!cv_WardenRequest)
	{
		if (!GetConVarBool(JB_EngineConVars[0]))
		{
			SetConVarBool(JB_EngineConVars[0], true);
			CPrintToChatAll("%s %t", JTAG_COLORED, "friendlyfire enabled");
			Jail_Log("%N has enabled friendly fire as warden.", Warden);
		}
		else
		{
			SetConVarBool(JB_EngineConVars[0], false);
			CPrintToChatAll("%s %t", JTAG_COLORED, "friendlyfire disabled");
			Jail_Log("%N has disabled friendly fire as warden.", Warden);
		}
	}
	else
	{
		CPrintToChatAll("%s %t", JTAG_COLORED, "friendlyfire request");
		EnumWardenMenu = FriendlyFire;
	}
	
	return Plugin_Handled;
}

public Action:WardenCollision(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (!client)
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!cv_WardenCC)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "warden collision manage disabled");
		return Plugin_Handled;
	}
	
	if (client != Warden)
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
		return Plugin_Handled;
	}
	
	if (!cv_WardenRequest)
	{
		if (!GetConVarBool(JB_EngineConVars[1]))
		{
			SetConVarBool(JB_EngineConVars[1], true);
			CPrintToChatAll("%s %t", JTAG_COLORED, "collision enabled");
			Jail_Log("%N has enabled collision as warden.", Warden);
		}
		else
		{
			SetConVarBool(JB_EngineConVars[1], false);
			CPrintToChatAll("%s %t", JTAG_COLORED, "collision disabled");
			Jail_Log("%N has disabled collision as warden.", Warden);
		}
	}
	else
	{
		CPrintToChatAll("%s %t", JTAG_COLORED, "collision request");
		EnumWardenMenu = Collision;
	}

	return Plugin_Handled;
}

public Action:ExitWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (!client)
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (IsWarden(client))
	{
		CPrintToChatAll("%s %t", JTAG_COLORED, "warden retired", client);
		PrintCenterTextAll("%t", "warden retired center");
		WardenUnset(client);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
	}

	return Plugin_Handled;
}

public Action:LockWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsWarden(i))
		{
			WardenUnset(i);
		}
	}
	g_bAdminLockWarden = true;
	CShowActivity2(client, JTAG_COLORED, "%t", "Admin Lock Warden");
	Jail_Log("Admin %N has locked Warden via administration.", client);
	return Plugin_Handled;
}

public Action:UnlockWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	g_bAdminLockWarden = false;
	CShowActivity2(client, JTAG_COLORED, "%t", "Admin Unlock Warden");
	Jail_Log("Admin %N has unlocked Warden via administration.", client);
	return Plugin_Handled;
}

public Action:AdminRemoveWarden(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (Warden != -1)
	{
		PrintCenterTextAll("%t", "warden fired center");
		CShowActivity2(client, JTAG_COLORED, "%t", "Admin Remove Warden", Warden);
		Jail_Log("Admin %N has removed %N's Warden status with admin.", client, Warden);
		WardenUnset(Warden);
	}
	else
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "no warden current");
	}

	return Plugin_Handled;
}

public Action:OnOpenCommand(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (IsValidClient(client))
	{
		if (cv_DoorControl)
		{
			if (g_IsMapCompatible)
			{
				if (IsWarden(client))
				{
					DoorHandler(OPEN);
					Jail_Log("%N has opened the cell doors using door controls as warden.", client);
				}
				else
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
				}
			}
			else
			{
				CPrintToChat(client, "%s %t", JTAG_COLORED, "incompatible map");
			}
		}
		else
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "door controls disabled");
		}
	}
	else
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
	}
	return Plugin_Handled;
}

public Action:OnCloseCommand(client, args)
{
	if (!cv_Enabled) return Plugin_Handled;
	
	if (IsValidClient(client))
	{
		if (cv_DoorControl)
		{
			if (g_IsMapCompatible)
			{
				if (IsWarden(client))
				{
					DoorHandler(CLOSE);
					Jail_Log("%N has closed the cell doors using door controls as warden.", client);
				}
				else
				{
					CPrintToChat(client, "%s %t", JTAG_COLORED, "not warden");
				}
			}
			else
			{
				CPrintToChat(client, "%s %t", JTAG_COLORED, "incompatible map");
			}
		}
		else
		{
			CPrintToChat(client, "%s %t", JTAG_COLORED, "door controls disabled");
		}
	}
	else
	{
		CReplyToCommand(client, "%s%t", JTAG, "Command is in-game only");
	}
	return Plugin_Handled;
}

WardenSet(client)
{
	Warden = client;
	g_HasBeenWarden[client]++;
	
	switch (cv_WardenVoice)
	{
	case 1: SetClientListeningFlags(client, VOICE_NORMAL);
	case 2: CPrintToChatAll("%s %t", JTAG_COLORED, "warden voice muted", Warden);
	}
	
	if (cv_WardenForceSoldier)
	{
		new Health = GetClientHealth(client);
		TF2_SetPlayerClass(client, TFClass_Soldier);
		TF2_RegeneratePlayer(client);
		new Health2 = GetClientHealth(client);
		if (Health < Health2)
		{
			SetEntityHealth(client, Health);
		}
	}

	if (cv_WardenModel)
	{
		decl String:s[PLATFORM_MAX_PATH];
		Format(s, PLATFORM_MAX_PATH, "%s.mdl", WARDEN_MODEL);
		SetModel(client, s);
	}
	
	if (cv_WardenStabProtection == 1)
	{
		AddAttribute(client, "backstab shield", 1.0);
	}
	
	SetHudTextParams(-1.0, -1.0, 2.0, 255, 255, 255, 255, 1, _, 1.0, 1.0);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (cv_BlueMute == 1)
			{
				if (GetClientTeam(i) == _:TFTeam_Blue && !IsWarden(i))
				{
					MutePlayer(i);
				}
			}
			ShowSyncHudText(i, WardenName, "%t", "warden current screen", Warden);
		}
	}
	
	ClearTimer(hTimer_WardenLock);
	
	ResetVotes();
	WardenMenu(client);
	
	Call_StartForward(Forward_WardenCreated);
	Call_PushCell(client);
	Call_Finish();
	
	CPrintToChatAll("%s %t", JTAG_COLORED, "warden new", client);
	CPrintToChat(client, "%s %t", JTAG_COLORED, "warden message");
}

WardenUnset(client)
{
	if (Warden != -1)
	{
		Warden = -1;
		if (cv_WardenModel)
		{
			RemoveModel(client);
		}
	}
	
	if (g_bActiveRound)
	{
		if (cv_BlueMute == 1)
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && GetClientTeam(i) == _:TFTeam_Blue)
				{
					UnmutePlayer(i);
				}
			}
		}
		
		if (cv_WardenTimer != 0 && cv_WardenTimer != 0.0)
		{
			new Float:timer = float(cv_WardenTimer);
			hTimer_WardenLock = CreateTimer(timer, DisableWarden, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	RemoveAttribute(client, "backstab shield");
	
	Call_StartForward(Forward_WardenRemoved);
	Call_PushCell(client);
	Call_Finish();
}

public Action:SetModel(client, const String:model[])
{
	if (IsValidClient(client) && IsPlayerAlive(client) && !g_HasModel[client])
	{
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);
		if (cv_WardenWearables)
		{
			RemoveValveHat(client, true);
		}
		g_HasModel[client] = true;
	}
}

public Action:RemoveModel(client)
{
	if (IsValidClient(client) && g_HasModel[client])
	{
		SetVariantString("");
		AcceptEntityInput(client, "SetCustomModel");
		RemoveValveHat(client);
		g_HasModel[client] = false;
	}
}

/* Stock Functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
MarkFreekiller(client)
{
	g_IsFreekiller[client] = true;
	
	ClearTimer(hTimer_ParticleTimers[client]);
	hTimer_ParticleTimers[client] = CreateTimer(2.0, Timer_FreekillerParticle, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	TF2_RemoveAllWeapons(client);
	ServerCommand("sm_beacon #%d", GetClientUserId(client));
	EmitSoundToAll("ui/system_message_alert.wav", _, _, _, _, 1.0, _, _, _, _, _, _);
	
	if (cv_FreekillersWave >= 1.0)
	{
		new time = RoundFloat(cv_FreekillersWave);
		CPrintToChatAll("%s %t", JTAG_COLORED, "freekiller timer start", client, time);

		decl String:sAuth[24];
		if(!GetClientAuthString(client, sAuth, sizeof(sAuth[])))
		{
			CReplyToCommand(client, "%s Client failed to auth, delayed ban not possible.", JTAG);
			return;
		}
		else
		{
			new Handle:hPack;
			hTimer_FreekillingData = CreateDataTimer(cv_FreekillersWave, BanClientTimerFreekiller, hPack, TIMER_FLAG_NO_MAPCHANGE);
			if (hTimer_FreekillingData != INVALID_HANDLE)
			{
				WritePackCell(hPack, client);
				WritePackCell(hPack, GetClientUserId(client));
				WritePackString(hPack, sAuth);
				PushArrayCell(hPack, hTimer_FreekillingData);
			}
			else
			{
				hTimer_FreekillingData = INVALID_HANDLE;
				CloseHandle(hPack);
			}
		}
	}
	Jail_Log("%N has been marked as a Freekiller.", client);
}

public Action:Timer_FreekillerParticle(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		CreateParticle(Particle_Freekiller, 3.0, client, ATTACH_NORMAL);
	}
	else
	{
		ClearTimer(hTimer_ParticleTimers[client]);
	}
}

bool:AlreadyMuted(client)
{
	switch (EnumCommsList)
	{
	case Basecomms:
		{
			if (!BaseComm_IsClientMuted(client)) return false;
		}
	case Sourcecomms:
		{
			if (SourceComms_GetClientMuteType(client) == bNot) return false;
		}
	}
	return true;
}

ConvarsSet(bool:Status = false)
{
	if (Status)
	{
		SetConVarInt(FindConVar("mp_stalemate_enable"),0);
		SetConVarInt(FindConVar("tf_arena_use_queue"), 0);
		SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);
		SetConVarInt(FindConVar("mp_autoteambalance"), 0);
		SetConVarInt(FindConVar("tf_arena_first_blood"), 0);
		SetConVarInt(FindConVar("mp_scrambleteams_auto"), 0);
		SetConVarInt(FindConVar("phys_pushscale"), 1000);
	}
	else
	{
		SetConVarInt(FindConVar("mp_stalemate_enable"),1);
		SetConVarInt(FindConVar("tf_arena_use_queue"), 1);
		SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 1);
		SetConVarInt(FindConVar("mp_autoteambalance"), 1);
		SetConVarInt(FindConVar("tf_arena_first_blood"), 1);
		SetConVarInt(FindConVar("mp_scrambleteams_auto"), 1);
	}
}

bool:IsWarden(client)
{
	if (client == Warden) return true;
	return false;
}

MutePlayer(client)
{
	if (!AlreadyMuted(client) && !IsVIP(client) && !g_IsMuted[client])
	{
		SetClientListeningFlags(client, VOICE_MUTED);
		g_IsMuted[client] = true;
		CPrintToChat(client, "%s %t", JTAG_COLORED, "muted player");
	}
}

UnmutePlayer(client)
{
	if (!AlreadyMuted(client) && !IsVIP(client) && g_IsMuted[client])
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
		g_IsMuted[client] = false;
		CPrintToChat(client, "%s %t", JTAG_COLORED, "unmuted player");
	}
}

ParseConfigs()
{
	new Handle:MapConfig = CreateKeyValues("TF2Jail_MapConfig");
	
	decl String:MapConfig_File[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, MapConfig_File, sizeof(MapConfig_File), "configs/tf2jail/mapconfig.cfg");
	
	decl String:g_Mapname[128];
	GetCurrentMap(g_Mapname, sizeof(g_Mapname));

	Jail_Log("Loading last request configuration entry - %s...", g_Mapname);

	if (FileToKeyValues(MapConfig, MapConfig_File))
	{
		if (KvJumpToKey(MapConfig, g_Mapname))
		{
			decl String:CellNames[32], String:CellsButton[32];
			
			KvGetString(MapConfig, "CellNames", CellNames, sizeof(CellNames), "");
			if (!StrEqual(CellNames, ""))
			{
				new CellNames_H = Entity_FindByName(CellNames, "func_door");
				if (Entity_IsValid(CellNames_H))
				{
					GCellNames = CellNames;
					g_IsMapCompatible = true;
				}
				else
				{
					g_IsMapCompatible = false;
				}
			}
			else
			{
				g_IsMapCompatible = false;
			}
			
			KvGetString(MapConfig, "CellsButton", CellsButton, sizeof(CellsButton), "");
			if (!StrEqual(CellsButton, ""))
			{
				new CellsButton_H = Entity_FindByName(CellsButton, "func_button");
				if (Entity_IsValid(CellsButton_H))
				{
					GCellOpener = CellsButton;
				}
			}
			
			#if defined _tf2jail_lastrequests_included
			if (e_tf2jail_lastrequests && KvJumpToKey(MapConfig, "Freeday"))
			{
				if (KvJumpToKey(MapConfig, "Teleport"))
				{
					new status = (KvGetNum(MapConfig, "Status", 1) == 1);
					
					if (status)
					{
						new Float:free_pos[3];
						free_pos[0] = KvGetFloat(MapConfig, "Coordinate_X");
						free_pos[1] = KvGetFloat(MapConfig, "Coordinate_Y");
						free_pos[2] = KvGetFloat(MapConfig, "Coordinate_Z");
						
						TF2Jail_SetFreedayPos(status, free_pos[0] , free_pos[1] , free_pos[2]);
						Jail_Log("Freeday Teleportation coordinates set for the map '%s' - X: %d, Y: %d, Z: %d", g_Mapname, free_pos[0], free_pos[1], free_pos[2]);
					}
					
					KvGoBack(MapConfig);
				}
				else
				{
					TF2Jail_SetFreedayPos(false);
					Jail_Log("Could not find subset key for 'Freeday' - 'Teleport', disabling functionality for Freeday Teleportation.");
				}
				KvGoBack(MapConfig);
			}
			else
			{
				TF2Jail_SetFreedayPos(false);
				Jail_Log("Could not find subset 'Freeday', disabling functionality for Freedays via Map.");
			}
			#endif
		}
		else
		{
			g_IsMapCompatible = false;
			TF2Jail_SetFreedayPos(false);
			Jail_Log("Map '%s' is missing from configuration file, please verify integrity of your installation.", g_Mapname);
		}
	}
	else
	{
		g_IsMapCompatible = false;
		TF2Jail_SetFreedayPos(false);
		Jail_Log("Configuration file is invalid or not found, please verify integrity of your installation.");
	}
	
	Jail_Log("Map configuration for '%s' has been successfully parsed and loaded.", g_Mapname);
	CloseHandle(MapConfig);
}

EmptyWeaponSlots(client)
{
	switch(TF2_GetPlayerClass(client))
	{
	case TFClass_DemoMan, TFClass_Engineer, TFClass_Medic, TFClass_Scout, TFClass_Soldier, TFClass_Spy:
		{
			SetClip(client, 0, 0);
		}
	}
	
	SetClip(client, 1, 0);
	SetAmmo(client, 0, 0);
	SetAmmo(client, 1, 0);
	
	decl String:szClassName[64];
	GetEntityClassname(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), szClassName, sizeof(szClassName));
	if (StrEqual(szClassName, "tf_weapon_compound_bow"))
	{
		SetClip(client, 0, 0);
	}

	TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
	TF2_RemoveWeaponSlot(client, 3);
	TF2_RemoveWeaponSlot(client, 4);
	TF2_RemoveWeaponSlot(client, 5);
	CPrintToChat(client, "%s %t", JTAG_COLORED, "stripped weapons and ammo");
}

Jail_Log(const String:format[], any:...)
{
	decl String:buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);
	
	switch (cv_Logging)
	{
	case 1: LogMessage("%s", buffer);
	case 2:
		{
			decl String:Date[20];
			FormatTime(Date, sizeof(Date), "%Y-%m-%d", GetTime());
			
			decl String:path[PLATFORM_MAX_PATH], String:path_final[PLATFORM_MAX_PATH];
			Format(path, sizeof(path), "logs/TF2Jail_%s.log", Date);
			BuildPath(Path_SM, path_final, sizeof(path_final), path);
			LogToFileEx(path_final, "%s", buffer);
		}
	}
	
	if (cv_ConsoleSpew)
	{
		PrintToConsoleAll("%s %s", JTAG, buffer);
	}
}

DoorHandler(DoorMode:status)
{
	if (!StrEqual(GCellNames, ""))
	{
		for (new i = 0; i < sizeof(DoorList); i++)
		{
			new String:buffer[60], ent = -1;
			while((ent = FindEntityByClassnameSafe(ent, DoorList[i])) != -1)
			{
				GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));
				if (StrEqual(buffer, GCellNames, false))
				{
					switch (status)
					{
					case OPEN: AcceptEntityInput(ent, "Open");
					case CLOSE: AcceptEntityInput(ent, "Close");
					case LOCK: AcceptEntityInput(ent, "Lock");
					case UNLOCK: AcceptEntityInput(ent, "Unlock");
					}
				}
			}
		}
		switch (status)
		{
		case OPEN:
			{
				if (g_CellsOpened)
				{
					CPrintToChatAll("%s %t", JTAG_COLORED, "doors manual open");
					g_CellsOpened = false;
				}
				else
				{
					CPrintToChatAll("%s %t", JTAG_COLORED, "doors opened");
				}
			}
		case CLOSE: CPrintToChatAll("%s %t", JTAG_COLORED, "doors closed");
		case LOCK: CPrintToChatAll("%s %t", JTAG_COLORED, "doors locked");
		case UNLOCK: CPrintToChatAll("%s %t", JTAG_COLORED, "doors unlocked");
		}
	}
}

FindRandomWarden()
{
	if (cv_WardenAuto)
	{
		new client = Client_GetRandom(CLIENTFILTER_TEAMTWO|CLIENTFILTER_ALIVE|CLIENTFILTER_NOBOTS);
		if (IsValidClient(client))
		{
			if (cv_PrefStatus)
			{
				if (g_bRolePreference_Warden[client])
				{
					WardenSet(client);
					Jail_Log("%N has been set to warden automatically at the start of this arena round.", client);
				}
				else
				{
					Jail_Log("%N has preferred settings set to Prisoner only.", client);
					FindRandomWarden();
				}
			}
			else
			{
				WardenSet(client);
				Jail_Log("%N has been set to warden automatically at the start of this arena round.", client);
			}
		}
	}
}

public TF2Jail_Preferences(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	switch (action)
	{
	case CookieMenuAction_SelectOption:
		{
			PreferenceMenu(client);
		}
	}
}

PreferenceMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Preferences);
	SetMenuTitle(hMenu, "TF2Jail Preferences");
	
	decl String:sValue[64];
	Format(sValue, sizeof(sValue), "%s", g_bRolePreference_Blue[client] ? "Blue Preference [OFF]" : "Blue Preference [ON]");
	AddMenuItem(hMenu, "Pref_Blue", sValue, cv_PrefBlue ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	Format(sValue, sizeof(sValue), "%s", g_bRolePreference_Warden[client] ? "Warden Preference [OFF]" : "Warden Preference [ON]");
	AddMenuItem(hMenu, "Pref_Warden", sValue, cv_PrefWarden ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	DisplayMenu(hMenu, client, 0);
}

public MenuHandle_Preferences(Handle:hMenu, MenuAction:action, client, item)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			new String:info[64];
			GetMenuItem(hMenu, item, info, sizeof(info));
			
			if (StrEqual(info, "Pref_Blue"))
			{
				if (cv_PrefBlue)
				{
					if (!g_bRolePreference_Blue[client])
					{
						SetClientCookie(client, g_hRolePref_Blue, "0");
						g_bRolePreference_Blue[client] = true;
						CPrintToChat(client, "%s %t", JTAG_COLORED, "preference blue off");
					}
					else
					{
						SetClientCookie(client, g_hRolePref_Blue, "1");
						g_bRolePreference_Blue[client] = false;
						CPrintToChat(client, "%s %t", JTAG_COLORED, "preference blue on");
					}
				}
			}
			else if (StrEqual(info, "Pref_Warden"))
			{
				if (cv_PrefWarden)
				{
					if (!g_bRolePreference_Warden[client])
					{
						SetClientCookie(client, g_hRolePref_Warden, "1");
						g_bRolePreference_Warden[client] = true;
						CPrintToChat(client, "%s %t", JTAG_COLORED, "preference warden off");
					}
					else
					{
						SetClientCookie(client, g_hRolePref_Warden, "0");
						g_bRolePreference_Warden[client] = false;
						CPrintToChat(client, "%s %t", JTAG_COLORED, "preference warden on");
					}
				}
			}
			PreferenceMenu(client);
		}
	case MenuAction_End:
		{
			CloseHandle(hMenu);
		}
	}
}

StartAdvertisement() hTimer_Advertisement = CreateTimer(120.0, TimerAdvertisement, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

IsVIP(client)
{
	if (CheckCommandAccess(client, "TF2Jail_VIP", ADMFLAG_GENERIC)) return true;
	return false;
}

/* Timers ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
public Action:UnmuteReds(Handle:hTimer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == _:TFTeam_Red)
		{
			UnmutePlayer(i);
		}
	}
	CPrintToChatAll("%s %t", JTAG_COLORED, "red team unmuted");
	Jail_Log("All players have been unmuted.");
}

public Action:Open_Doors(Handle:hTimer)
{
	hTimer_OpenCells = INVALID_HANDLE;
	if (g_CellsOpened)
	{
		DoorHandler(OPEN);
		new time = RoundFloat(cv_DoorOpenTimer);
		CPrintToChatAll("%s %t", JTAG_COLORED, "cell doors open end", time);
		g_CellsOpened = false;
		Jail_Log("Doors have been automatically opened by a timer.");
	}
}

public Action:TimerAdvertisement (Handle:hTimer)
{
	CPrintToChatAll("%s %t", JTAG_COLORED, "plugin advertisement");
	return Plugin_Continue;
}

public Action:Timer_Welcome(Handle:hTimer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (cv_Enabled && IsValidClient(client))
	{
		CPrintToChat(client, "%s %t", JTAG_COLORED, "welcome message");
	}
}

public Action:ManageWeapons(Handle:hTimer, any:userid)
{
	new client = GetClientOfUserId(userid);
	switch (GetClientTeam(client))
	{
	case TFTeam_Red:
		{
			if (cv_Enabled && cv_RedMelee)
			{
				EmptyWeaponSlots(client);
			}
		}
	}
}

public Action:BanClientTimerFreekiller(Handle:hTimer, Handle:hPack)
{
	hTimer_FreekillingData = INVALID_HANDLE;
	
	ResetPack(hPack);
	new client = ReadPackCell(hPack);
	new userid = ReadPackCell(hPack);
	new String:sAuth[24];
	ReadPackString(hPack, sAuth, sizeof(sAuth));
	
	if (IsValidClient(client))
	{
		switch (cv_FreekillersAction)
		{
		case 0:
			{
				g_IsFreekiller[client] = false;
				TF2_RegeneratePlayer(client);
				ServerCommand("sm_beacon #%d", GetClientUserId(client));
			}
		case 1:
			{
				ForcePlayerSuicide(client);
				g_IsFreekiller[client] = false;
			}
		case 2:
			{
				if (IsValidClient(userid))
				{
					if (e_sourcebans)
					{
						SBBanPlayer(0, userid, 60, "Client has been marked for Freekilling.");
						Jail_Log("Client %N has been banned via Sourcebans for being marked as a Freekiller.", userid);
					}
					else
					{
						BanClient(userid, cv_FreekillersBantime, BANFLAG_AUTHID, "Client has been marked for Freekilling.", BanMsg, "freekillban", userid);
						Jail_Log("Client %N has been banned for being marked as a Freekiller.", userid);
					}
				}
				else
				{
					if (cv_FreekillersAction == 2)
					{
						GetConVarString(JB_ConVars[38], BanMsgDC, sizeof(BanMsgDC));
						BanIdentity(sAuth, cv_FreekillersBantimeDC, BANFLAG_AUTHID, BanMsgDC);
						Jail_Log("%N has been banned via identity.", BANFLAG_AUTHID);
					}
				}
			}
		}
	}
	else
	{
		if (cv_FreekillersAction == 2)
		{
			GetConVarString(JB_ConVars[38], BanMsgDC, sizeof(BanMsgDC));
			BanIdentity(sAuth, cv_FreekillersBantimeDC, BANFLAG_AUTHID, BanMsgDC);
			Jail_Log("%N has been banned via identity.", BANFLAG_AUTHID);
		}
	}
}

public Action:EnableFFTimer(Handle:hTimer)
{
	hTimer_FriendlyFireEnable = INVALID_HANDLE;
	SetConVarBool(JB_EngineConVars[0], true);
}

public Action:DisableWarden(Handle:hTimer)
{
	hTimer_WardenLock = INVALID_HANDLE;
	if (g_bActiveRound)
	{
		CPrintToChatAll("%s %t", JTAG_COLORED, "warden locked timer");
		g_bIsWardenLocked = true;
	}
}

public Action:ExecuteServerCommand(Handle:timer, Handle:dp)
{
	if (dp != INVALID_HANDLE)
	{
		new String:buffer[64];
		ResetPack(dp);
		ReadPackString(dp, buffer, sizeof(buffer));
		ServerCommand(buffer);
	}
}

/* Group Functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
public bool:WardenGroup(const String:strPattern[], Handle:hClients)
{
	for (new i = 1; i <= MaxClients; i ++)
	{
		if (IsValidClient(i) && Warden != -1 && IsWarden(i))
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

public bool:NotWardenGroup(const String:strPattern[], Handle:hClients)
{
	for (new i = 1; i <= MaxClients; i ++)
	{
		if (IsValidClient(i) && Warden != -1 && !IsWarden(i))
		{
			PushArrayCell(hClients, i);
		}
	}
	return true;
}

/* Native Functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
public Native_ExistWarden(Handle:plugin, numParams)
{
	if (!cv_Enabled || !cv_Warden)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Warden System is disabled");
	}
	
	if (Warden != -1) return true;
	return false;
}

public Native_IsWarden(Handle:plugin, numParams)
{
	if (!cv_Enabled || !cv_Warden)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Warden System is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (IsWarden(client)) return true;
	return false;
}

public Native_SetWarden(Handle:plugin, numParams)
{
	if (!cv_Enabled || !cv_Warden)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Warden System is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (Warden != -1)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Warden is currently in use, cannot execute native function.");
	}
	else
	{
		if (cv_PrefStatus && g_bRolePreference_Warden[client])
		{
			ThrowNativeError(SP_ERROR_INDEX, "Client index %i has their preference set to prisoner only.", client);
		}

		WardenSet(client);
	}
}

public Native_RemoveWarden(Handle:plugin, numParams)
{
	if (!cv_Enabled || !cv_Warden)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Warden System is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (IsWarden(client))
	{
		WardenUnset(client);
	}
	else
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is currently not Warden.", client);
	}
}

public Native_IsFreekiller(Handle:plugin, numParams)
{
	if (!cv_Enabled || !cv_Freekillers)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Anti-Freekill System is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (g_IsFreekiller[client]) return true;
	return false;
}

public Native_MarkFreekill(Handle:plugin, numParams)
{
	if (!cv_Enabled || !cv_Freekillers)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin or Anti-Freekill System is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (!g_IsFreekiller[client])
	{
		MarkFreekiller(client);
	}
	else
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is already marked as a Freekiller.", client);
	}
}

public Native_StripToMelee(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (IsPlayerAlive(client))
	{
		CreateTimer(0.1, ManageWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is currently not alive to strip ammo.", client);
	}
}

public Native_StripAllWeapons(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}

	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (IsPlayerAlive(client))
	{
		StripToMelee(client);
	}
	else
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is currently not alive to strip weapons.", client);
	}
}

public Native_LockWarden(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	
	g_bAdminLockWarden = true;
	CPrintToChatAll("%s %t", JTAG_COLORED, "warden locked natives");
	Jail_Log("Natives has locked Warden.");
}

public Native_UnlockWarden(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	
	g_bAdminLockWarden = false;
	CPrintToChatAll("%s %t", JTAG_COLORED, "warden unlocked natives");
	Jail_Log("Natives has unlocked Warden.");
}

public Native_Logging(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	
	decl String:buffer[1024], written;
	FormatNativeString(0, 1, 2, sizeof(buffer),  written, buffer);
	Jail_Log("%s", buffer);
}

public Native_IsVIP(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	
	new client = GetNativeCell(1);
	if (!IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	}
	
	if (IsVIP(client)) return true;
	return false;
}

public Native_ServerCommand(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	
	new len;
	GetNativeStringLength(1, len);

	if (len <= 0)
	{
		return;
	}

	new String:ServerCommands[len + 1];
	GetNativeString(1, ServerCommands, len + 1);

	new Handle:dp;
	CreateDataTimer(0.5, ExecuteServerCommand, dp);
	WritePackString(dp, ServerCommands);
}

public Native_ControlDoors(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	DoorHandler(GetNativeCell(1));
}

public Native_VoidFreekills(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	g_VoidFreekills = GetNativeCell(1);
}

public Native_StartFFTimer(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	
	new Float:Timer = Float:GetNativeCell(1);
	hTimer_FriendlyFireEnable = CreateTimer(Timer, EnableFFTimer, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
}

public Native_GetWarden(Handle:plugin, numParams)
{
	if (!cv_Enabled)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Plugin is disabled");
	}
	
	if (Warden != -1)
	{
		return Warden;
	}
	else
	{
		ThrowNativeError(SP_ERROR_INDEX, "Warden does not exist.");
		return -1;
	}
}
/* Plugin End ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/