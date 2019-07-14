
/* PluginPack Helpers */

DataPackPos PluginPack_Plugin = view_as<DataPackPos>(0);
DataPackPos PluginPack_Files = view_as<DataPackPos>(0);
DataPackPos PluginPack_Status = view_as<DataPackPos>(0);
DataPackPos PluginPack_URL = view_as<DataPackPos>(0);

GetMaxPlugins()
{
	return GetArraySize(g_hPluginPacks);
}

bool:IsValidPlugin(Handle:plugin)
{
	/* Check if the plugin handle is pointing to a valid plugin. */
	new Handle:hIterator = GetPluginIterator();
	new bool:bIsValid = false;
	
	while (MorePlugins(hIterator))
	{
		if (plugin == ReadPlugin(hIterator))
		{
			bIsValid = true;
			break;
		}
	}
	
	CloseHandle(hIterator);
	return bIsValid;
}

PluginToIndex(Handle:plugin)
{
	DataPack dPluginPack = null;
	
	new maxPlugins = GetMaxPlugins();
	for (new i = 0; i < maxPlugins; i++)
	{
		dPluginPack = view_as<DataPack>(GetArrayCell(g_hPluginPacks, i));
		dPluginPack.Position = PluginPack_Plugin;
		
		if (plugin == view_as<Handle>(dPluginPack.ReadCell()))
		{
			return i;
		}
	}
	
	return -1;
}

Handle:IndexToPlugin(index)
{
	DataPack dPluginPack = view_as<DataPack>(GetArrayCell(g_hPluginPacks, index));
	dPluginPack.Position = PluginPack_Plugin;
	return view_as<Handle>(dPluginPack.ReadCell());
}

Updater_AddPlugin(Handle:plugin, const String:url[])
{	
	new index = PluginToIndex(plugin);
	
	if (index != -1)
	{
		// Remove plugin from removal queue.
		new maxPlugins = GetArraySize(g_hRemoveQueue);
		for (new i = 0; i < maxPlugins; i++)
		{
			if (plugin == GetArrayCell(g_hRemoveQueue, i))
			{
				RemoveFromArray(g_hRemoveQueue, i);
				break;
			}
		}
		
		// Update the url.
		Updater_SetURL(index, url);
	}
	else
	{
		DataPack dPluginPack = new DataPack();
		new Handle:hFiles = CreateArray(PLATFORM_MAX_PATH);
		
		PluginPack_Plugin = dPluginPack.Position;
		dPluginPack.WriteCell(_:plugin);
		
		PluginPack_Files = dPluginPack.Position;
		dPluginPack.WriteCell(_:hFiles);
		
		PluginPack_Status = dPluginPack.Position;
		dPluginPack.WriteCell(_:Status_Idle);
		
		PluginPack_URL = dPluginPack.Position;
		dPluginPack.WriteString(url);
		
		PushArrayCell(g_hPluginPacks, dPluginPack);
	}
}

Updater_QueueRemovePlugin(Handle:plugin)
{
	/* Flag a plugin for removal. */
	new maxPlugins = GetArraySize(g_hRemoveQueue);
	for (new i = 0; i < maxPlugins; i++)
	{
		// Make sure it wasn't previously flagged.
		if (plugin == GetArrayCell(g_hRemoveQueue, i))
		{
			return;
		}
	}
	
	PushArrayCell(g_hRemoveQueue, plugin);
	Updater_FreeMemory();
}

Updater_RemovePlugin(index)
{
	/* Warning: Removing a plugin will shift indexes. */
	CloseHandle(Updater_GetFiles(index)); // hFiles
	CloseHandle(GetArrayCell(g_hPluginPacks, index)); // hPluginPack
	RemoveFromArray(g_hPluginPacks, index);
}

Handle:Updater_GetFiles(index)
{
	DataPack dPluginPack = view_as<DataPack>(GetArrayCell(g_hPluginPacks, index));
	dPluginPack.Position = PluginPack_Files;
	return view_as<Handle>(dPluginPack.ReadCell());
}

UpdateStatus:Updater_GetStatus(index)
{
	DataPack dPluginPack = view_as<DataPack>(GetArrayCell(g_hPluginPacks, index));
	dPluginPack.Position = PluginPack_Status;
	return view_as<UpdateStatus>(dPluginPack.ReadCell());
}

Updater_SetStatus(index, UpdateStatus:status)
{
	DataPack dPluginPack = view_as<DataPack>(GetArrayCell(g_hPluginPacks, index));
	dPluginPack.Position = PluginPack_Status;
	dPluginPack.WriteCell(_:status);
}

Updater_GetURL(index, String:buffer[], size)
{
	DataPack dPluginPack = view_as<DataPack>(GetArrayCell(g_hPluginPacks, index));
	dPluginPack.Position = PluginPack_URL;
	dPluginPack.ReadString(buffer, size);
}

Updater_SetURL(index, const String:url[])
{
	DataPack dPluginPack = view_as<DataPack>(GetArrayCell(g_hPluginPacks, index));
	dPluginPack.Position = PluginPack_URL;
	dPluginPack.WriteString(url);
}

/* Stocks */
stock ReloadPlugin(Handle:plugin=INVALID_HANDLE)
{
	decl String:filename[64];
	GetPluginFilename(plugin, filename, sizeof(filename));
	ServerCommand("sm plugins reload %s", filename);
}

stock UnloadPlugin(Handle:plugin=INVALID_HANDLE)
{
	decl String:filename[64];
	GetPluginFilename(plugin, filename, sizeof(filename));
	ServerCommand("sm plugins unload %s", filename);
}

stock DisablePlugin(Handle:plugin=INVALID_HANDLE)
{
	decl String:filename[64] String:path_disabled[PLATFORM_MAX_PATH], String:path_plugin[PLATFORM_MAX_PATH];
	
	GetPluginFilename(plugin, filename, sizeof(filename));
	BuildPath(Path_SM, path_disabled, sizeof(path_disabled), "plugins/disabled/%s", filename);
	BuildPath(Path_SM, path_plugin, sizeof(path_plugin), "plugins/%s", filename);
	
	if (FileExists(path_disabled))
	{
		DeleteFile(path_disabled);
	}
	
	if (!RenameFile(path_disabled, path_plugin))
	{
		DeleteFile(path_plugin);
	}
	
	ServerCommand("sm plugins unload %s", filename);
}
