#property link          "https://www.earnforex.com/metatrader-indicators/stochastic-multi-timeframe/"
#property version       "1.04"

#property copyright     "EarnForex.com - 2019-2024"
#property description   "See the status of the stochastic indicator on multiple timeframes."
#property description   " "
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for any damage or loss."
#property description   " "
#property description   "Find More on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window

#include <MQLTA Utils.mqh>

#property indicator_buffers 1
#property indicator_buffers 1
#property indicator_plots 1
#property indicator_type1 DRAW_NONE

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0, // CURRENT CANDLE
    CLOSED_CANDLE = 1   // PREVIOUS CANDLE
};

input string Comment_1 = "===================="; // Indicator Settings
input int StochKPeriod = 5;                      // Stochastic K Period
input int StochDPeriod = 3;                      // Stochastic D Period
input int StochSlowing = 3;                      // Stochastic Slowing
input ENUM_MA_METHOD StochMAMethod = MODE_SMA;   // Stochastic MA Method
input ENUM_STO_PRICE StochPriceField = 0;        // Stochastic Price Field
input int StochHighLimit = 80;                   // Stochastic High Limit
input int StochLowLimit = 20;                    // Stochastic Low Limit
input ENUM_CANDLE_TO_CHECK CandleToCheck = CLOSED_CANDLE; // Candle To Use For Analysis
input string Comment_2b = "==================="; // Enabled Timeframes
input bool TFM1 = true;                          // Enable Timeframe M1
input bool TFM5 = true;                          // Enable Timeframe M5
input bool TFM15 = true;                         // Enable Timeframe M15
input bool TFM30 = true;                         // Enable Timeframe M30
input bool TFH1 = true;                          // Enable Timeframe H1
input bool TFH4 = true;                          // Enable Timeframe H4
input bool TFD1 = true;                          // Enable Timeframe D1
input bool TFW1 = true;                          // Enable Timeframe W1
input bool TFMN1 = true;                         // Enable Timeframe MN1
input string Comment_3 = "===================="; // Notification Options
input bool EnableNotify = false;                 // Enable Notifications feature
input bool SendAlert = true;                     // Send Alert Notification
input bool SendApp = false;                      // Send Notification to Mobile
input bool SendEmail = false;                    // Send Notification via Email
input bool InRangeAlerts = true;                 // Alert on 'In Range'?
input bool OversoldAlerts = true;                // Alert on 'Oversold'?
input bool OverboughtAlerts = true;              // Alert on 'Overbought'?
input bool UncertainAlerts = false;              // Alert on 'Uncertain'?
input string Comment_4 = "===================="; // Graphical Objects
input int Xoff = 20;                             // Horizontal spacing for the control panel
input int Yoff = 20;                             // Vertical spacing for the control panel
input ENUM_BASE_CORNER ChartCorner = CORNER_LEFT_UPPER;
input int FontSize = 10;                         // Font size
input string IndicatorName = "MQLTA-STMTF";      // Indicator Name (to name the objects)

double IndCurr[9], IndPrevDiff[9], IndCurrAdd[9];

bool Overbought = false;
bool Oversold = false;
bool InRange = false;

bool TFEnabled[9];
ENUM_TIMEFRAMES TFValues[9];
string TFText[9];
int Stochastic_handles[9];

double BufferZero[1];

double LastAlertDirection = 2; // Signal that was alerted on previous alert. Double because BufferZero is double. "2" because "EMPTY_VALUE", "0", "1", and "-1" are taken for signals.

double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    CleanChart();

    TFEnabled[0] = TFM1;
    TFEnabled[1] = TFM5;
    TFEnabled[2] = TFM15;
    TFEnabled[3] = TFM30;
    TFEnabled[4] = TFH1;
    TFEnabled[5] = TFH4;
    TFEnabled[6] = TFD1;
    TFEnabled[7] = TFW1;
    TFEnabled[8] = TFMN1;
    TFValues[0] = PERIOD_M1;
    TFValues[1] = PERIOD_M5;
    TFValues[2] = PERIOD_M15;
    TFValues[3] = PERIOD_M30;
    TFValues[4] = PERIOD_H1;
    TFValues[5] = PERIOD_H4;
    TFValues[6] = PERIOD_D1;
    TFValues[7] = PERIOD_W1;
    TFValues[8] = PERIOD_MN1;
    TFText[0] = "M1";
    TFText[1] = "M5";
    TFText[2] = "M15";
    TFText[3] = "M30";
    TFText[4] = "H1";
    TFText[5] = "H4";
    TFText[6] = "D1";
    TFText[7] = "W1";
    TFText[8] = "MN1";

    InRange = false;
    Overbought = false;
    Oversold = false;

    // Prepare Stochastic indicator handles.
    for (int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        Stochastic_handles[i] = iStochastic(Symbol(), TFValues[i], StochKPeriod, StochDPeriod, StochSlowing, StochMAMethod, StochPriceField);
    }

    SetIndexBuffer(0, BufferZero, INDICATOR_DATA);

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;
    PanelMovX = (int)MathRound(40 * DPIScale);
    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (PanelMovX + 1) * 4 + 2;
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;
    
    CalculateLevels();

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    CalculateLevels();

    FillBuffers();

    if (EnableNotify) Notify();

    DrawPanel();
    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

//+------------------------------------------------------------------+
//| Processes key presses and mouse clicks.                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27) // Escape key pressed.
        {
            ChartIndicatorDelete(0, 0, IndicatorName);
        }
    }

    if (id == CHARTEVENT_OBJECT_CLICK) // Timeframe switching.
    {
        if (StringFind(sparam, "-P-TF-") >= 0)
        {
            string ClickDesc = ObjectGetString(0, sparam, OBJPROP_TEXT);
            ChangeChartPeriod(ClickDesc);
        }
    }
}

//+------------------------------------------------------------------+
//| Delets all chart objects created by the indicator.               |
//+------------------------------------------------------------------+
void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

//+------------------------------------------------------------------+
//| Switch chart timeframe.                                          |
//+------------------------------------------------------------------+
void ChangeChartPeriod(string Button)
{
    StringReplace(Button, "*", "");
    ENUM_TIMEFRAMES NewPeriod = 0;
    if (Button == "M1") NewPeriod = PERIOD_M1;
    if (Button == "M5") NewPeriod = PERIOD_M5;
    if (Button == "M15") NewPeriod = PERIOD_M15;
    if (Button == "M30") NewPeriod = PERIOD_M30;
    if (Button == "H1") NewPeriod = PERIOD_H1;
    if (Button == "H4") NewPeriod = PERIOD_H4;
    if (Button == "D1") NewPeriod = PERIOD_D1;
    if (Button == "W1") NewPeriod = PERIOD_W1;
    if (Button == "MN1") NewPeriod = PERIOD_MN1;
    ChartSetSymbolPeriod(0, Symbol(), NewPeriod);
}

//+------------------------------------------------------------------+
//| Main function to detect OB, OS, Ranging, Uncertain state.        |
//+------------------------------------------------------------------+
void CalculateLevels()
{
    int EnabledCount = 0;
    int OverboughtCount = 0;
    int OversoldCount = 0;
    int InRangeCount = 0;
    Overbought = false;
    Oversold = false;
    InRange = false;
    int Shift = 0;
    if (CandleToCheck == CLOSED_CANDLE) Shift = 1;
    int MaxBars = StochKPeriod + Shift + 1;
    ArrayInitialize(IndCurr, 0);
    ArrayInitialize(IndPrevDiff, 0);
    ArrayInitialize(IndCurrAdd, 0);
    for(int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        if (iBars(Symbol(), TFValues[i]) < MaxBars)
        {
            MaxBars = iBars(Symbol(), TFValues[i]);
            Print("Please load more historical candles. Current calculation only on ", MaxBars, " bars for timeframe ", TFText[i], ".");
            if (MaxBars < 0)
            {
                break;
            }
        }
        EnabledCount++;
        string TFDesc = TFText[i];

        double Buf_Main[2], Buf_Sign[2];
        int n_main = CopyBuffer(Stochastic_handles[i], 0, Shift, 2, Buf_Main);
        int n_sign = CopyBuffer(Stochastic_handles[i], 1, Shift, 2, Buf_Sign);
        if ((n_main < 2) || (n_sign < 2))
        {
            Print("Stochastic data not ready for ", Symbol(), " @ ", EnumToString(TFValues[i]));
            return;
        }

        double StochCurrMain = Buf_Main[1];
        double StochPrevMain = Buf_Main[0];
        double StochCurrSign = Buf_Sign[1];
        double StochPrevSign = Buf_Sign[0];
        
        if (StochCurrMain >= StochHighLimit)
        {
            IndCurr[i] = 1;
            OverboughtCount++;
        }
        if (StochCurrMain <= StochLowLimit)
        {
            IndCurr[i] = -1;
            OversoldCount++;
        }
        if ((StochCurrMain < StochHighLimit) && (StochCurrMain > StochLowLimit))
        {
            IndCurr[i] = 0;
            InRangeCount++;
        }
        
        if (StochCurrMain > StochPrevMain)
        {
            IndPrevDiff[i] = 1;
        }
        else if (StochCurrMain < StochPrevMain)
        {
            IndPrevDiff[i] = -1;
        }
        
        if (StochCurrMain > StochCurrSign)
        {
            IndCurrAdd[i] = 1;
        }
        else if (StochCurrMain < StochCurrSign)
        {
            IndCurrAdd[i] = -1;
        }
    }
    if (OverboughtCount == EnabledCount) Overbought = true;
    if (OversoldCount == EnabledCount) Oversold = true;
    if (InRangeCount == EnabledCount) InRange = true;
}

//+------------------------------------------------------------------+
//| Fills indicator buffers.                                         |
//+------------------------------------------------------------------+
void FillBuffers()
{
    if (Overbought) BufferZero[0] = 1;
    if (Oversold) BufferZero[0] = -1;
    if (InRange) BufferZero[0] = 0;
    if ((!Overbought) && (!Oversold) && (!InRange)) BufferZero[0] = EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Alert processing.                                                |
//+------------------------------------------------------------------+
void Notify()
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if (LastAlertDirection == 2)
    {
        LastAlertDirection = BufferZero[0]; // Avoid initial alert when just attaching the indicator to the chart.
        return;
    }
    if (BufferZero[0] == LastAlertDirection) return; // Avoid alerting about the same signal.
    LastAlertDirection = BufferZero[0];
    string SituationString = "UNCERTAIN";
    if (Overbought)
    {
        if (!OverboughtAlerts) return;
        SituationString = "OVERBOUGHT";
    }
    else if (Oversold)
    {
        if (!OversoldAlerts) return;
        SituationString = "OVERSOLD";
    }
    else if (InRange)
    {
        if (!InRangeAlerts) return;
        SituationString = "IN RANGE";
    }
    else if (!UncertainAlerts) return;
    if (SendAlert)
    {
        string AlertText = IndicatorName + " - " + Symbol() + " Notification: The symbol is currently - " + SituationString + ".";
        Alert(AlertText);
    }
    if (SendEmail)
    {
        string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
        string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n\r\n" + IndicatorName + " Notification for " + Symbol() + "\r\n\r\n";
        EmailBody += "The symbol is currently - " + SituationString;
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email: " + IntegerToString(GetLastError()) + ".");
    }
    if (SendApp)
    {
        string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " - The symbol is currently - " + SituationString + ".";
        if (!SendNotification(AppText)) Print("Error sending notification: " + IntegerToString(GetLastError()) + ".");
    }
}

string PanelBase = IndicatorName + "-P-BAS";
string PanelLabel = IndicatorName + "-P-LAB";
string PanelDAbove = IndicatorName + "-P-DABOVE";
string PanelDBelow = IndicatorName + "-P-DBELOW";
string PanelSig = IndicatorName + "-P-SIG";
//+------------------------------------------------------------------+
//| Main panel drawing function.                                     |
//+------------------------------------------------------------------+
void DrawPanel()
{
    int SignX = 1;
    if ((ChartCorner == CORNER_RIGHT_UPPER) || (ChartCorner == CORNER_RIGHT_LOWER))
    {
        SignX = -1; // Correction for right-side panel position.
    }
    string IndicatorNameTextBox = "MT STOCHASTIC";
    int Rows = 1;
    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_CORNER, ChartCorner);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, FontSize);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2 * SignX,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             FontSize,
             "Stochastic Multi-Timeframe Indicator",
             ALIGN_CENTER,
             "Consolas",
             IndicatorNameTextBox,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);
    ObjectSetInteger(0, PanelLabel, OBJPROP_CORNER, ChartCorner);

    for (int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        string TFRowObj = IndicatorName + "-P-TF-" + TFText[i];
        string IndCurrObj = IndicatorName + "-P-ICURR-V-" + TFText[i];
        string IndPrevDiffObj = IndicatorName + "-P-PREVDIFF-V-" + TFText[i];
        string IndCurrAddObj = IndicatorName + "-P-CURRADD-V-" + TFText[i];
        string TFRowText = TFText[i];
        string IndCurrText = "";
        string IndPrevDiffText = "";
        string IndCurrAddText = "";
        string IndCurrToolTip = "";
        string IndPrevDiffToolTip = "";
        string IndCurrAddToolTip = "";

        color IndCurrBackColor = clrKhaki;
        color IndCurrTextColor = clrNavy;
        color IndPrevDiffBackColor = clrKhaki;
        color IndPrevDiffTextColor = clrNavy;
        color IndCurrAddBackColor = clrKhaki;
        color IndCurrAddTextColor = clrNavy;

        if (IndCurr[i] == 1)
        {
            IndCurrText = "OB";
            IndCurrToolTip = "Currently Overbought";
            IndCurrBackColor = clrDarkRed;
            IndCurrTextColor = clrWhite;
        }
        else if (IndCurr[i] == -1)
        {
            IndCurrText = "OS";
            IndCurrToolTip = "Currently Oversold";
            IndCurrBackColor = clrDarkRed;
            IndCurrTextColor = clrWhite;
        }
        else if (IndCurr[i] == 0)
        {
            IndCurrText = "OK";
            IndCurrToolTip = "Currently in Range";
        }

        if (IndPrevDiff[i] == 1)
        {
            IndPrevDiffText = CharToString(225); // Up arrow.
            IndPrevDiffToolTip = "Current Stochastic Line Higher than Previous Candle";
            IndPrevDiffBackColor = clrDarkGreen;
            IndPrevDiffTextColor = clrWhite;
        }
        else if (IndPrevDiff[i] == -1)
        {
            IndPrevDiffText = CharToString(226); // Down arrow.
            IndPrevDiffToolTip = "Current Stochastic Lower than Previous Candle";
            IndPrevDiffBackColor = clrDarkRed;
            IndPrevDiffTextColor = clrWhite;
        }

        if (IndCurrAdd[i] == 1)
        {
            IndCurrAddText = CharToString(225); // Up arrow.
            IndCurrAddToolTip = "Current Stochastic Line Higher than Signal Line";
            IndCurrAddBackColor = clrDarkGreen;
            IndCurrAddTextColor = clrWhite;
        }
        else if (IndCurrAdd[i] == -1)
        {
            IndCurrAddText = CharToString(226); // Down arrow.
            IndCurrAddToolTip = "Current Stochastic Line Lower than Signal Line";
            IndCurrAddBackColor = clrDarkRed;
            IndCurrAddTextColor = clrWhite;
        }

        DrawEdit(TFRowObj,
                 Xoff + 2 * SignX,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 FontSize,
                 "Click to change the chart",
                 ALIGN_CENTER,
                 "Consolas",
                 TFRowText,
                 false,
                 clrNavy,
                 clrKhaki,
                 clrBlack);
        ObjectSetInteger(0, TFRowObj, OBJPROP_CORNER, ChartCorner);

        DrawEdit(IndCurrObj,
                 Xoff + (PanelMovX + 4) * SignX,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 FontSize,
                 IndCurrToolTip,
                 ALIGN_CENTER,
                 "Consolas",
                 IndCurrText,
                 false,
                 IndCurrTextColor,
                 IndCurrBackColor,
                 clrBlack);
        ObjectSetInteger(0, IndCurrObj, OBJPROP_CORNER, ChartCorner);

        DrawEdit(IndPrevDiffObj,
                 Xoff + (PanelMovX * 2 + 6) * SignX,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 FontSize,
                 IndPrevDiffToolTip,
                 ALIGN_CENTER,
                 "Wingdings",
                 IndPrevDiffText,
                 false,
                 IndPrevDiffTextColor,
                 IndPrevDiffBackColor,
                 clrBlack);
        ObjectSetInteger(0, IndPrevDiffObj, OBJPROP_CORNER, ChartCorner);

        DrawEdit(IndCurrAddObj,
                 Xoff + (PanelMovX * 3 + 8) * SignX,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 FontSize,
                 IndCurrAddToolTip,
                 ALIGN_CENTER,
                 "Wingdings",
                 IndCurrAddText,
                 false,
                 IndCurrAddTextColor,
                 IndCurrAddBackColor,
                 clrBlack);
        ObjectSetInteger(0, IndCurrAddObj, OBJPROP_CORNER, ChartCorner);

        Rows++;
    }
    string SigText = "";
    color SigColor = clrNavy;
    color SigBack = clrKhaki;
    if (Overbought)
    {
        SigText = "Overbought";
        SigColor = clrWhite;
        SigBack = clrDarkRed;
    }
    else if (Oversold)
    {
        SigText = "Oversold";
        SigColor = clrWhite;
        SigBack = clrDarkRed;
    }
    else if (InRange)
    {
        SigText = "In Range";
        SigColor = clrWhite;
        SigBack = clrDarkGreen;
    }
    else
    {
        SigText = "Uncertain";
    }

    DrawEdit(PanelSig,
             Xoff + 2 * SignX,
             Yoff + (PanelMovY + 1) * Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             FontSize,
             "Situation Considering All Timeframes",
             ALIGN_CENTER,
             "Consolas",
             SigText,
             false,
             SigColor,
             SigBack,
             clrBlack);
    ObjectSetInteger(0, PanelSig, OBJPROP_CORNER, ChartCorner);

    Rows++;

    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
    if ((ChartCorner == CORNER_LEFT_UPPER) || (ChartCorner == CORNER_RIGHT_UPPER))
    {
        ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    }
    else
    {
        ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff + (PanelMovY + 1) * Rows + 3 - PanelLabY);
    }
}
//+------------------------------------------------------------------+