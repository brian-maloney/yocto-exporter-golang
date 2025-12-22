#include "yocto_wrapper.h"
#include "yocto_api.h"
#include <string.h>

extern "C" {

int yocto_RegisterHub(const char* url, char* errMsg, int errMsgSize) {
    string err;
    int res = YAPI::RegisterHub(url, err);
    if (res != YAPI::SUCCESS) {
        strncpy(errMsg, err.c_str(), errMsgSize - 1);
        errMsg[errMsgSize - 1] = '\0';
    }
    return res;
}

void yocto_FreeAPI() {
    YAPI::FreeAPI();
}

int yocto_UpdateCheck(char* errMsg, int errMsgSize) {
    string err;
    int res = YAPI::UpdateDeviceList(err);
    if (res != YAPI::SUCCESS) {
        strncpy(errMsg, err.c_str(), errMsgSize - 1);
        errMsg[errMsgSize - 1] = '\0';
    }
    return res;
}

YSensorPtr yocto_FirstSensor() {
    return (YSensorPtr)yFirstSensor();
}

YSensorPtr yocto_NextSensor(YSensorPtr sensor) {
    if (!sensor) return NULL;
    return (YSensorPtr)((YSensor*)sensor)->nextSensor();
}

int yocto_GetFunctionId(YSensorPtr sensor, char* buffer, int bufferSize) {
    if (!sensor) return -1;
    string fid = ((YSensor*)sensor)->get_functionId();
    strncpy(buffer, fid.c_str(), bufferSize - 1);
    buffer[bufferSize - 1] = '\0';
    return 0;
}

int yocto_GetUnit(YSensorPtr sensor, char* buffer, int bufferSize) {
    if (!sensor) return -1;
    string unit = ((YSensor*)sensor)->get_unit();
    strncpy(buffer, unit.c_str(), bufferSize - 1);
    buffer[bufferSize - 1] = '\0';
    return 0;
}

int yocto_GetHardwareId(YSensorPtr sensor, char* buffer, int bufferSize) {
    if (!sensor) return -1;
    string hid = ((YSensor*)sensor)->get_hardwareId();
    strncpy(buffer, hid.c_str(), bufferSize - 1);
    buffer[bufferSize - 1] = '\0';
    return 0;
}

double yocto_GetCurrentValue(YSensorPtr sensor) {
    if (!sensor) return 0.0;
    return ((YSensor*)sensor)->get_currentValue();
}

}
