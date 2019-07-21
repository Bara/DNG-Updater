#include <sourcemod>
#include <updater>

public Plugin:myinfo =
{
	name = "Updater - Test",
	author = "Bara",
	version = "1.0.1",
	description = "",
	url = "dng.xyz"
};

public void OnPluginStart()
{
    LogMessage("Test 2");
    AddPluginToUpdater("test");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater", false))
    {
        AddPluginToUpdater("test");
    }
}

void AddPluginToUpdater(const char[] name)
{
    if (!LibraryExists("updater"))
    {
        return;
    }

    char sURL[128];
    Format(sURL, sizeof(sURL), "https://update.dng.xyz/xrt8gANDP8QZ/%s/update.txt", name);

    Updater_AddPlugin(sURL);
    Updater_ForceUpdate();
}
