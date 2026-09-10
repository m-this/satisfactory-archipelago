// Runtime check for Source/APCpp/lib/Linux.
//
// apcpp-link-check.cpp only takes the address of each entry point, so a library
// that segfaults the moment it runs still links clean. This one performs the
// call sequence AApSubsystem::ConnectToArchipelago() performs, in the same
// order, then polls the connection status the way the lifecycle does and shuts
// down. Takes the URI as argv[1] so an unreachable host and an empty string can
// both be exercised.

#include "Archipelago.h"
#include "Archipelago_Satisfactory.h"

#include <chrono>
#include <cstdio>
#include <string>
#include <thread>

int main(int argc, char** argv) {
    std::string const uri = argc > 1 ? argv[1] : "";
    std::string const user = argc > 2 ? argv[2] : "Mathis";
    std::string const password = argc > 3 ? argv[3] : "";
    int const seconds_max = argc > 4 ? std::stoi(argv[4]) : 10;

    std::printf("AP_SetClientVersion\n");
    std::fflush(stdout);
    AP_NetworkVersion version;
    version.major = 0;
    version.minor = 6;
    version.build = 0;
    AP_SetClientVersion(&version);

    std::printf("AP_Init(\"%s\", \"Satisfactory\", \"%s\", \"%s\")\n", uri.c_str(), user.c_str(), password.c_str());
    std::fflush(stdout);
    AP_Init(uri.c_str(), "Satisfactory", user.c_str(), password.c_str());

    std::printf("callbacks\n");
    std::fflush(stdout);
    AP_SetItemClearCallback([]() {});
    AP_SetItemRecvCallback([](int64_t, bool, bool) {});
    AP_SetLocationCheckedCallback([](int64_t) {});
    AP_SetLocationInfoCallback([](std::vector<AP_NetworkItem>) {});
    AP_SetLoggingCallback([](std::string message) {
        std::printf("  LogFromAPCpp: %s\n", message.c_str());
        std::fflush(stdout);
    });
    AP_RegisterBouncedCallback([](AP_Bounce) {});
    AP_SetPackageReceivedCallback([](std::string) {});
    AP_SetGiftingSupported(false);

    std::printf("AP_Start\n");
    std::fflush(stdout);
    AP_Start();

    for (int second = 0; second < seconds_max; ++second) {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        AP_ConnectionStatus const status = AP_GetConnectionStatus();
        std::printf("  t+%.1fs status=%d\n", (second + 1) * 0.5, static_cast<int>(status));
        std::fflush(stdout);
        if (status == AP_ConnectionStatus::Authenticated)
            break;
    }

    std::printf("AP_Shutdown\n");
    std::fflush(stdout);
    AP_Shutdown();

    std::printf("clean exit\n");
    return 0;
}
