// Link check for Source/APCpp/lib/Linux.
//
// Every AP_ function Source/Archipelago calls is referenced here and compiled
// against Source/APCpp/inc, so linking this proves the staged Linux archives
// satisfy the mod without needing the engine. Add a line when the mod starts
// calling something new.

#include "Archipelago.h"
#include "Archipelago_Satisfactory.h"

static volatile void* sink;

template <typename T>
static void use(T fn) {
    sink = reinterpret_cast<void*>(fn);
}

int main() {
    use(&AP_ClearLatestMessage);
    use(&AP_EnabledDeathlinkAnyway);
    use(&AP_GetAllLocations);
    use(&AP_GetAllPlayers);
    use(&AP_GetConnectionStatus);
    use(&AP_GetCurrentPlayerTeam);
    use(&AP_GetItemName);
    use(&AP_GetLatestMessage);
    use(&AP_GetPlayerID);
    use(&AP_GetRoomInfo);
    use(&AP_GetSlotData);
    use(static_cast<void(*)(const char*, const char*, const char*, const char*)>(&AP_Init));
    use(static_cast<void(*)(const char*)>(&AP_Init));
    use(&AP_IsMessagePending);
    use(&AP_RegisterBouncedCallback);
    use(&AP_Say);
    use(&AP_Send);
    use(&AP_SendBounce);
    use(static_cast<void(*)(int64_t)>(&AP_SendItem));
    use(static_cast<void(*)(std::set<int64_t> const&)>(&AP_SendItem));
    use(&AP_SendLocationScouts);
    use(&AP_SetClientVersion);
    use(&AP_SetGiftingSupported);
    use(&AP_SetItemClearCallback);
    use(&AP_SetItemRecvCallback);
    use(&AP_SetLocationCheckedCallback);
    use(&AP_SetLocationInfoCallback);
    use(&AP_SetLoggingCallback);
    use(&AP_SetPackageReceivedCallback);
    use(&AP_Shutdown);
    use(&AP_Start);
    use(&AP_StoryComplete);

    return 0;
}
