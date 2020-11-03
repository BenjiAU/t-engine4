//This file is automatically generated by generator.lua from https://github.com/cimgui/cimplot
//based on implot.h file version 0.7 WIP from implot https://github.com/epezent/implot
#ifndef CIMGUIPLOT_INCLUDED
#define CIMGUIPLOT_INCLUDED
#include <stdio.h>
#include <stdint.h>
#if defined _WIN32 || defined __CYGWIN__
    #ifdef CIMGUI_NO_EXPORT
        #define API
    #else
        #define API __declspec(dllexport)
    #endif
    #ifndef __GNUC__
    #define snprintf sprintf_s
    #endif
#else
    #ifdef __GNUC__
        #define API  __attribute__((__visibility__("default")))
    #else
        #define API
    #endif
#endif

#if defined __cplusplus
    #define EXTERN extern "C"
#else
    #include <stdarg.h>
    #include <stdbool.h>
    #define EXTERN extern
#endif

#define CIMGUI_API EXTERN API
#define CONST const


#ifdef _MSC_VER
typedef unsigned __int64 ImU64;
#else
//typedef unsigned long long ImU64;
#endif


#ifdef CIMGUI_DEFINE_ENUMS_AND_STRUCTS
typedef struct ImPlotInputMap ImPlotInputMap;
typedef struct ImPlotStyle ImPlotStyle;
typedef struct ImPlotLimits ImPlotLimits;
typedef struct ImPlotRange ImPlotRange;
typedef struct ImPlotPoint ImPlotPoint;
typedef struct ImPlotContext ImPlotContext;

struct ImPlotContext;
typedef int ImPlotFlags;
typedef int ImPlotAxisFlags;
typedef int ImPlotCol;
typedef int ImPlotStyleVar;
typedef int ImPlotMarker;
typedef int ImPlotColormap;
typedef enum {
    ImPlotFlags_None = 0,
    ImPlotFlags_NoLegend = 1 << 0,
    ImPlotFlags_NoMenus = 1 << 1,
    ImPlotFlags_NoBoxSelect = 1 << 2,
    ImPlotFlags_NoMousePos = 1 << 3,
    ImPlotFlags_NoHighlight = 1 << 4,
    ImPlotFlags_NoChild = 1 << 5,
    ImPlotFlags_YAxis2 = 1 << 6,
    ImPlotFlags_YAxis3 = 1 << 7,
    ImPlotFlags_Query = 1 << 8,
    ImPlotFlags_Crosshairs = 1 << 9,
    ImPlotFlags_AntiAliased = 1 << 10,
    ImPlotFlags_CanvasOnly = ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoBoxSelect | ImPlotFlags_NoMousePos
}ImPlotFlags_;
typedef enum {
    ImPlotAxisFlags_None = 0,
    ImPlotAxisFlags_NoGridLines = 1 << 0,
    ImPlotAxisFlags_NoTickMarks = 1 << 1,
    ImPlotAxisFlags_NoTickLabels = 1 << 2,
    ImPlotAxisFlags_LogScale = 1 << 3,
    ImPlotAxisFlags_Time = 1 << 4,
    ImPlotAxisFlags_Invert = 1 << 5,
    ImPlotAxisFlags_LockMin = 1 << 6,
    ImPlotAxisFlags_LockMax = 1 << 7,
    ImPlotAxisFlags_Lock = ImPlotAxisFlags_LockMin | ImPlotAxisFlags_LockMax,
    ImPlotAxisFlags_NoDecorations = ImPlotAxisFlags_NoGridLines | ImPlotAxisFlags_NoTickMarks | ImPlotAxisFlags_NoTickLabels
}ImPlotAxisFlags_;
typedef enum {
    ImPlotCol_Line,
    ImPlotCol_Fill,
    ImPlotCol_MarkerOutline,
    ImPlotCol_MarkerFill,
    ImPlotCol_ErrorBar,
    ImPlotCol_FrameBg,
    ImPlotCol_PlotBg,
    ImPlotCol_PlotBorder,
    ImPlotCol_LegendBg,
    ImPlotCol_LegendBorder,
    ImPlotCol_LegendText,
    ImPlotCol_TitleText,
    ImPlotCol_InlayText,
    ImPlotCol_XAxis,
    ImPlotCol_XAxisGrid,
    ImPlotCol_YAxis,
    ImPlotCol_YAxisGrid,
    ImPlotCol_YAxis2,
    ImPlotCol_YAxisGrid2,
    ImPlotCol_YAxis3,
    ImPlotCol_YAxisGrid3,
    ImPlotCol_Selection,
    ImPlotCol_Query,
    ImPlotCol_Crosshairs,
    ImPlotCol_COUNT
}ImPlotCol_;
typedef enum {
    ImPlotStyleVar_LineWeight,
    ImPlotStyleVar_Marker,
    ImPlotStyleVar_MarkerSize,
    ImPlotStyleVar_MarkerWeight,
    ImPlotStyleVar_FillAlpha,
    ImPlotStyleVar_ErrorBarSize,
    ImPlotStyleVar_ErrorBarWeight,
    ImPlotStyleVar_DigitalBitHeight,
    ImPlotStyleVar_DigitalBitGap,
    ImPlotStyleVar_PlotBorderSize,
    ImPlotStyleVar_MinorAlpha,
    ImPlotStyleVar_MajorTickLen,
    ImPlotStyleVar_MinorTickLen,
    ImPlotStyleVar_MajorTickSize,
    ImPlotStyleVar_MinorTickSize,
    ImPlotStyleVar_MajorGridSize,
    ImPlotStyleVar_MinorGridSize,
    ImPlotStyleVar_PlotPadding,
    ImPlotStyleVar_LabelPadding,
    ImPlotStyleVar_LegendPadding,
    ImPlotStyleVar_InfoPadding,
    ImPlotStyleVar_PlotMinSize,
    ImPlotStyleVar_COUNT
}ImPlotStyleVar_;
typedef enum {
    ImPlotMarker_None = -1,
    ImPlotMarker_Circle,
    ImPlotMarker_Square,
    ImPlotMarker_Diamond,
    ImPlotMarker_Up,
    ImPlotMarker_Down,
    ImPlotMarker_Left,
    ImPlotMarker_Right,
    ImPlotMarker_Cross,
    ImPlotMarker_Plus,
    ImPlotMarker_Asterisk,
    ImPlotMarker_COUNT
}ImPlotMarker_;
typedef enum {
    ImPlotColormap_Default = 0,
    ImPlotColormap_Deep = 1,
    ImPlotColormap_Dark = 2,
    ImPlotColormap_Pastel = 3,
    ImPlotColormap_Paired = 4,
    ImPlotColormap_Viridis = 5,
    ImPlotColormap_Plasma = 6,
    ImPlotColormap_Hot = 7,
    ImPlotColormap_Cool = 8,
    ImPlotColormap_Pink = 9,
    ImPlotColormap_Jet = 10,
    ImPlotColormap_COUNT
}ImPlotColormap_;
struct ImPlotPoint
{
    double x, y;
};
struct ImPlotRange
{
    double Min, Max;
};
struct ImPlotLimits
{
    ImPlotRange X, Y;
};
struct ImPlotStyle
{
    float LineWeight;
    int Marker;
    float MarkerSize;
    float MarkerWeight;
    float FillAlpha;
    float ErrorBarSize;
    float ErrorBarWeight;
    float DigitalBitHeight;
    float DigitalBitGap;
    float PlotBorderSize;
    float MinorAlpha;
    ImVec2 MajorTickLen;
    ImVec2 MinorTickLen;
    ImVec2 MajorTickSize;
    ImVec2 MinorTickSize;
    ImVec2 MajorGridSize;
    ImVec2 MinorGridSize;
    ImVec2 PlotPadding;
    ImVec2 LabelPadding;
    ImVec2 LegendPadding;
    ImVec2 InfoPadding;
    ImVec2 PlotMinSize;
    ImVec4 Colors[ImPlotCol_COUNT];
    bool AntiAliasedLines;
    bool UseLocalTime;
};
struct ImPlotInputMap
{
    ImGuiMouseButton PanButton;
    ImGuiKeyModFlags PanMod;
    ImGuiMouseButton FitButton;
    ImGuiMouseButton ContextMenuButton;
    ImGuiMouseButton BoxSelectButton;
    ImGuiKeyModFlags BoxSelectMod;
    ImGuiMouseButton BoxSelectCancelButton;
    ImGuiMouseButton QueryButton;
    ImGuiKeyModFlags QueryMod;
    ImGuiKeyModFlags QueryToggleMod;
    ImGuiKeyModFlags HorizontalMod;
    ImGuiKeyModFlags VerticalMod;
};
#else

#endif // CIMGUI_DEFINE_ENUMS_AND_STRUCTS

#ifndef CIMGUI_DEFINE_ENUMS_AND_STRUCTS
#endif //CIMGUI_DEFINE_ENUMS_AND_STRUCTS
CIMGUI_API ImPlotPoint* ImPlotPoint_ImPlotPointNil(void);
CIMGUI_API void ImPlotPoint_destroy(ImPlotPoint* self);
CIMGUI_API ImPlotPoint* ImPlotPoint_ImPlotPointdouble(double _x,double _y);
CIMGUI_API ImPlotRange* ImPlotRange_ImPlotRangeNil(void);
CIMGUI_API void ImPlotRange_destroy(ImPlotRange* self);
CIMGUI_API ImPlotRange* ImPlotRange_ImPlotRangedouble(double _min,double _max);
CIMGUI_API bool ImPlotRange_Contains(ImPlotRange* self,double value);
CIMGUI_API double ImPlotRange_Size(ImPlotRange* self);
CIMGUI_API bool ImPlotLimits_ContainsPlotPoInt(ImPlotLimits* self,const ImPlotPoint p);
CIMGUI_API bool ImPlotLimits_Containsdouble(ImPlotLimits* self,double x,double y);
CIMGUI_API ImPlotStyle* ImPlotStyle_ImPlotStyle(void);
CIMGUI_API void ImPlotStyle_destroy(ImPlotStyle* self);
CIMGUI_API ImPlotInputMap* ImPlotInputMap_ImPlotInputMap(void);
CIMGUI_API void ImPlotInputMap_destroy(ImPlotInputMap* self);
CIMGUI_API ImPlotContext* ImPlot_CreateContext(void);
CIMGUI_API void ImPlot_DestroyContext(ImPlotContext* ctx);
CIMGUI_API ImPlotContext* ImPlot_GetCurrentContext(void);
CIMGUI_API void ImPlot_SetCurrentContext(ImPlotContext* ctx);
CIMGUI_API bool ImPlot_BeginPlot(const char* title_id,const char* x_label,const char* y_label,const ImVec2 size,ImPlotFlags flags,ImPlotAxisFlags x_flags,ImPlotAxisFlags y_flags,ImPlotAxisFlags y2_flags,ImPlotAxisFlags y3_flags);
CIMGUI_API void ImPlot_EndPlot(void);
CIMGUI_API void ImPlot_PlotLineFloatPtrInt(const char* label_id,const float* values,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotLinedoublePtrInt(const char* label_id,const double* values,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotLineFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotLinedoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotLineVec2Ptr(const char* label_id,const ImVec2* data,int count,int offset);
CIMGUI_API void ImPlot_PlotLinePlotPoIntPtr(const char* label_id,const ImPlotPoint* data,int count,int offset);
CIMGUI_API void ImPlot_PlotLineFnPlotPoIntPtr(const char* label_id,ImPlotPoint(*getter)(void* data,int idx),void* data,int count,int offset);
CIMGUI_API void ImPlot_PlotScatterFloatPtrInt(const char* label_id,const float* values,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotScatterdoublePtrInt(const char* label_id,const double* values,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotScatterFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotScatterdoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotScatterVec2Ptr(const char* label_id,const ImVec2* data,int count,int offset);
CIMGUI_API void ImPlot_PlotScatterPlotPoIntPtr(const char* label_id,const ImPlotPoint* data,int count,int offset);
CIMGUI_API void ImPlot_PlotScatterFnPlotPoIntPtr(const char* label_id,ImPlotPoint(*getter)(void* data,int idx),void* data,int count,int offset);
CIMGUI_API void ImPlot_PlotShadedFloatPtrIntFloat(const char* label_id,const float* values,int count,float y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotShadeddoublePtrIntdouble(const char* label_id,const double* values,int count,double y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotShadedFloatPtrFloatPtrIntFloat(const char* label_id,const float* xs,const float* ys,int count,float y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotShadeddoublePtrdoublePtrIntdouble(const char* label_id,const double* xs,const double* ys,int count,double y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotShadedFloatPtrFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys1,const float* ys2,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotShadeddoublePtrdoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys1,const double* ys2,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotShadedFnPlotPoIntPtr(const char* label_id,ImPlotPoint(*getter1)(void* data,int idx),void* data1,ImPlotPoint(*getter2)(void* data,int idx),void* data2,int count,int offset);
CIMGUI_API void ImPlot_PlotBarsFloatPtrIntFloat(const char* label_id,const float* values,int count,float width,float shift,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsdoublePtrIntdouble(const char* label_id,const double* values,int count,double width,double shift,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys,int count,float width,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsdoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys,int count,double width,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsFnPlotPoIntPtr(const char* label_id,ImPlotPoint(*getter)(void* data,int idx),void* data,int count,double width,int offset);
CIMGUI_API void ImPlot_PlotBarsHFloatPtrIntFloat(const char* label_id,const float* values,int count,float height,float shift,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsHdoublePtrIntdouble(const char* label_id,const double* values,int count,double height,double shift,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsHFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys,int count,float height,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsHdoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys,int count,double height,int offset,int stride);
CIMGUI_API void ImPlot_PlotBarsHFnPlotPoIntPtr(const char* label_id,ImPlotPoint(*getter)(void* data,int idx),void* data,int count,double height,int offset);
CIMGUI_API void ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrInt(const char* label_id,const float* xs,const float* ys,const float* err,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrInt(const char* label_id,const double* xs,const double* ys,const double* err,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotErrorBarsFloatPtrFloatPtrFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys,const float* neg,const float* pos,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotErrorBarsdoublePtrdoublePtrdoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys,const double* neg,const double* pos,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrInt(const char* label_id,const float* xs,const float* ys,const float* err,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrInt(const char* label_id,const double* xs,const double* ys,const double* err,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotErrorBarsHFloatPtrFloatPtrFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys,const float* neg,const float* pos,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotErrorBarsHdoublePtrdoublePtrdoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys,const double* neg,const double* pos,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotStemsFloatPtrIntFloat(const char* label_id,const float* values,int count,float y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotStemsdoublePtrIntdouble(const char* label_id,const double* values,int count,double y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotStemsFloatPtrFloatPtr(const char* label_id,const float* xs,const float* ys,int count,float y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotStemsdoublePtrdoublePtr(const char* label_id,const double* xs,const double* ys,int count,double y_ref,int offset,int stride);
CIMGUI_API void ImPlot_PlotPieChartFloatPtr(const char** label_ids,const float* values,int count,float x,float y,float radius,bool normalize,const char* label_fmt,float angle0);
CIMGUI_API void ImPlot_PlotPieChartdoublePtr(const char** label_ids,const double* values,int count,double x,double y,double radius,bool normalize,const char* label_fmt,double angle0);
CIMGUI_API void ImPlot_PlotHeatmapFloatPtr(const char* label_id,const float* values,int rows,int cols,float scale_min,float scale_max,const char* label_fmt,const ImPlotPoint bounds_min,const ImPlotPoint bounds_max);
CIMGUI_API void ImPlot_PlotHeatmapdoublePtr(const char* label_id,const double* values,int rows,int cols,double scale_min,double scale_max,const char* label_fmt,const ImPlotPoint bounds_min,const ImPlotPoint bounds_max);
CIMGUI_API void ImPlot_PlotDigitalFloatPtr(const char* label_id,const float* xs,const float* ys,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotDigitaldoublePtr(const char* label_id,const double* xs,const double* ys,int count,int offset,int stride);
CIMGUI_API void ImPlot_PlotDigitalFnPlotPoIntPtr(const char* label_id,ImPlotPoint(*getter)(void* data,int idx),void* data,int count,int offset);
CIMGUI_API void ImPlot_PlotTextFloat(const char* text,float x,float y,bool vertical,const ImVec2 pixel_offset);
CIMGUI_API void ImPlot_PlotTextdouble(const char* text,double x,double y,bool vertical,const ImVec2 pixel_offset);
CIMGUI_API void ImPlot_SetNextPlotLimits(double xmin,double xmax,double ymin,double ymax,ImGuiCond cond);
CIMGUI_API void ImPlot_SetNextPlotLimitsX(double xmin,double xmax,ImGuiCond cond);
CIMGUI_API void ImPlot_SetNextPlotLimitsY(double ymin,double ymax,ImGuiCond cond,int y_axis);
CIMGUI_API void ImPlot_LinkNextPlotLimits(double* xmin,double* xmax,double* ymin,double* ymax,double* ymin2,double* ymax2,double* ymin3,double* ymax3);
CIMGUI_API void ImPlot_FitNextPlotAxes(bool x,bool y,bool y2,bool y3);
CIMGUI_API void ImPlot_SetNextPlotTicksXdoublePtr(const double* values,int n_ticks,const char** labels,bool show_default);
CIMGUI_API void ImPlot_SetNextPlotTicksXdouble(double x_min,double x_max,int n_ticks,const char** labels,bool show_default);
CIMGUI_API void ImPlot_SetNextPlotTicksYdoublePtr(const double* values,int n_ticks,const char** labels,bool show_default,int y_axis);
CIMGUI_API void ImPlot_SetNextPlotTicksYdouble(double y_min,double y_max,int n_ticks,const char** labels,bool show_default,int y_axis);
CIMGUI_API void ImPlot_SetPlotYAxis(int y_axis);
CIMGUI_API void ImPlot_PixelsToPlotVec2(ImPlotPoint *pOut,const ImVec2 pix,int y_axis);
CIMGUI_API void ImPlot_PixelsToPlotFloat(ImPlotPoint *pOut,float x,float y,int y_axis);
CIMGUI_API void ImPlot_PlotToPixelsPlotPoInt(ImVec2 *pOut,const ImPlotPoint plt,int y_axis);
CIMGUI_API void ImPlot_PlotToPixelsdouble(ImVec2 *pOut,double x,double y,int y_axis);
CIMGUI_API void ImPlot_GetPlotPos(ImVec2 *pOut);
CIMGUI_API void ImPlot_GetPlotSize(ImVec2 *pOut);
CIMGUI_API bool ImPlot_IsPlotHovered(void);
CIMGUI_API bool ImPlot_IsPlotXAxisHovered(void);
CIMGUI_API bool ImPlot_IsPlotYAxisHovered(int y_axis);
CIMGUI_API void ImPlot_GetPlotMousePos(ImPlotPoint *pOut,int y_axis);
CIMGUI_API void ImPlot_GetPlotLimits(ImPlotLimits *pOut,int y_axis);
CIMGUI_API bool ImPlot_IsPlotQueried(void);
CIMGUI_API void ImPlot_GetPlotQuery(ImPlotLimits *pOut,int y_axis);
CIMGUI_API ImPlotStyle* ImPlot_GetStyle(void);
CIMGUI_API void ImPlot_StyleColorsAuto(ImPlotStyle* dst);
CIMGUI_API void ImPlot_StyleColorsClassic(ImPlotStyle* dst);
CIMGUI_API void ImPlot_StyleColorsDark(ImPlotStyle* dst);
CIMGUI_API void ImPlot_StyleColorsLight(ImPlotStyle* dst);
CIMGUI_API void ImPlot_PushStyleColorU32(ImPlotCol idx,ImU32 col);
CIMGUI_API void ImPlot_PushStyleColorVec4(ImPlotCol idx,const ImVec4 col);
CIMGUI_API void ImPlot_PopStyleColor(int count);
CIMGUI_API void ImPlot_PushStyleVarFloat(ImPlotStyleVar idx,float val);
CIMGUI_API void ImPlot_PushStyleVarInt(ImPlotStyleVar idx,int val);
CIMGUI_API void ImPlot_PushStyleVarVec2(ImPlotStyleVar idx,const ImVec2 val);
CIMGUI_API void ImPlot_PopStyleVar(int count);
CIMGUI_API void ImPlot_SetNextLineStyle(const ImVec4 col,float weight);
CIMGUI_API void ImPlot_SetNextFillStyle(const ImVec4 col,float alpha_mod);
CIMGUI_API void ImPlot_SetNextMarkerStyle(ImPlotMarker marker,float size,const ImVec4 fill,float weight,const ImVec4 outline);
CIMGUI_API void ImPlot_SetNextErrorBarStyle(const ImVec4 col,float size,float weight);
CIMGUI_API const char* ImPlot_GetStyleColorName(ImPlotCol color);
CIMGUI_API const char* ImPlot_GetMarkerName(ImPlotMarker marker);
CIMGUI_API void ImPlot_PushColormapPlotColormap(ImPlotColormap colormap);
CIMGUI_API void ImPlot_PushColormapVec4Ptr(const ImVec4* colormap,int size);
CIMGUI_API void ImPlot_PopColormap(int count);
CIMGUI_API void ImPlot_SetColormapVec4Ptr(const ImVec4* colormap,int size);
CIMGUI_API void ImPlot_SetColormapPlotColormap(ImPlotColormap colormap,int samples);
CIMGUI_API int ImPlot_GetColormapSize(void);
CIMGUI_API void ImPlot_GetColormapColor(ImVec4 *pOut,int index);
CIMGUI_API void ImPlot_LerpColormap(ImVec4 *pOut,float t);
CIMGUI_API void ImPlot_NextColormapColor(ImVec4 *pOut);
CIMGUI_API void ImPlot_ShowColormapScale(double scale_min,double scale_max,float height);
CIMGUI_API const char* ImPlot_GetColormapName(ImPlotColormap colormap);
CIMGUI_API bool ImPlot_IsLegendEntryHovered(const char* label_id);
CIMGUI_API bool ImPlot_BeginLegendDragDropSource(const char* label_id,ImGuiDragDropFlags flags);
CIMGUI_API void ImPlot_EndLegendDragDropSource(void);
CIMGUI_API bool ImPlot_BeginLegendPopup(const char* label_id,ImGuiMouseButton mouse_button);
CIMGUI_API void ImPlot_EndLegendPopup(void);
CIMGUI_API ImPlotInputMap* ImPlot_GetInputMap(void);
CIMGUI_API ImDrawList* ImPlot_GetPlotDrawList(void);
CIMGUI_API void ImPlot_PushPlotClipRect(void);
CIMGUI_API void ImPlot_PopPlotClipRect(void);
CIMGUI_API bool ImPlot_ShowStyleSelector(const char* label);
CIMGUI_API void ImPlot_ShowStyleEditor(ImPlotStyle* ref);
CIMGUI_API void ImPlot_ShowUserGuide(void);
CIMGUI_API void ImPlot_ShowDemoWindow(bool* p_open);

CIMGUI_API void cimplot_forcelink();


#endif //CIMGUIPLOT_INCLUDED



