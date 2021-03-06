//+------------------------------------------------------------------+
//|                                                 ShadowRecord.mqh |
//|                                 Copyright 2017, Keisuke Iwabuchi |
//|                                        https://order-button.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Keisuke Iwabuchi"
#property link      "https://order-button.com/"
#property strict


#ifndef _LOAD_MODULE_SHADOW_RECORD
#define _LOAD_MODULE_SHADOW_RECORD


/** Create and manage virtual trade records. */
class ShadowRecord
{
   // variables and structures
   protected:
      /** @var int error_code  Latest Error code. */
      int error_code;
      
      /** @var int record_count  Total number of orders. */
      int record_count;
      
      /** 
       * @var int select_element  Index of the currentry selected order.
       */
      int select_element;
      
      /**
       * @var bool show_arrw  Display arrows on charts 
       *                      when virtual trading.
       */
      bool show_arrow;
      
      /** @var string record_file_name  Save file name. */
      string record_file_name;
   
      /** Data about the trading order. */
      struct Record {
         int      ticket;
         bool     valid;
         bool     open;
         datetime open_time;
         datetime close_time;
         uchar    symbol[10];
         int      cmd;
         double   volume;
         double   open_price;
         double   close_price;
         double   stoploss;
         double   takeprofit;
         int      magic;
         datetime expiration;
      };
   
   public:
      /** @var Record records[]  Array that keep records. */
      Record records[];
   
   
   // methods
   protected:
      void CheckCloseRecords(const int shift = 0);
      void CheckExpirationRecords(const int shift = 0);
      void CheckOpenRecords(const int shift = 0);
      int  GetElement(const int ticket);

   public:
      ShadowRecord(void);
      ~ShadowRecord(void);
      
      void     ArrowCreate(const int   id, 
                           const int   type, 
                           const color arrow_color
                           );
      void     ArrowDelete(const int id);
      int      GetLastErrorRecord(void);
      int      GetRecordCount(void);
      bool     Load(string file=NULL);
      string   PeriodToString(int period);
      bool     RecordClose(const int    ticket, 
                                 double lots, 
                           const double price, 
                           const int    slippage, 
                           const color  arrow_color=clrNONE
                           );
      double   RecordClosePrice(void);
      datetime RecordCloseTime(void);
      double   RecordCommission(void);
      bool     RecordDelete(const int ticket, 
                            const color arrow_color=clrNONE
                            );
      datetime RecordExpiration(void);
      double   RecordLots(void);
      int      RecordMagicNumber(void);
      bool     RecordModify(const int      ticket,
                            const double   price, 
                            const double   stoploss, 
                            const double   takeprofit, 
                            const datetime expiration, 
                            const color    arrow_color
                            );
      double   RecordOpenPrice(void);
      datetime RecordOpenTime(void);
      double   RecordProfit(void);
      bool     RecordSelect(const int index, 
                            const int select, 
                            const int pool=MODE_TRADES
                            );
      int      RecordSend(string   symbol,
                          int      cmd, 
                          double   volume, 
                          double   price, 
                          int      slippage, 
                          double   stoploss, 
                          double   takeprofit, 
                          string   comment="",
                          int      magic=0, 
                          datetime expiration=0, 
                          color    arrow_color=clrNONE
                          );
      int      RecordsHistoryTotal(void);
      double   RecordStopLoss(void);
      int      RecordsTotal(void);
      double   RecordSwap(void);
      string   RecordSymbol(void);
      double   RecordTakeProfit(void);
      int      RecordTicket(void);
      int      RecordType(void);
      void     ResetLastErrorRecord(void);
      bool     Save(void);
      void     SetArrow(const bool value);
      void     SetRecordCount(const int value);
      void     SetRecordFileName(const string value);
      void     SetSelectElement(const int value);
      void     SymbolToCharArray(const string symbol, uchar& array[]);
      void     Tick(const int shift=0);
      bool     WriteHTML(string file_name=NULL);
};


/**
 * Record class initialization function.
 */
ShadowRecord::ShadowRecord(void)
{
   this.record_count        = 0;
   this.select_element      = -1;
   this.show_arrow          = false;
   this.record_file_name    = "ShadowRecord/" +
                              MQLInfoString(MQL_PROGRAM_NAME) +
                              "/Record.bin";
}


/**
 * Record class deinitialization function.
 */
ShadowRecord::~ShadowRecord(void)
{
   double   price;
   string   symbol;
   datetime time;
   
   time = TimeCurrent();
   
   for(int i = 0; i < this.record_count; i++) {
      if(this.records[i].valid == false) continue;
      if(this.records[i].open == false) continue;
      
      symbol = CharArrayToString(this.records[i].symbol);
      
      if(this.records[i].cmd == 0) {
         price = MarketInfo(symbol, MODE_BID);
      }
      else if(this.records[i].cmd == 1) {
         price = MarketInfo(symbol, MODE_ASK);
      }
      else {
         this.records[i].valid = false;
         continue;
      }
      
      this.records[i].open        = false;
      this.records[i].close_time  = time;
      this.records[i].close_price = price;
   }
}


/**
 * Check whether the open position has reached the settlement price.
 * If it reaches the settlement price, execute RecordClose method.
 *
 * @param const int shift
 *  Relative to the current bar the given amount of periods ago.
 */
void ShadowRecord::CheckCloseRecords(const int shift=0)
{
   double ask, bid, point, spread;
   string symbol;
   
   RefreshRates();

   for(int i = 0; i < this.record_count; i++) {
      if(this.records[i].valid == false) continue;
      if(this.records[i].open == false) continue;
      
      symbol = CharArrayToString(this.records[i].symbol);
      
      if(this.records[i].cmd == 0) {
         if(shift == 0) {
            bid = MarketInfo(symbol, MODE_BID);
         } else {
            bid = iOpen(symbol, 0, shift);
         }
         
         if(this.records[i].stoploss > 0 && 
            this.records[i].stoploss >= bid
            ) {
            this.RecordClose(this.records[i].ticket,
                             this.records[i].volume,
                             bid,
                             0,
                             clrNONE
                             );
         }
         if(this.records[i].takeprofit > 0 && 
            this.records[i].takeprofit <= bid
            ) {
            this.RecordClose(this.records[i].ticket, 
                             this.records[i].volume, 
                             bid, 
                             0, 
                             clrNONE
                             );
         }
      }
      if(this.records[i].cmd == 1) {
         if(shift == 0) {
            ask = MarketInfo(symbol, MODE_ASK);
         } else {
            point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
            spread = MarketInfo(symbol, MODE_SPREAD) * point;
            ask    = iOpen(symbol, 0, shift) + spread;
         }
         
         if(this.records[i].stoploss > 0 && 
            this.records[i].stoploss <= ask
            ) {
            this.RecordClose(this.records[i].ticket, 
                             this.records[i].volume, 
                             ask, 
                             0, 
                             clrNONE
                             );
         }
         if(this.records[i].takeprofit > 0 && 
            this.records[i].takeprofit >= ask
            ) {
            this.RecordClose(this.records[i].ticket, 
                             this.records[i].volume, 
                             ask, 
                             0, 
                             clrNONE
                             );
         }
      }
   }
}


/**
 * Confirm expiration date of pending order.
 * If pending order expires, disable it.
 *
 * @param const int shift
 *  Relative to the current bar the given amount of periods ago.
 */
void ShadowRecord::CheckExpirationRecords(const int shift=0)
{
   datetime time = (shift == 0) ? TimeCurrent() : Time[shift];
   
   for(int i = 0; i < this.record_count; i++) {
      if(this.records[i].valid == false) continue;
      if(this.records[i].open == true) continue;
      
      // if pending order
      if(2 <= this.records[i].cmd && this.records[i].cmd <= 5) {
         if(this.records[i].expiration == 0) continue;
         if(this.records[i].expiration <= time) {
            this.records[i].valid = false;
         }
      }
   }
}


/**
 * Check whether the pending order has reached the entry price.
 * If the entry price has been reached, change the state.
 *
 * @param const int shift
 *  Relative to the current bar the given amount of periods ago.
 */
void ShadowRecord::CheckOpenRecords(const int shift=0)
{
   double   ask, bid;
   string   symbol;
   datetime time;
   
   RefreshRates();
   
   time = (shift == 0) ? TimeCurrent() : Time[shift];
   
   for(int i = 0; i < this.record_count; i++) {
      if(this.records[i].valid == false) continue;
      if(this.records[i].open == true) continue;
      
      symbol = CharArrayToString(this.records[i].symbol);
      
      // Buy Limit
      if(this.records[i].cmd == 2) {
         ask = MarketInfo(symbol, MODE_ASK);
         if(this.records[i].open_price >= ask) {
            this.records[i].open       = true;
            this.records[i].cmd        = 0;
            this.records[i].open_price = ask;
            this.records[i].open_time  = time;
            this.records[i].expiration = 0;
         }
      }
      // Sell Limit
      else if(this.records[i].cmd == 3) {
         bid = MarketInfo(symbol, MODE_BID);
         if(this.records[i].open_price <= bid) {
            this.records[i].open       = true;
            this.records[i].cmd        = 1;
            this.records[i].open_price = bid;
            this.records[i].open_time  = time;
            this.records[i].expiration = 0;
         }
      }
      // Buy Stop
      else if(this.records[i].cmd == 4) {
         ask = MarketInfo(symbol, MODE_ASK);
         if(this.records[i].open_price <= ask) {
            this.records[i].open       = true;
            this.records[i].cmd        = 0;
            this.records[i].open_price = ask;
            this.records[i].open_time  = time;
            this.records[i].expiration = 0;
         }
      }
      // SellStop
      else if(this.records[i].cmd == 5) {
         bid = MarketInfo(symbol, MODE_BID);
         if(this.records[i].open_price >= bid) {
            this.records[i].open       = true;
            this.records[i].cmd        = 1;
            this.records[i].open_price = bid;
            this.records[i].open_time  = time;
            this.records[i].expiration = 0;
         }
      }
   }
}


/**
 * Returns element.
 *
 * @param const int ticket  Order ticket.
 *
 * @return int
 */
int ShadowRecord::GetElement(const int ticket)
{
   for(int i = 0; i < this.record_count; i++) {
      if(this.records[i].ticket == ticket) return(i);
   }
   return(-1);
}


/**
 * Create arrow object.
 *
 * @param const int   id           Arrow object id.
 * @param const int   type         Order operation type.
 * @param const color arrow_color  Color of the arrow on the chart.
 */
void ShadowRecord::ArrowCreate(const int   id, 
                               const int   type, 
                               const color arrow_color
                               )
{
   int    arrow_code = 0;
   double price = 0;
   string object_name;
   
   if(arrow_color == clrNONE) return;
   
   object_name = "Record" + IntegerToString(this.record_count);
   
   switch(type) {
      case 0:
         price = MarketInfo(Symbol(), MODE_ASK);
         arrow_code = 1;
         break;
      case 1:
         price = MarketInfo(Symbol(), MODE_BID);
         arrow_code = 1;
         break;
      case 2:
         price = MarketInfo(Symbol(), MODE_BID);
         arrow_code = 3;
         break;
      case 3:
         price = MarketInfo(Symbol(), MODE_ASK);
         arrow_code = 3;
         break;
      default: return; break;
   }
   
   ObjectCreate(0, object_name, OBJ_ARROW, 0, Time[0], price);
   ObjectSet(object_name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSet(object_name, OBJPROP_COLOR, arrow_color);
}


/**
 * Delete arrow objects.
 *
 * @param const int id  Arrow object id.
 */
void ShadowRecord::ArrowDelete(const int id)
{
   ObjectDelete(0, "Record" + IntegerToString(id));
}


/**
 * Returns the contents of the ShadowRecord class error code.
 *
 * @return int  Returns the value of the last error.
 */
int ShadowRecord::GetLastErrorRecord(void)
{
   return(this.error_code);  
}


/**
 * Returns record count.
 *
 * @return int  Returns the value of
 *              the member variable record_count.
 */
int ShadowRecord::GetRecordCount()
{
   return(this.record_count);
}


/**
 * The method opens the file and load records.
 *
 * @param string file  The name of the file.
 *
 * @return bool  If a file has been loaded successfully,
                 the function returns the true.
 */
bool ShadowRecord::Load(string file=NULL)
{
   int handle;
   
   if(file == NULL) file = this.record_file_name;
   handle = FileOpen(file, FILE_READ|FILE_BIN);
   
   if(handle != INVALID_HANDLE) {
      ArrayFree(this.records);
      this.record_count = 0;
      
      if(FileReadArray(handle, this.records, 0, WHOLE_ARRAY) <= 0) {
         Print("File read failed:", GetLastError());
         return(false);  
      }
      else {
         this.record_count = ArraySize(this.records);
      }
   }
   else {
      if(TerminalInfoString(TERMINAL_LANGUAGE) == "Japanese") {
         Print("ファイルが見つかりませんでした。");
      }
      else {
         Print("File open failed");
      }
      return(false);
   }
   return(true);
}


/**
 * Convert period to string.
 *
 * @param int period  Timeframe. 0 means the current chart timeframe.
 *
 * @return string  String presentation of timeframe.
 */
string ShadowRecord::PeriodToString(int period)
{
   if(period == 0) period = Period();

   if(TerminalInfoString(TERMINAL_LANGUAGE) == "Japanese") {
      switch(period) {
         case PERIOD_M1:  return("1分足 (M1)");   break;
         case PERIOD_M5:  return("5分足 (M5)");   break;
         case PERIOD_M15: return("15分足 (M15)"); break;
         case PERIOD_M30: return("30分足 (M30)"); break;
         case PERIOD_H1:  return("1時間足 (H1)"); break;
         case PERIOD_H4:  return("4時間足 (H4)"); break;
         case PERIOD_D1:  return("日足 (D1)");    break;
         case PERIOD_W1:  return("週足 (W1)");    break;
         case PERIOD_MN1: return("月足 (MN1)");   break;
         default: break;
      }
   }
   else {
      switch(period) {
         case PERIOD_M1:  return("1 minute (M1)");    break;
         case PERIOD_M5:  return("5 minutes (M5)");   break;
         case PERIOD_M15: return("15 minutes (M15)"); break;
         case PERIOD_M30: return("30 minutes (M30)"); break;
         case PERIOD_H1:  return("1 hour (H1)");      break;
         case PERIOD_H4:  return("4 hours (H4)");     break;
         case PERIOD_D1:  return("1 day (D1)");       break;
         case PERIOD_W1:  return("1 week (W1)");      break;
         case PERIOD_MN1: return("1 month (MN1)");    break;
         default: break;
      }
   }
   
   return("");
}


/**
 * Close opened order.
 *
 * @param const int    ticket       Unique number of the order ticket.
 * @param       double lots         Number of lots.
 * @param const double price        Closing price.
 * @param const int    slippage     Value the maximum price slippage
 *                                  in points.
 * @param const color  arrow_color  Color of the closing arrow
 *                                  on the chart.
 *
 * @return bool  Ruturns true if successful, otherwise false.
 */
bool ShadowRecord::RecordClose(const int    ticket, 
                                     double lots, 
                               const double price, 
                               const int    slippage, 
                               const color  arrow_color=clrNONE
                               )
{
   int      id, type = 0;
   double   ask, bid, min_lots, max_lots, lot_step, point;
   string   symbol;
   datetime time;
   
   RefreshRates();
   
   // check ticket
   id = this.GetElement(ticket);
   if(id < 0) {
      this.error_code = 4108; // invalid ticket
      return(false);
   }
   if(this.records[id].cmd != 0 && this.records[id].cmd != 1) {
      this.error_code = 4108; // invalid ticket
      return(false);
   }
   
   // check lots
   symbol   = CharArrayToString(this.records[id].symbol);
   min_lots = MarketInfo(symbol, MODE_MINLOT);
   max_lots = MarketInfo(symbol, MODE_MAXLOT);
   lot_step = MarketInfo(symbol, MODE_LOTSTEP);
   
   if(lots < min_lots || lots > max_lots) {
      this.error_code = 131; // invalid trade volume
      return(false);
   }
   
   if(lots >= this.records[id].volume) lots = this.records[id].volume;
   
   // check price
   point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(this.records[id].cmd == 0) {
      type = 2;
      bid  = MarketInfo(symbol, MODE_BID);
      if(price > bid + slippage * point ||
         price < bid - slippage * point
         ) {
         this.error_code = 129; // invalid price
         return(false);
      }
   }
   else if(this.records[id].cmd == 1) {
      type = 3;
      ask  = MarketInfo(symbol, MODE_ASK);
      if(price > ask + slippage * point ||
         price < ask - slippage * point
         ) {
         this.error_code = 129; // invalid price
         return(false);
      }
   }
   
   time = TimeCurrent();
   
   // full settlement
   if(lots >= this.records[id].volume) {
      this.records[id].open        = false;
      this.records[id].close_time  = time;
      this.records[id].close_price = price;
   }
   // partial settlement
   else {
      // create new Record
      SymbolToCharArray(CharArrayToString(this.records[id].symbol), 
                        this.records[this.record_count].symbol
                        );

      this.records[this.record_count].valid
         = true;

      this.records[this.record_count].ticket
         = this.record_count + 1;

      this.records[this.record_count].open
         = true;

      this.records[this.record_count].open_time
         = this.records[id].open_time;

      this.records[this.record_count].close_time
         = 0;

      this.records[this.record_count].cmd
         = this.records[id].cmd;

      this.records[this.record_count].volume
         = this.records[id].volume - lots;

      this.records[this.record_count].open_price
         = this.records[id].open_price;

      this.records[this.record_count].close_price
         = 0;

      this.records[this.record_count].stoploss
         = this.records[id].stoploss;

      this.records[this.record_count].takeprofit
         = this.records[id].takeprofit;

      this.records[this.record_count].magic
         = this.records[id].magic;

      this.records[this.record_count].expiration
         = 0;
      
      this.record_count++;
      
      // exit old record
      this.records[id].open        = false;
      this.records[id].close_time  = time;
      this.records[id].close_price = price;
      this.records[id].volume      = lots;
   }
   
   if(this.show_arrow) {
      this.ArrowCreate(this.record_count, type, arrow_color);
   }
   
   return(true);
}


/**
 * Returns close price of the currently selected order.
 *
 * @return double  The close price of currently selected order.
 */
double ShadowRecord::RecordClosePrice(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false || 
      this.records[this.select_element].open == true
      ) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }

   return(this.records[this.select_element].close_price);
}


/**
 * Returns close time of the currently selcted order.
 *
 * @return datetime  Close time for the currently selected order.
 *                   If close time is not 0, then the order selected
 *                   and has been closed.
 *                   Open and pending orders close time is equal 0.                   
 */
datetime ShadowRecord::RecordCloseTime(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false || 
      this.records[this.select_element].open == true
      ) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(this.records[this.select_element].close_time);
}


/**
 * Returns calculated commissions of the currently selected order.
 *
 * @return double  This method always returns 0.
 */
double ShadowRecord::RecordCommission(void)
{
   return(0);
}


/**
 * Deletes previously opened pending order.
 *
 * @param const int   ticket      Unique number of the order ticket.
 * @param const color arrow_color Color of the arrow on the chart.
 *
 * @return bool  If the method succeeds, it returns true,
 *               otherwise false.
 */
bool ShadowRecord::RecordDelete(const int ticket, 
                                const color arrow_color=clrNONE
                                )
{
   // check ticket
   int id = this.GetElement(ticket);
   
   if(id == -1) {
      this.error_code = 4108; // invalid ticket
      return(false);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(NULL);
   }
   if(this.records[id].cmd != 0 && this.records[id].cmd != 1) {
      this.error_code = 4108; // invalid ticket
      return(false);
   }
   
   this.records[id].valid = false;
   
   return(true);
}


/**
 * Returns expiration date of the selected pending order.
 *
 * @return datetime  Expiration date of the selected pending order.
 */
datetime ShadowRecord::RecordExpiration(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid != 2 && 
      this.records[this.select_element].valid != 3 && 
      this.records[this.select_element].valid != 4 && 
      this.records[this.select_element].valid != 5
      ) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(this.records[this.select_element].expiration);
}


/**
 * Returns amount of lots of the selected order.
 *
 * @return double  Amount of lots of the selected order.
 */
double ShadowRecord::RecordLots(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }

   return(this.records[this.select_element].volume);
}


/**
 * Returns an identifying (magic) number of the 
 * currently selecteid record.
 *
 * @return int  The indentifying number of the currently selected order.
 */
int ShadowRecord::RecordMagicNumber(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(-1);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(-1);
   }

   return(this.records[this.select_element].magic);
}


/**
 * Modification of characteristics of the 
 * previously opened or pending order.
 *
 * @param const int      ticket       Unique number of the order ticket.
 * @param const double   price        New open price of the pending order.
 * @param const double   stoploss     New Stoploss level.
 * @param const double   takeprofit   New TakeProfit level.
 * @param const datetime expiration   Pending order expiration time.
 * @param const color    arrow_color  Arrow color for TP/SL modifications
 *                                    in the chart.
 *
 * @return bool  If the function succeeds, it returns true,
 *               otherwise false.
 */
bool ShadowRecord::RecordModify(const int      ticket, 
                                const double   price, 
                                const double   stoploss, 
                                const double   takeprofit, 
                                const datetime expiration, 
                                const color    arrow_color
                                )
{
   int      id, cmd;
   double   ask, bid, stoplevel;
   string   symbol;
   datetime time;
   
   RefreshRates();
   
   // check ticket
   id = this.GetElement(ticket);
   if(id == -1){
      this.error_code = 4108; // invalid ticket
      return(false);
   }
   
   // check price and expiration
   symbol    = CharArrayToString(this.records[id].symbol);
   cmd       = this.records[id].cmd;
   ask       = MarketInfo(symbol, MODE_ASK);
   bid       = MarketInfo(symbol, MODE_BID);
   stoplevel = MarketInfo(symbol, MODE_STOPLEVEL)
               * SymbolInfoDouble(symbol, SYMBOL_POINT);
   time      = TimeCurrent();
   
   switch(cmd) {
      // buy limit
      case 2:
         if(price != 0 && price >= ask - stoplevel) {
            this.error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // sell limit
      case 3:
         if(price != 0 && price <= bid + stoplevel) {
            this.error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // buy stop
      case 4:
         if(price != 0 && price <= ask + stoplevel) {
            this.error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // sell stop
      case 5:
         if(price != 0 && price >= bid - stoplevel) {
            this.error_code = 129; // invalid price
            return(false);
         }
         if(expiration != 0 && expiration <= time) {
            error_code = 147; // expirations are denied by broker
            return(false);
         }
         break;
      // unexpected value
      default:
         this.error_code = 4108; // invalid ticket
         return(false);
         break;
   }
   
   // check stoploss and takeprofit
   switch(cmd) {
      // buy
      case 0: case 2: case 4:
         if(stoploss != 0) {
            if(bid - stoplevel <= stoploss) {
               this.error_code = 130; // invalid stops
               return(false);
            }
            if(stoploss < 0) {
               this.error_code = 130; // invalid stops
               return(false);
            }
         }
         if(takeprofit != 0) {
            if(bid + stoplevel >= takeprofit) {
               this.error_code = 130; // invalid stops
               return(false);
            }
         }
         break;
      // sell
      case 1: case 3: case 5:
         if(stoploss != 0) {
            if(ask + stoplevel >= stoploss) {
               this.error_code = 130; // invalid stops
               return(false);
            }
         }
         if(takeprofit != 0) {
            if(ask - stoplevel <= takeprofit) {
               this.error_code = 130; // invalid stops
               return(false);
            }
            if(takeprofit < 0) {
               this.error_code = 130; // invalid stops
               return(false);
            }
         }
         break;
      default:
         this.error_code = 4108; // invalid ticket
         return(false);
         break;
   }
   
   // modification record
   if(cmd <= 2 && cmd >= 5 && price > 0) {
      this.records[id].open_price = price;
   }
   if(stoploss   != 0) this.records[id].stoploss   = stoploss;
   if(takeprofit != 0) this.records[id].takeprofit = takeprofit;
   if(expiration != 0) this.records[id].expiration = expiration;
   
   return(true);
}


/**
 * Returns open price of the currently selected order.
 *
 * @return double  Open price of the currently selected order.
 */
double ShadowRecord::RecordOpenPrice(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(this.records[this.select_element].open_price);
}


/**
 * Returns open time of the currently selected order.
 *
 * @return datetime  Open time of the currently selected order.
 */
datetime ShadowRecord::RecordOpenTime(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }

   return(this.records[this.select_element].open_time);
}


/**
 * Returns profit of the currently selected order.
 *
 * @return double  The net profit value (without swaps and commissions)
 *                 for the selected order.
 */
double ShadowRecord::RecordProfit(void)
{
   string symbol;
   double profit, ask, bid;
   
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   symbol = CharArrayToString(this.records[this.select_element].symbol);
   
   if(this.records[this.select_element].open) {
      if(this.records[this.select_element].cmd == 0) {
         bid    = MarketInfo(symbol, MODE_BID);
         profit = (bid - this.records[this.select_element].close_price) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * this.records[this.select_element].volume;
      }
      else if(this.records[this.select_element].cmd == 1) {
         ask    = MarketInfo(symbol, MODE_ASK);
         profit = (this.records[this.select_element].open_price - ask) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * this.records[this.select_element].volume;
      }
      else {
         return(0);
      }
   }
   else {
      if(this.records[this.select_element].cmd == 0) {
         profit = (this.records[this.select_element].close_price 
                  - this.records[this.select_element].open_price) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * this.records[this.select_element].volume;
      }
      else if(this.records[this.select_element].cmd == 1) {
         profit = (this.records[this.select_element].open_price 
                  - this.records[this.select_element].close_price) 
                  / SymbolInfoDouble(symbol, SYMBOL_POINT) 
                  * MarketInfo(Symbol(), MODE_TICKVALUE) 
                  * this.records[this.select_element].volume;
      }
      else {
         return(0);
      }
   }
   
   return(profit);
}


/**
 * The function selects an order for futher processing.
 *
 * @param const int index   Order index or order ticket depending on 
 *                          the second parameter.
 * @param const int select  Selecting flags.
 * @param const int pool    Optional order pool index.
 *
 * @return bool  It returns true If the function succeeds, otherwise false.
 */
bool ShadowRecord::RecordSelect(const int index, 
                                const int select, 
                                const int pool=MODE_TRADES)
{
   int count = 0;
   
   //番号で選択
   if(select == SELECT_BY_POS) {
      //オープン・ポジションの場合
      if(pool == MODE_TRADES) {
         for(int i = 0; i < this.record_count; i++) {
            if(this.records[i].valid == false) continue;
            if(this.records[i].open == false) continue;
            if(index == count){
               this.select_element = i;
               return(true);
            }
            else count++;
         }
      }
      //ヒストリープールの場合
      else if(pool == MODE_HISTORY) {
         for(int i = 0; i < this.record_count; i++) {
            if(this.records[i].valid == false) continue;
            if(this.records[i].open == true) continue;
            if(index == count) {
               this.select_element = i;
               return(true);
            }
            else count++;
         }
      }
   }
   //チケット番号で選択
   else if(select == SELECT_BY_TICKET) {
      //オープン・ポジションの場合
      if(pool == MODE_TRADES) {
         for(int i = 0; i < this.record_count; i++) {
            if(this.records[i].valid == false) continue;
            if(this.records[i].open == false) continue;
            if(index == this.records[i].ticket) {
               this.select_element = i;
               return(true);
            }
         }
      }
      //ヒストリープールの場合
      else if(pool == MODE_HISTORY) {
         for(int i = 0; i < this.record_count; i++) {
            if(this.records[i].valid == false) continue;
            if(this.records[i].open == true) continue;
            if(index == this.records[i].ticket) {
               this.select_element = i;
               return(true);
            }
         }
      }
   }
   
   return(false);
}

/**
 * The main function used to open or place a pending order.
 * Returns number of the ticket or -1 if it fails.
 *
 * @param string   symbol       Symbol for trading.
 * @param int      cmd          Operation type.
 *                              It can be any of the 
 *                              [Trade operation] enumeration.
 * @param const double   volume       Order volume in lots.
 * @param const double   price        Order price.
 * @param const int      slippage     Maximum price slippage for 
 *                                    buy or sell orders.
 * @param const double   stoploss     Stop loss level.
 * @param const double   takeprofit   Take profit level.
 * @param       string   comment      This parameter will never used.
 * @param const int      magic        Order magic number. 
 * @param       datetime expiration   Order expiration time
 *                                    (for pending orders only).
 * @param const color    arrow_color  Color of the opening arrow on the chart.
 *
 * @return int  Returns number of the ticket or -1 if it fails.
 */
int ShadowRecord::RecordSend(const string   symbol, 
                             const int      cmd, 
                             const double   volume, 
                             const double   price, 
                             const int      slippage, 
                             const double   stoploss, 
                             const double   takeprofit, 
                                   string   comment="",
                             const int      magic=0, 
                                   datetime expiration=0, 
                             const color    arrow_color=clrNONE)
{
   int      ticket = 0, type = 0;
   double   stoplevel, ask, bid, min_lots, max_lots;
   datetime time;
   
   RefreshRates();
   
   // check symbol
   if(!SymbolInfoInteger(symbol, SYMBOL_SELECT)) {
      this.error_code = 4106; // unknown symbol
      return(-1);
   }
   
   // check cmd, stoploss and takeprofit
   stoplevel = MarketInfo(symbol, MODE_STOPLEVEL) 
               * SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   switch(cmd) {
      // buy
      case 0: case 2: case 4:
         type = 0;
         if(stoploss != 0) {
            if(price - stoplevel <= stoploss) {
               this.error_code = 130; // invalid stops
               return(-1);
            }
            if(stoploss < 0) {
               this.error_code = 130; // invalid stops
               return(-1); 
            }
         }
         if(takeprofit != 0) {
            if(price + stoplevel >= takeprofit) {
               this.error_code = 130; // invalid stops
               return(-1);
            }
         }
         break;
      // sell
      case 1: case 3: case 5:
         type = 1;
         if(stoploss != 0) {
            if(price + stoplevel >= stoploss) {
               this.error_code = 130; // invalid stops
               return(-1);
            }
         }
         if(takeprofit != 0) {
            if(price - stoplevel <= takeprofit) {
               this.error_code = 130; // invalid stops
               return(-1);
            }
            if(takeprofit < 0) {
               this.error_code = 130; // invalid stops
               return(-1);
            }
         }
         break;
      default:
         this.error_code = 3; // invalid trade parameters
         return(-1);
         break;
   }
   
   // check volume
   min_lots = MarketInfo(symbol, MODE_MINLOT);
   max_lots = MarketInfo(symbol, MODE_MAXLOT);
   
   if(volume < min_lots || volume > max_lots) {
      this.error_code = 131; // invalid trade volume
      return(-1);
   }
   
   // check price and expiration
   ask  = MarketInfo(symbol, MODE_ASK);
   bid  = MarketInfo(symbol, MODE_BID);
   time = TimeCurrent();
   
   switch(cmd) {
      // buy, sell
      case 0: case 1: expiration = 0; break;
      case 2:
         if(stoplevel != 0) {
            if(price >= ask - stoplevel) {
               this.error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            this.error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // sell limit
      case 3:
         if(stoplevel != 0) {
            if(price <= bid + stoplevel) {
               this.error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            this.error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // buy stop
      case 4:
         if(stoplevel != 0) {
            if(price <= ask + stoplevel) {
               this.error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            this.error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // sell stop
      case 5:
         if(stoplevel != 0) {
            if(price >= bid - stoplevel) {
               this.error_code = 129; // invalid price
               return(-1);
            }
         }
         if(expiration < 0) {
            this.error_code = 147; // expirations are denied by broker
            return(-1);
         }
         break;
      // unexpected value
      default:
         this.error_code = 3; // invalid trade parameters
         return(-1);
         break;
   }
   
   ArrayResize(this.records, this.record_count + 1);
   
   // create record
   ticket = this.record_count + 1;
   
   this.records[this.record_count].valid       = true;
   this.records[this.record_count].ticket      = ticket;
   this.records[this.record_count].open_time   = time;
   this.records[this.record_count].close_time  = 0;
   this.records[this.record_count].cmd         = cmd;
   this.records[this.record_count].volume      = volume;
   this.records[this.record_count].open_price  = price;
   this.records[this.record_count].close_price = 0;
   this.records[this.record_count].stoploss    = stoploss;
   this.records[this.record_count].takeprofit  = takeprofit;
   this.records[this.record_count].magic       = magic;
   
   this.SymbolToCharArray(symbol, this.records[this.record_count].symbol);
   
   if(cmd == 0 || cmd == 1) {
      this.records[this.record_count].open = true;
   }
   else {
      this.records[this.record_count].open = false;
   }
   
   if(expiration > 0) {
      this.records[this.record_count].expiration = time + expiration * 1000;
   }
   else {
      this.records[this.record_count].expiration = 0;
   }
   
   if(this.show_arrow) {
      this.ArrowCreate(this.record_count, type, arrow_color);
   }
   
   this.record_count++;
   
   return(ticket);
}


/**
 * Returns the number of closed orders.
 *
 * @return int  The number of closed orders.
 */
int ShadowRecord::RecordsHistoryTotal(void)
{
   int count = 0;
   
   for(int i = 0; i < this.record_count; i++) {
      if(this.records[i].valid == false) continue;
      if(this.records[i].open == false) count++;
   }
   
   return(count);
}


/**
 * Returns stop loss value of the currently selected order.
 *
 * @return double  Stop loss value of the currently selected order.
 */
double ShadowRecord::RecordStopLoss(void)
{
   if(this.select_element == -1) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false) {
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(this.records[this.select_element].stoploss);
}


/**
 * Returns the number of market and pending order.
 *
 * @return int  Total ammount of market and pending orders.
 */
int ShadowRecord::RecordsTotal(void)
{
   int count = 0;
   
   for(int i = 0; i < this.record_count; i++) {
      if(this.records[i].valid == false) continue;
      if(this.records[i].open == true) count++;
   }
   
   return(count);
}


/**
 * Returns swap value of the currently selected order.
 *
 * @return double  This method always return 0.
 */
double ShadowRecord::RecordSwap(void)
{
   return(0);
}


/**
 * Returns symbol name of the currently selected order.
 *
 * @return string  The symbol name of the currently selected order.
 */
string ShadowRecord::RecordSymbol(void)
{
   if(this.select_element == -1){
      this.error_code = 4108; // invalid ticket
      return(NULL);
   }
   if(this.records[this.select_element].valid == false){
      this.error_code = 4108; // invalid ticket
      return(NULL);
   }
   
   return(CharArrayToString(this.records[this.select_element].symbol));
}


/**
 * Returns take profit value of the currently selected order.
 *
 * @return double  Take profit value of the currently selected order.
 */
double ShadowRecord::RecordTakeProfit(void)
{
   if(this.select_element == -1){
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false){
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(this.records[this.select_element].takeprofit);
}


/**
 * Returns ticket number of the currently selectted order.
 *
 * @return int  Ticket number of the currently selected order.
 */
int ShadowRecord::RecordTicket(void)
{
   if(this.select_element == -1){
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false){
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(this.records[this.select_element].ticket);
}


/**
 * Returns Record operation type of the currently selected order.
 *
 * @return int  Order operation type of the currently selected order.
 */
int ShadowRecord::RecordType(void)
{
   if(this.select_element == -1){
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   if(this.records[this.select_element].valid == false){
      this.error_code = 4108; // invalid ticket
      return(0);
   }
   
   return(this.records[this.select_element].cmd);
}


/**
 * Sets the value of the variable error_code into zero.
 */
void ShadowRecord::ResetLastErrorRecord(void)
{
   this.error_code = 0;
}


/**
 * Save records.
 *
 * @return bool  It returns false if this method succeeds,
 *               otherwise returns false.
 */
bool ShadowRecord::Save(void)
{
   int handle = FileOpen(this.record_file_name, 
                         FILE_READ|FILE_WRITE|FILE_BIN
                         );
   int size   = ArrayRange(this.records, 0);
   
   if(handle != INVALID_HANDLE){
      FileSeek(handle, 0, SEEK_SET);
      if(FileWriteArray(handle, this.records, 0, size) == 0) {
         Print(__FUNCTION__, 
               " Failed to save the file, error:", 
               GetLastError()
               );
         FileClose(handle);
         return(false);
      }
      FileClose(handle);
   }
   else {
      Print(__FUNCTION__, 
            " Failed to open the file, error ",
            GetLastError()
            );
      return(false);
   }
   
   return(true);
}


/**
 * Sets the value of the variable show_arrow into input argument.
 *
 * @param const bool value  Value to set to show_arrow.
 */
void ShadowRecord::SetArrow(const bool value)
{
   this.show_arrow = value;
}


/**
 * Sets the value of the variable record_count into input argument.
 *
 * @param const int value  Value to set to record_count.
 */
void ShadowRecord::SetRecordCount(const int value)
{
   this.record_count = value;
}


/**
 * Sets the value of the variable record_file_name into input argument.
 *
 * @param const string value  Value to set to record_file_name.
 */
void ShadowRecord::SetRecordFileName(const string value)
{
   this.record_file_name = value;
}


/**
 * Sets the value of the variable select_element into input argument.
 *
 * @param const int value  Value to set to select_element.
 */
void ShadowRecord::SetSelectElement(const int value)
{
   this.select_element = value;
}


/**
 * Convert symbol (string type) to char array.
 *
 * @param const string symbol  Symbol to be converted.
 * @param uchar array[]  Array for receiving results.
 */
void ShadowRecord::SymbolToCharArray(const string symbol, uchar& array[])
{
   StringToCharArray(symbol, array, 0, WHOLE_ARRAY, CP_ACP);
}


/**
 * Tick function.
 *
 * @param const int shift  Relative to the current bar 
 *                         the given amount of periods ago.
 */
void ShadowRecord::Tick(const int shift=0)
{
   this.error_code = 0;
   this.select_element = -1;
   this.CheckExpirationRecords(shift);
   this.CheckOpenRecords(shift);
   this.CheckCloseRecords(shift);
}


/**
 * Create HTML file.
 *
 * @param string file_name  File name.
 *
 * @return bool  Returns true if successful, otherwise false.
 */
bool ShadowRecord::WriteHTML(string file_name=NULL)
{
   // local variables
   int count                = 0;
   int type                 = -1;
   int digits               = 2;
   int TotalTrades          = 0;
   int ProfitCount          = 0; 
   int LossCount            = 0;
   int LongPositions        = 0;
   int ShortPositions       = 0;
   int LongWonCount         = 0; 
   int ShortWonCount        = 0;
   int ConsecutiveWins      = 0;
   int MaxConsecutiveWins   = 0; 
   int ConsecutiveLosses    = 0;
   int MaxConsecutiveLosses = 0;
   
   uint start_time;
   
   double balance                = 10000;
   double pf                     = 0;
   double payoff                 = 0;
   double avg_profit_trade       = 0;
   double avg_loss_trade         = 0;
   double TotalProfit            = 0;
   double GrossProfit            = 0;
   double GrossLoss              = 0;
   double MaxProfit              = 0;
   double MinLoss                = 0;
   double ConsecutiveProfit      = 0;
   double ConsecutiveLoss        = 0;
   double MaxConsecutiveProfit   = 0;
   double MinConsecutiveLoss     = 0;
   double LongWinningPercentage  = 0;
   double ShortWinningPercentage = 0;
   double WinningPercentage      = 0;
   double LosingPercentage       = 0;
   
   string out, trade;
                 
   if(file_name == NULL) {
      file_name = "ShadowRecord/" + MQLInfoString(MQL_PROGRAM_NAME) 
                  + "/ShadowRecord.html";
   }
   // open
   int handle = FileOpen(file_name, FILE_WRITE|FILE_CSV);
   if(handle == INVALID_HANDLE) {
      Print(__FUNCTION__, ": output file creation error!!");
      return(false);
   }
   FileSeek(handle, 0, SEEK_SET);
   
   // display progress
   start_time = GetTickCount();
   
   // create ducument
   if(AccountCurrency() == "JPY") balance = 1000000;
   if(IsTesting()) balance = AccountBalance() - TesterStatistics(STAT_PROFIT);
   
   for(int i = 0; i < this.RecordsHistoryTotal(); i++) {
      if(!this.RecordSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      
      // display progress every 10 minutes.
      if(GetTickCount() > start_time + 10 * 1000) {
         Print(__FUNCTION__, " :", (i+1), "/", this.RecordsHistoryTotal());
         Comment((i+1), "/", this.RecordsHistoryTotal());
         start_time = GetTickCount();
      }
      
      digits = (int)MarketInfo(this.RecordSymbol(), MODE_DIGITS);
      count++;
      
      // record when entry
      trade += "<tr align=right>";
      trade += "<td>" + IntegerToString(count) + "</td>";
      trade += "<td class=msdate>";
      trade += TimeToString(this.RecordOpenTime(), TIME_DATE|TIME_MINUTES);
      trade += "</td>";
      type = this.RecordType();
      switch(type) {
         case 0:  trade += "<td>buy</td>";        break;
         case 1:  trade += "<td>sell</td>";       break;
         case 2:  trade += "<td>buy limit</td>";  break;
         case 3:  trade += "<td>sell limit</td>"; break;
         case 4:  trade += "<td>buy stop</td>";   break;
         case 5:  trade += "<td>sell stop</td>";  break;
         default: trade += "<td></td>";           break;
      }
      trade += "<td>" + IntegerToString(this.RecordTicket()) + "</td>";
      trade += "<td class=mspt>";
      trade += DoubleToString(this.RecordLots(), 2);
      trade += "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\">";
      trade += DoubleToString(this.RecordOpenPrice(), digits) + "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(this.RecordStopLoss(), digits) + "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(this.RecordTakeProfit(), digits) + "</td>";
      trade += "<td colspan=2></td>";
      trade += "</tr>";
      trade += "\n";
      
      count++;
      
      // record when exit
      trade += "<tr bgcolor=\"#E0E0E0\" align=right>";
      trade += "<td>" + IntegerToString(count) + "</td>";
      trade += "<td class=msdate>" ;
      trade += TimeToString(this.RecordCloseTime(), TIME_DATE|TIME_MINUTES);
      trade += "</td>";
      trade += "<td>close</td>";
      trade += "<td>" + IntegerToString(this.RecordTicket()) + "</td>";
      trade += "<td class=mspt>";
      trade += DoubleToString(this.RecordLots(), 2);
      trade += "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" >";
      trade += DoubleToString(this.RecordClosePrice(), digits);
      trade += "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(this.RecordStopLoss(), digits);
      trade += "</td>";
      trade += "<td style=\"mso-number-format:0\\.000;\" align=right>";
      trade += DoubleToString(this.RecordTakeProfit(), digits);
      trade += "</td>";
      trade += "<td class=mspt>";
      trade += DoubleToString(this.RecordProfit(), 2);
      trade += "</td>";
      TotalProfit += NormalizeDouble(this.RecordProfit(), 2);
      trade += "<td class=mspt>";
      trade += DoubleToString((balance + TotalProfit), 2);
      trade += "</td>";
      trade += "</tr>";
      trade += "\n";
      
      // aggregation processing
      if(this.RecordProfit() > 0) {
         GrossProfit += this.RecordProfit();
         ProfitCount++;
         if(this.RecordType() == 0) {
            LongPositions++;
            LongWonCount++;
         }
         if(this.RecordType() == 1) {
            ShortPositions++;
            ShortWonCount++;
         }
         if(this.RecordProfit() > MaxProfit) MaxProfit = this.RecordProfit();
         ConsecutiveWins++;
         ConsecutiveLosses = 0;
         ConsecutiveProfit += this.RecordProfit();
         ConsecutiveLoss = 0;
         if(ConsecutiveWins > MaxConsecutiveWins) {
            MaxConsecutiveWins = ConsecutiveWins;
         }
         if(ConsecutiveProfit > MaxConsecutiveProfit) {
            MaxConsecutiveProfit = ConsecutiveProfit;
         }
      }
      if(this.RecordProfit() < 0) {
         GrossLoss += this.RecordProfit();
         LossCount++;
         if(this.RecordType() == 0) LongPositions++;
         if(this.RecordType() == 1) ShortPositions++;
         if(this.RecordProfit() < MinLoss) MinLoss = this.RecordProfit();
         ConsecutiveWins = 0;
         ConsecutiveLosses++;
         ConsecutiveProfit = 0;
         ConsecutiveLoss += this.RecordProfit();
         if(ConsecutiveLosses > MaxConsecutiveLosses) {
            MaxConsecutiveLosses = ConsecutiveLosses;
         }
         if(ConsecutiveLoss < MinConsecutiveLoss) {
            MinConsecutiveLoss = ConsecutiveLoss;
         }
      }
      TotalTrades++;
      
   }
   
   if(AccountCurrency() == "JPY") digits = 0;
   else digits = 2;
   
   out =  "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"";
   out += " \"http://www.w3.org/TR/html4/strict.dtd\">\n";
   out += "<html>\n";
   out += "  <head>\n";
   out += "     <title>Virtual Record: "; 
   out += MQLInfoString(MQL_PROGRAM_NAME);
   out += "</title>\n";
   out += "     <meta name=\"version\" content=\"Build ";
   out += IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)) + "\">\n";
   out += "     <meta name=\"server\" content=\"" + AccountServer() + "\">\n";
   out += "     <style type=\"text/css\" media=\"screen\">\n";
   out += "     <!--\n";
   out += "     td { font: 8pt Tahoma,Arial; }\n";
   out += "     //-->\n";
   out += "     </style>\n";
   out += "     <style type=\"text/css\" media=\"print\">\n";
   out += "     <!--\n";
   out += "     td { font: 7pt Tahoma,Arial; }\n";
   out += "     //-->\n";
   out += "     </style>\n";
   out += "     <style type=\"text/css\">\n";
   out += "     <!--\n";
   out += "     .msdate { mso-number-format:\"General Date\"; }\n";
   out += "     .mspt   { mso-number-format:\\#\\,\\#\\#0\\.00;  }\n";
   out += "     //-->\n";
   out += "     </style>\n";
   out += "  </head>\n";
   out += "<body topmargin=1 marginheight=1>\n";
   out += "<div align=center>\n";
   out += "<div style=\"font: 20pt Times New Roman\">";
   out += "<b>Virtual Record Report</b>";
   out += "</div>\n";
   out += "<div style=\"font: 16pt Times New Roman\">";
   out += "<b>" + MQLInfoString(MQL_PROGRAM_NAME) + "</b>";
   out += "</div>\n";
   out += "<div style=\"font: 10pt Times New Roman\">";
   out += "<b>" + AccountServer() + " (Build ";
   out += IntegerToString(TerminalInfoInteger(TERMINAL_BUILD));
   out += ")</b>";
   out += "</div><br>\n";
   
   out += "<table width=820 cellspacing=1 cellpadding=3 border=0>\n";
   out += "<tr align=left>";
   out += "<td colspan=2>通貨ペア</td>";
   out += "<td colspan=4>" + Symbol() + "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2>期間</td>";
   out += "<td colspan=4>" + this.PeriodToString(Period()) + "</td>";
   out += "</tr>\n";
   out += "<tr height=8><td colspan=6></td></tr>\n";
   out += "<tr align=left>";
   out += "<td>初期証拠金</td><td align=right>";
   out += DoubleToString(balance, digits);
   out += "</td>";
   out += "<td></td><td align=right></td>";
   out += "<td>スプレッド</td><td align=right>";
   out += IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD));
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td>総損益</td><td align=right>";
   out += DoubleToString(TotalProfit, digits);
   out += "</td>";
   out += "<td>総利益</td><td align=right>";
   out += DoubleToString(GrossProfit, digits);
   out += "</td>";
   out += "<td>総損失</td><td align=right>";
   out += DoubleToString(GrossLoss, digits);
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   if(GrossLoss != 0) pf = GrossProfit / MathAbs(GrossLoss);
   out += "<td>プロフィットファクター</td>";
   out += "<td align=right>" + DoubleToString(pf, digits) + "</td>";
   if(TotalTrades > 0) payoff = TotalProfit / TotalTrades;
   out += "<td>期待利得</td>";
   out += "<td align=right>" + DoubleToString(payoff, digits) + "</td>";
   out += "<td></td><td align=right></td>";
   out += "</tr>\n";
   out += "<tr height=8><td colspan=6></td></tr>\n";
   out += "<tr align=left>";
   out += "<td>総取引数</td>";
   out += "<td align=right>" + IntegerToString(TotalTrades) + "</td>";
   if(LongPositions > 0) {
      LongWinningPercentage = (double)LongWonCount 
                              / (double)LongPositions 
                              * 100;
   }
   if(ShortPositions > 0) {
      ShortWinningPercentage = (double)ShortWonCount 
                               / (double)ShortPositions 
                               * 100;
   }
   out += "<td>ショートポジション(勝率%）</td>";
   out += "<td align=right>";
   out += IntegerToString(ShortPositions);
   out += " (" + DoubleToString(ShortWinningPercentage, digits) + "%)";
   out += "</td>";
   out += "<td>ロングポジション(勝率%）</td>";
   out += "<td align=right>";
   out += IntegerToString(LongPositions);
   out += " (" + DoubleToString(LongWinningPercentage, digits) + "%)";
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right></td>";
   if(TotalTrades > 0) {
      WinningPercentage = (double)ProfitCount / (double)TotalTrades * 100;
      LosingPercentage = (double)LossCount / (double)TotalTrades * 100;
   }
   out += "<td>勝率(%)</td><td align=right>";
   out += IntegerToString(ProfitCount);
   out += " (" + DoubleToString(WinningPercentage, digits) + "%)";
   out += "</td>";
   out += "<td>負率(%)</td>";
   out += "<td align=right>";
   out += IntegerToString(LossCount);
   out += " (" + DoubleToString(LosingPercentage, digits) + "%)";
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right>最大</td>";
   out += "<td>勝トレード</td><td align=right>";
   out += DoubleToString(MaxProfit, digits);
   out += "</td>";
   out += "<td>負トレード</td><td align=right>";
   out += DoubleToString(MinLoss, digits);
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right>平均</td>";
   if(ProfitCount > 0) avg_profit_trade = GrossProfit / ProfitCount * 100;
   out += "<td>勝トレード</td><td align=right>";
   out += DoubleToString(avg_profit_trade, digits);
   out += "</td>";
   if(LossCount > 0) avg_loss_trade = GrossLoss / LossCount * 100;
   out += "<td>負トレード</td><td align=right>";
   out += DoubleToString(avg_loss_trade, digits);
   out += "</td>";
   out += "</tr>\n";
   out += "<tr align=left>";
   out += "<td colspan=2 align=right>最大</td>";
   out += "<td>連勝(金額)</td><td align=right>";
   out += IntegerToString(MaxConsecutiveWins);
   out += " (" + DoubleToString(MaxConsecutiveProfit, digits) + ")";
   out += "</td>";
   out += "<td>連敗(金額)</td><td align=right>";
   out += IntegerToString(MaxConsecutiveLosses);
   out += " (" + DoubleToString(MinConsecutiveLoss, digits) + ")";
   out += "</td>";
   out += "</tr>\n";
   out += "</table>\n";
   out += "<br>\n";

   out += "<table width=820 cellspacing=1 cellpadding=3 border=0>\n";
   out += "<tr bgcolor=\"#C0C0C0\" align=right>";
   out += "<td>#</td><td>時間</td><td>取引種別</td><td>注文番号</td>";
   out += "<td>数量</td><td>価格</td><td>SL</td>";
   out += "<td>TP</td><td>損益</td><td>残高</td>";
   out += "</tr>\n";
   out += trade;
   out += "</table>\n";
   out += "</div></body></html>";
   
   FileWriteString(handle, out);
   if(0 < handle) FileClose(handle);
   
   return(true);
}


#endif
