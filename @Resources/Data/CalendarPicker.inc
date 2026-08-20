; In-flow calendar navigator. Lua supplies labels and selected-state colors.

[MeterCalendarPrevious]
Meter=String
Group=Flyout|Calendar
MeterStyle=StyleScrollButton
X=(#PanelX#+200)
Y=(#PanelY#+20)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureScript "CalendarPrevious()"]
Hidden=1
DynamicVariables=1

[MeterCalendarTitle]
Meter=String
Group=Flyout|Calendar
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+20)
W=142
H=20
StringAlign=CenterCenter
FontColor=#TextColor#
FontSize=10
StringStyle=Bold
Text=#CalendarTitle#
ToolTipText=Choose a month and year
LeftMouseUpAction=[!CommandMeasure MeasureScript "ToggleMonthPicker()"]
Hidden=1
DynamicVariables=1

[MeterCalendarNext]
Meter=String
Group=Flyout|Calendar
MeterStyle=StyleScrollButton
X=(#PanelX#+370)
Y=(#PanelY#+20)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureScript "CalendarNext()"]
Hidden=1
DynamicVariables=1

[MeterCalendarWeekday1]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+208)
Y=(#PanelY#+48)
W=26
H=16
Text=S
Hidden=1
DynamicVariables=1

[MeterCalendarWeekday2]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+237)
Y=(#PanelY#+48)
W=26
H=16
Text=M
Hidden=1
DynamicVariables=1

[MeterCalendarWeekday3]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+266)
Y=(#PanelY#+48)
W=26
H=16
Text=T
Hidden=1
DynamicVariables=1

[MeterCalendarWeekday4]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+48)
W=26
H=16
Text=W
Hidden=1
DynamicVariables=1

[MeterCalendarWeekday5]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+324)
Y=(#PanelY#+48)
W=26
H=16
Text=T
Hidden=1
DynamicVariables=1

[MeterCalendarWeekday6]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+353)
Y=(#PanelY#+48)
W=26
H=16
Text=F
Hidden=1
DynamicVariables=1

[MeterCalendarWeekday7]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+382)
Y=(#PanelY#+48)
W=26
H=16
Text=S
Hidden=1
DynamicVariables=1

[MeterCalendarDay1]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+208)
Y=(#PanelY#+75)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay1Color#
SolidColor=#CalendarDay1Bg#
Text=#CalendarDay1Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(1)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay2]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+237)
Y=(#PanelY#+75)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay2Color#
SolidColor=#CalendarDay2Bg#
Text=#CalendarDay2Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(2)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay3]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+266)
Y=(#PanelY#+75)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay3Color#
SolidColor=#CalendarDay3Bg#
Text=#CalendarDay3Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(3)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay4]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+75)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay4Color#
SolidColor=#CalendarDay4Bg#
Text=#CalendarDay4Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(4)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay5]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+324)
Y=(#PanelY#+75)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay5Color#
SolidColor=#CalendarDay5Bg#
Text=#CalendarDay5Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(5)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay6]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+353)
Y=(#PanelY#+75)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay6Color#
SolidColor=#CalendarDay6Bg#
Text=#CalendarDay6Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(6)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay7]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+382)
Y=(#PanelY#+75)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay7Color#
SolidColor=#CalendarDay7Bg#
Text=#CalendarDay7Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(7)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay8]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+208)
Y=(#PanelY#+100)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay8Color#
SolidColor=#CalendarDay8Bg#
Text=#CalendarDay8Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(8)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay9]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+237)
Y=(#PanelY#+100)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay9Color#
SolidColor=#CalendarDay9Bg#
Text=#CalendarDay9Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(9)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay10]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+266)
Y=(#PanelY#+100)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay10Color#
SolidColor=#CalendarDay10Bg#
Text=#CalendarDay10Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(10)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay11]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+100)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay11Color#
SolidColor=#CalendarDay11Bg#
Text=#CalendarDay11Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(11)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay12]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+324)
Y=(#PanelY#+100)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay12Color#
SolidColor=#CalendarDay12Bg#
Text=#CalendarDay12Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(12)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay13]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+353)
Y=(#PanelY#+100)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay13Color#
SolidColor=#CalendarDay13Bg#
Text=#CalendarDay13Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(13)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay14]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+382)
Y=(#PanelY#+100)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay14Color#
SolidColor=#CalendarDay14Bg#
Text=#CalendarDay14Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(14)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay15]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+208)
Y=(#PanelY#+125)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay15Color#
SolidColor=#CalendarDay15Bg#
Text=#CalendarDay15Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(15)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay16]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+237)
Y=(#PanelY#+125)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay16Color#
SolidColor=#CalendarDay16Bg#
Text=#CalendarDay16Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(16)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay17]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+266)
Y=(#PanelY#+125)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay17Color#
SolidColor=#CalendarDay17Bg#
Text=#CalendarDay17Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(17)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay18]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+125)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay18Color#
SolidColor=#CalendarDay18Bg#
Text=#CalendarDay18Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(18)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay19]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+324)
Y=(#PanelY#+125)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay19Color#
SolidColor=#CalendarDay19Bg#
Text=#CalendarDay19Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(19)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay20]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+353)
Y=(#PanelY#+125)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay20Color#
SolidColor=#CalendarDay20Bg#
Text=#CalendarDay20Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(20)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay21]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+382)
Y=(#PanelY#+125)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay21Color#
SolidColor=#CalendarDay21Bg#
Text=#CalendarDay21Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(21)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay22]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+208)
Y=(#PanelY#+150)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay22Color#
SolidColor=#CalendarDay22Bg#
Text=#CalendarDay22Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(22)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay23]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+237)
Y=(#PanelY#+150)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay23Color#
SolidColor=#CalendarDay23Bg#
Text=#CalendarDay23Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(23)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay24]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+266)
Y=(#PanelY#+150)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay24Color#
SolidColor=#CalendarDay24Bg#
Text=#CalendarDay24Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(24)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay25]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+150)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay25Color#
SolidColor=#CalendarDay25Bg#
Text=#CalendarDay25Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(25)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay26]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+324)
Y=(#PanelY#+150)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay26Color#
SolidColor=#CalendarDay26Bg#
Text=#CalendarDay26Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(26)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay27]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+353)
Y=(#PanelY#+150)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay27Color#
SolidColor=#CalendarDay27Bg#
Text=#CalendarDay27Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(27)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay28]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+382)
Y=(#PanelY#+150)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay28Color#
SolidColor=#CalendarDay28Bg#
Text=#CalendarDay28Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(28)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay29]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+208)
Y=(#PanelY#+175)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay29Color#
SolidColor=#CalendarDay29Bg#
Text=#CalendarDay29Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(29)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay30]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+237)
Y=(#PanelY#+175)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay30Color#
SolidColor=#CalendarDay30Bg#
Text=#CalendarDay30Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(30)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay31]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+266)
Y=(#PanelY#+175)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay31Color#
SolidColor=#CalendarDay31Bg#
Text=#CalendarDay31Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(31)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay32]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+175)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay32Color#
SolidColor=#CalendarDay32Bg#
Text=#CalendarDay32Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(32)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay33]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+324)
Y=(#PanelY#+175)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay33Color#
SolidColor=#CalendarDay33Bg#
Text=#CalendarDay33Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(33)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay34]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+353)
Y=(#PanelY#+175)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay34Color#
SolidColor=#CalendarDay34Bg#
Text=#CalendarDay34Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(34)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay35]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+382)
Y=(#PanelY#+175)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay35Color#
SolidColor=#CalendarDay35Bg#
Text=#CalendarDay35Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(35)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay36]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+208)
Y=(#PanelY#+200)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay36Color#
SolidColor=#CalendarDay36Bg#
Text=#CalendarDay36Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(36)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay37]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+237)
Y=(#PanelY#+200)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay37Color#
SolidColor=#CalendarDay37Bg#
Text=#CalendarDay37Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(37)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay38]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+266)
Y=(#PanelY#+200)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay38Color#
SolidColor=#CalendarDay38Bg#
Text=#CalendarDay38Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(38)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay39]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+295)
Y=(#PanelY#+200)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay39Color#
SolidColor=#CalendarDay39Bg#
Text=#CalendarDay39Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(39)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay40]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+324)
Y=(#PanelY#+200)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay40Color#
SolidColor=#CalendarDay40Bg#
Text=#CalendarDay40Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(40)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay41]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+353)
Y=(#PanelY#+200)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay41Color#
SolidColor=#CalendarDay41Bg#
Text=#CalendarDay41Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(41)"]
Hidden=1
DynamicVariables=1

[MeterCalendarDay42]
Meter=String
Group=Flyout|CalendarDays
MeterStyle=StyleSmallLabel
X=(#PanelX#+382)
Y=(#PanelY#+200)
W=26
H=22
StringAlign=CenterCenter
FontColor=#CalendarDay42Color#
SolidColor=#CalendarDay42Bg#
Text=#CalendarDay42Text#
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarDay(42)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonthPrevious]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleScrollButton
X=(#PanelX#+226)
Y=(#PanelY#+20)
Text=<
LeftMouseUpAction=[!CommandMeasure MeasureScript "ChangeCalendarYear(-1)"]
Hidden=1
DynamicVariables=1

[MeterCalendarYear]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+250)
Y=(#PanelY#+20)
W=110
H=20
FontColor=#TextColor#
FontSize=10
StringStyle=Bold
Text=#CalendarYear#
Hidden=1
DynamicVariables=1

[MeterCalendarMonthNext]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleScrollButton
X=(#PanelX#+364)
Y=(#PanelY#+20)
Text=>
LeftMouseUpAction=[!CommandMeasure MeasureScript "ChangeCalendarYear(1)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth1]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+218)
Y=(#PanelY#+62)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth1Color#
SolidColor=#CalendarMonth1Bg#
Text=JAN
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(1)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth2]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+281)
Y=(#PanelY#+62)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth2Color#
SolidColor=#CalendarMonth2Bg#
Text=FEB
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(2)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth3]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+344)
Y=(#PanelY#+62)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth3Color#
SolidColor=#CalendarMonth3Bg#
Text=MAR
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(3)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth4]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+218)
Y=(#PanelY#+96)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth4Color#
SolidColor=#CalendarMonth4Bg#
Text=APR
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(4)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth5]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+281)
Y=(#PanelY#+96)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth5Color#
SolidColor=#CalendarMonth5Bg#
Text=MAY
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(5)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth6]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+344)
Y=(#PanelY#+96)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth6Color#
SolidColor=#CalendarMonth6Bg#
Text=JUN
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(6)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth7]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+218)
Y=(#PanelY#+130)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth7Color#
SolidColor=#CalendarMonth7Bg#
Text=JUL
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(7)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth8]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+281)
Y=(#PanelY#+130)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth8Color#
SolidColor=#CalendarMonth8Bg#
Text=AUG
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(8)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth9]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+344)
Y=(#PanelY#+130)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth9Color#
SolidColor=#CalendarMonth9Bg#
Text=SEP
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(9)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth10]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+218)
Y=(#PanelY#+164)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth10Color#
SolidColor=#CalendarMonth10Bg#
Text=OCT
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(10)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth11]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+281)
Y=(#PanelY#+164)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth11Color#
SolidColor=#CalendarMonth11Bg#
Text=NOV
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(11)"]
Hidden=1
DynamicVariables=1

[MeterCalendarMonth12]
Meter=String
Group=Flyout|CalendarMonths
MeterStyle=StyleSmallLabel
X=(#PanelX#+344)
Y=(#PanelY#+164)
W=58
H=26
StringAlign=CenterCenter
FontColor=#CalendarMonth12Color#
SolidColor=#CalendarMonth12Bg#
Text=DEC
LeftMouseUpAction=[!CommandMeasure MeasureScript "SelectCalendarMonth(12)"]
Hidden=1
DynamicVariables=1
