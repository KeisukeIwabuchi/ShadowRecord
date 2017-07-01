# ShadowRecord
Create and manage virtual trade records.


## Install
1. Download ShadowRecord.mqh
2. Save the file to MQL4/Include/mql4_modules/ShadowRecord/ShadowRecord.mqh


## How to use
```cpp
#include <mql4_modules/ShadowRecord/ShadowRecord.mqh>

ShadowRecord *RS;

int OnInit()
{
   SR = new ShadowRecord();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  delete(SR);
}

void OnTick()
{
  SR.Tick();
}
```
