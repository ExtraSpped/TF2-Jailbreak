#if defined _tf2jail_core_included
#endinput
#endif
#define _tf2jail_core_included

#define JTAG_COLORED	"{community}[TF2Jail]"
#define JTAG	"[TF2Jail]"
#define PLUGIN_VERSION	"5.3.0"	//ONE VERSION FOR ALL!

enum DoorMode	//Enum struct to handle door controls.
{
	OPEN = 0,
	CLOSE,
	LOCK,
	UNLOCK
};

//Natives
/**
 * Warden Check if exists.
 *
 * @return		True on success, false on failure.
 **/
native TF2Jail_WardenActive();

/**
 * Returns if client is Warden.
 *
 * @param client		Client is Warden.
 * @return		True on success, false on failure.
 **/
native TF2Jail_IsWarden(client);

/**
 * Sets a client to Warden.
 *
 * @param client		Client to become Warden.
 * @noreturn
 **/
native TF2Jail_WardenSet(client);

/**
 * Remove the Warden if there is one.
 *
 * @param client		Client to remove Warden.
 * @noreturn
 **/
native TF2Jail_WardenUnset(client);

/**
 * Returns if the cilent is a Freekiller.
 *
 * @param client		Client is Freekiller.
 * @return		True on success, false on failure.
 **/
native TF2Jail_IsFreekiller(client);

/**
 * Marks the client as a Freekiller.
 *
 * @param client		Client to mark Freekiller.
 * @noreturn
 **/
native TF2Jail_MarkFreekiller(client);

/**
 * Strip clients to melee while using TF2Jail Rules. (Keep Weapons, ammo = 0)
 *
 * @param client		Client to Strip to melee.
 * @noreturn
 **/
native TF2Jail_StripToMelee(client);

/**
 * Strip client to melee entirely using TF2Jail rules.
 *
 * @param client		Client to Strip entirely.
 * @noreturn
 **/
native TF2Jail_StripAllWeapons(client);

/**
 * Lock warden from being allowed.
 *
 * @noreturn
 **/
native TF2Jail_LockWarden();

/**
 * Unlock warden from being allowed.
 *
 * @noreturn
 **/
native TF2Jail_UnlockWarden();

/**
 * Log using TF2Jail's logging system/rules.
 *
 * @param log			String or text to log.
 * @param ...			Formatting parameters.
 * @noreturn
 **/
native TF2Jail_Log(const String:log[], any:...);

/**
 * Check if the client is a VIP by TF2Jail's standards.
 *
 * @param client		Client to check for VIP.
 * @return		True on success, false on failure.
 **/
native TF2Jail_IsVIP(client);

/**
 * Execute server commands via data timers using TF2Jail rules.
 *
 * @param ServerCommand		String to execute into server console. (STRING)
 * @noreturn
 **/
native TF2Jail_ServerCommand(String:ServerCommand[]);

/**
 * Control cell doors in a variety of ways!
 *
 * @param Control		String to Execute. (OPEN, CLOSE, LOCK, UNLOCK) (If doors are locked, they must be unlocked to open)
 * @noreturn
 **/
native TF2Jail_ControlDoors(DoorMode:Status);

/**
 * Enable or disable freekilling void periods. (Freekilling detections will not be acted upon during void periods)
 *
 * @param Status		True or false. (DoorMode)
 * @noreturn
 **/
native TF2Jail_VoidFreekills(bool:Status);

/**
 * Start Friendly Fire timer which ends after a number of seconds. (Is managed, resets at the end of the round, etc)
 *
 * @param Timer			Time until enabled on execution. (FLOAT) (Minimum - 0.1)
 * @noreturn
 **/
native TF2Jail_StartFFTimer(Float:Timer = 10.0);

/**
 * Retrieve the client index who is the Warden.
 *
 * @return		Client index if exists, -1 if no Warden is currently active.
 **/
native TF2Jail_GetWarden();

//Forwards
/**
 * Called when the Warden has been assigned/created via the plugin or natives.
 *
 * @noreturn
 **/
forward Warden_OnWardenCreated(client);

/**
 * Called when the Warden has been removed/retired via the plugin or natives.
 *
 * @noreturn
 **/
forward Warden_OnWardenRemoved(client);

public SharedPlugin:__pl_tf2jail_core =
{
	name = "TF2Jail_Core",
	file = "TF2Jail_Core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public __pl_tf2jail_core_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail_WardenActive");
	MarkNativeAsOptional("TF2Jail_IsWarden");
	MarkNativeAsOptional("TF2Jail_WardenSet");
	MarkNativeAsOptional("TF2Jail_WardenUnset");
	MarkNativeAsOptional("TF2Jail_IsFreekiller");
	MarkNativeAsOptional("TF2Jail_MarkFreekiller");
	MarkNativeAsOptional("TF2Jail_StripToMelee");
	MarkNativeAsOptional("TF2Jail_StripAllWeapons");
	MarkNativeAsOptional("TF2Jail_LockWarden");
	MarkNativeAsOptional("TF2Jail_UnlockWarden");
	MarkNativeAsOptional("TF2Jail_Log");
	MarkNativeAsOptional("TF2Jail_IsVIP");
	MarkNativeAsOptional("TF2Jail_ServerCommand");
	MarkNativeAsOptional("TF2Jail_ControlDoors");
	MarkNativeAsOptional("TF2Jail_VoidFreekills");
	MarkNativeAsOptional("TF2Jail_StartFFTimer");
	MarkNativeAsOptional("TF2Jail_GetWarden");
}
#endif