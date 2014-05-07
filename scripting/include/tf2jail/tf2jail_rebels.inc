#if defined _tf2jail_rebels_included
#endinput
#endif
#define _tf2jail_rebels_included

//Natives
/**
 * Returns if the client is a Rebel.
 *
 * @param client		Client is Rebel.
 * @return		True on success, false on failure.
 **/
native TF2Jail_IsRebel(client);

/**
 * Marks a client as a Rebel.
 *
 * @param client		Client to mark Rebel.
 * @noreturn
 **/
native TF2Jail_MarkRebel(client);

//Forwards

public SharedPlugin:__pl_tf2jail_rebels =
{
	name = "TF2Jail_Rebels",
	file = "TF2Jail_Rebels.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if defined REQUIRE_PLUGIN
public __pl_tf2jail_rebels_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Jail_IsRebel");
	MarkNativeAsOptional("TF2Jail_MarkRebel");
}
#endif