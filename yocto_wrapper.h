#ifndef YOCTO_WRAPPER_H
#define YOCTO_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void* YSensorPtr;

int yocto_RegisterHub(const char* url, char* errMsg, int errMsgSize);
void yocto_FreeAPI();
int yocto_UpdateCheck(char* errMsg, int errMsgSize);

YSensorPtr yocto_FirstSensor();
YSensorPtr yocto_NextSensor(YSensorPtr sensor);

int yocto_GetFunctionId(YSensorPtr sensor, char* buffer, int bufferSize);
int yocto_GetUnit(YSensorPtr sensor, char* buffer, int bufferSize);
int yocto_GetHardwareId(YSensorPtr sensor, char* buffer, int bufferSize);
double yocto_GetCurrentValue(YSensorPtr sensor);

#ifdef __cplusplus
}
#endif

#endif
