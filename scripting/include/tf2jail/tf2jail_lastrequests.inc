#if defined _tf2jail_lastrequests_included
#endinput
#endif
#define _tf2jail_lastrequests_included

//Natives
/**
 * Returns if the client is a Freeday.
 *
 * @param client		Client is Freeday.
 * @return		True on success, false on failure.
 **/
native TF2Jail_IsFreeday(client);

/**
 * Sets a client to Freeday.
 *
 * @param client		Client to give Freeday.
 * @noreturn
 **/
native TF2Jail_GiveFreeday(client);

/**
 * Sets status/positions for Freeday teleports.
 *
 * @param status		Status for teleporting freedays via configs. (INT)
 * @param X				X-coordinates for teleporting. (FLOAT)
 * @param Y				Y-coordinates for teleporting. (FLOAT)
 * @param Z				Z-coordinates for teleporting. (FLOAT)
 * @return		True on success, false on failure.
 **/
native TF2Jail_SetFreedayPos(status, Float:X = 0.0, Float:Y = 0.0, Float:Z = 0.0);

/**
 * Returns if the current round is a Last Request day.
 *
 * @return		True on success, false on failure.
 **/
native TF2Jail_IsLRRound();

/**
 * Retrieves the ConVar if Warden should be locked during Last Request.
 *
 * @return		True on success, false on failure.
 **/
native TF2Jail_LockWardenLR();

//Forwards
/**
 * Called when the Warden has been removed/retired via the plugin or natives.
 *
 * @param Handler		String to check/match the handler tied to the Last Request in the config. (maximum is 32 characters)
 * @noreturn
 **/
forward TF2Jail_OnLastRequestExecute(const String:Handler[]);

public SharedPlugin:__pl_tf2jail_lastrequests =
{
	name = "TF2Jail_LastRequests",
	file = "TF2Jail_LastRequests.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public __pl_tf2jail_lastrequests_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail_IsFreeday");
	MarkNativeAsOptional("TF2Jail_GiveFreeday");
	MarkNativeAsOptional("TF2Jail_IsLRRound");
	MarkNativeAsOptional("TF2Jail_LockWardenLR");
	MarkNativeAsOptional("TF2Jail_SetFreedayPos");
}
#endif