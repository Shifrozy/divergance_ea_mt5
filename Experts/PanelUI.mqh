//+------------------------------------------------------------------+
//|                                                   PanelUI.mqh   |
//|                          On-chart information panel               |
//+------------------------------------------------------------------+
#ifndef PANEL_UI_MQH
#define PANEL_UI_MQH

class CPanelUI
{
private:
   string m_prefix;
   int    m_x, m_y;
   color  m_bgColor;
   color  m_textColor;
   color  m_buyColor;
   color  m_sellColor;

   void CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 9);
   void UpdateLabel(string name, string text, color clr);

public:
   void Create(string prefix, int x, int y);
   void Update(string status, int direction, int openPositions);
   void Destroy();
};

//+------------------------------------------------------------------+
void CPanelUI::Create(string prefix, int x, int y)
{
   m_prefix    = prefix;
   m_x         = x;
   m_y         = y;
   m_bgColor   = clrMidnightBlue;
   m_textColor = clrWhite;
   m_buyColor  = clrLime;
   m_sellColor = clrOrangeRed;

   // Background
   string bgName = m_prefix + "_BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, m_x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, m_y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 260);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, m_bgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 2);

   // Title
   CreateLabel(m_prefix + "_Title", m_x + 10, m_y + 8, "DIVERGENCE EA v1.0", clrDodgerBlue, 11);
   // Separator line simulated
   CreateLabel(m_prefix + "_Sep", m_x + 10, m_y + 28, "─────────────────────────", clrDimGray, 7);
   // Direction
   CreateLabel(m_prefix + "_Dir", m_x + 10, m_y + 40, "Bias: ---", m_textColor);
   // Status
   CreateLabel(m_prefix + "_Status", m_x + 10, m_y + 60, "Status: Initializing...", m_textColor);
   // Positions
   CreateLabel(m_prefix + "_Pos", m_x + 10, m_y + 80, "Positions: 0", m_textColor);
   // Symbol
   CreateLabel(m_prefix + "_Sym", m_x + 10, m_y + 100, "Symbol: " + _Symbol, clrGold, 8);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void CPanelUI::Update(string status, int direction, int openPositions)
{
   // Direction
   string dirText = "Bias: NEUTRAL";
   color dirColor = m_textColor;
   if(direction == 1)  { dirText = "Bias: ▲ BULLISH"; dirColor = m_buyColor; }
   if(direction == -1) { dirText = "Bias: ▼ BEARISH"; dirColor = m_sellColor; }
   UpdateLabel(m_prefix + "_Dir", dirText, dirColor);

   // Status
   string statusText = "Status: " + status;
   if(StringLen(statusText) > 38) statusText = StringSubstr(statusText, 0, 38) + "...";
   UpdateLabel(m_prefix + "_Status", statusText, m_textColor);

   // Positions
   UpdateLabel(m_prefix + "_Pos", StringFormat("Positions: %d", openPositions),
               openPositions > 0 ? clrYellow : m_textColor);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void CPanelUI::CreateLabel(string name, int x, int y, string text, color clr, int fontSize)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
void CPanelUI::UpdateLabel(string name, string text, color clr)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
void CPanelUI::Destroy()
{
   ObjectsDeleteAll(0, m_prefix);
   ChartRedraw(0);
}

#endif
