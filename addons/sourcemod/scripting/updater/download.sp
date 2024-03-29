
/* Download Manager */
#include "updater/download_steamworks.sp"

DataPackPos QueuePack_URL = view_as<DataPackPos>(0);

FinalizeDownload(index)
{
	/* Strip the temporary file extension from downloaded files. */
	decl String:newpath[PLATFORM_MAX_PATH], String:oldpath[PLATFORM_MAX_PATH];
	new Handle:hFiles = Updater_GetFiles(index);
	
	new maxFiles = GetArraySize(hFiles);
	for (new i = 0; i < maxFiles; i++)
	{
		GetArrayString(hFiles, i, newpath, sizeof(newpath));
		Format(oldpath, sizeof(oldpath), "%s.%s", newpath, TEMP_FILE_EXT);
		
		// Rename doesn't overwrite on Windows. Make sure the path is clear.
		if (FileExists(newpath))
		{
			DeleteFile(newpath);
		}
		
		RenameFile(newpath, oldpath);
	}
	
	ClearArray(hFiles);
}

AbortDownload(index)
{
	/* Delete all downloaded temporary files. */
	decl String:path[PLATFORM_MAX_PATH];
	new Handle:hFiles = Updater_GetFiles(index);
	
	new maxFiles = GetArraySize(hFiles);
	for (new i = 0; i < maxFiles; i++)
	{
		GetArrayString(hFiles, 0, path, sizeof(path));
		Format(path, sizeof(path), "%s.%s", path, TEMP_FILE_EXT);
		
		if (FileExists(path))
		{
			DeleteFile(path);
		}
	}
	
	ClearArray(hFiles);
}

ProcessDownloadQueue(bool:force=false)
{
	if (!force && (g_bDownloading || !GetArraySize(g_hDownloadQueue)))
	{
		return;
	}
	
	DataPack dQueuePack = view_as<DataPack>(GetArrayCell(g_hDownloadQueue, 0));
	dQueuePack.Position = QueuePack_URL;
	
	decl String:url[MAX_URL_LENGTH], String:dest[PLATFORM_MAX_PATH];
	dQueuePack.ReadString(url, sizeof(url));
	dQueuePack.ReadString(dest, sizeof(dest));
	
	if (!STEAMWORKS_AVAILABLE())
	{
		SetFailState(EXTENSION_ERROR);
	}
	
#if defined DEBUG
	Updater_DebugLog("Download started:");
	Updater_DebugLog("  [0]  URL: %s", url);
	Updater_DebugLog("  [1]  Destination: %s", dest);
#endif
	
	g_bDownloading = true;
	
	if (STEAMWORKS_AVAILABLE())
	{
		if (SteamWorks_IsLoaded())
		{
			Download_SteamWorks(url, dest);
		}
		else
		{
			CreateTimer(10.0, Timer_RetryQueue);
		}
	}
}

public Action:Timer_RetryQueue(Handle:timer)
{
	ProcessDownloadQueue(true);
	
	return Plugin_Stop;
}

AddToDownloadQueue(index, const String:url[], const String:dest[])
{
	DataPack dQueuePack = new DataPack();
	dQueuePack.WriteCell(index);
	
	QueuePack_URL = dQueuePack.Position;
	dQueuePack.WriteString(url);
	dQueuePack.WriteString(dest);
	
	PushArrayCell(g_hDownloadQueue, dQueuePack);
	
	ProcessDownloadQueue();
}

DownloadEnded(bool:successful, const String:error[]="")
{
	DataPack dQueuePack = view_as<DataPack>(GetArrayCell(g_hDownloadQueue, 0));
	dQueuePack.Reset();
	
	decl String:url[MAX_URL_LENGTH], String:dest[PLATFORM_MAX_PATH];
	new index = dQueuePack.ReadCell();
	dQueuePack.ReadString(url, sizeof(url));
	dQueuePack.ReadString(dest, sizeof(dest));
	
	// Remove from the queue.
	delete dQueuePack;
	RemoveFromArray(g_hDownloadQueue, 0);
	
#if defined DEBUG
	Updater_DebugLog("  [2]  Successful: %s", successful ? "Yes" : "No");
#endif
	
	switch (Updater_GetStatus(index))
	{
		case Status_Checking:
		{
			if (!successful || !ParseUpdateFile(index, dest))
			{
				Updater_SetStatus(index, Status_Idle);
				
#if defined DEBUG
				if (error[0] != '\0')
				{
					Updater_DebugLog("  [2]  %s", error);
				}
#endif
			}
		}
		
		case Status_Downloading:
		{
			if (successful)
			{
				// Check if this was the last file we needed.
				decl String:lastfile[PLATFORM_MAX_PATH];
				new Handle:hFiles = Updater_GetFiles(index);
				
				GetArrayString(hFiles, GetArraySize(hFiles) - 1, lastfile, sizeof(lastfile));
				Format(lastfile, sizeof(lastfile), "%s.%s", lastfile, TEMP_FILE_EXT);
				
				if (StrEqual(dest, lastfile))
				{
					new Handle:hPlugin = IndexToPlugin(index);
					
					Fwd_OnPluginUpdating(hPlugin);
					FinalizeDownload(index);
					
					decl String:sName[64];
					if (!GetPluginInfo(hPlugin, PlInfo_Name, sName, sizeof(sName)))
					{
						strcopy(sName, sizeof(sName), "Null");
					}
					
					Updater_Log("Successfully updated and installed \"%s\".", sName);
					
					Updater_SetStatus(index, Status_Updated);
					Fwd_OnPluginUpdated(hPlugin);
				}
			}
			else
			{
				// Failed during an update.
				AbortDownload(index);
				Updater_SetStatus(index, Status_Error);
				
				decl String:filename[64];
				GetPluginFilename(IndexToPlugin(index), filename, sizeof(filename));
				Updater_Log("Error downloading update for plugin: %s", filename);
				Updater_Log("  [0]  URL: %s", url);
				Updater_Log("  [1]  Destination: %s", dest);
				
				if (error[0] != '\0')
				{
					Updater_Log("  [2]  %s", error);
				}
			}
		}
		
		case Status_Error:
		{
			// Delete any additional files that this plugin had queued.
			if (successful && FileExists(dest))
			{
				DeleteFile(dest);
			}
		}
	}
	
	g_bDownloading = false;
	ProcessDownloadQueue();
}
