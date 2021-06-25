;Variables

globals [
  initial-efficiency
  dismissals
  levels
  resp
  nb-leaving
  comp-leaving
  tot-eff
]

turtles-own [
  age
  seniority
  competence
  happiness
]


;Initializing routines

to create-organisation
  clear-all
  set levels (list n-level-6 n-level-5 n-level-4 n-level-3 n-level-2 n-level-1)
  set dismissals (list dismissal-threshold-1 dismissal-threshold-2 dismissal-threshold-3 dismissal-threshold-4 dismissal-threshold-5 dismissal-threshold-6)
  set resp (list resp1 resp2 resp3 resp4 resp5 resp6)
  setup-turtles
end

to assign-age-and-competence-all
  random-seed new-seed
  ask turtles [assign-age-and-competence]
  do-plot
  set initial-efficiency calculate-efficiency
end

  
to setup-turtles
  let tot sum levels
  crt tot ;;create the turtles
  ;;set their physical property
  ask turtles [ set-turtle-shape ]
  arrange-turtles
  set tot-eff 0
end

to arrange-turtles
  ;;Put the turtles in a pyramid
  let cur 0
  let row 0
  foreach levels [
    let col 0
    while [col < ?] [
      let pos (16.0 / 99.0) * (col - (? / 2))
      ask turtle cur [ set seniority row ]
      ask turtle cur [ set-position pos ]
      set col col + 1
      set cur cur + 1
    ]
    set row row + 1
  ]
end


;Step by step routines

to start-simulation
  if ticks > 1000 [
    stop
  ]
  set tot-eff tot-eff + calculate-efficiency
  set nb-leaving 0
  set comp-leaving 0
  ;First every one is a year older! sigh! yes, life is short!!
  ask turtles [ set age age + 1]
  update-competence
  ask turtles [update-color]
  hierarchy-evolution
  tick
  do-plot
end

to hierarchy-evolution
  ask turtles [
    if does-he-leave [
      dismiss
    ]
  ]
end

to plot-career
  set-current-plot "Average Competence per Level"
  set-plot-x-range 0 6
  set-plot-y-range 0 max [competence] of turtles
  plot-pen-reset
  foreach [0 1 2 3 4 5] [
    let tot sum [competence] of turtles with [seniority = ?]
    let c count turtles with [seniority = ?]
    plotxy ? (tot / c)
    plotxy (? + 1) (tot / c)
    plotxy (? + 1) 0
  ]
end

to do-plot
  plot-dismissals
  plot-career
  plot-efficiency
  plot-happiness
  plot-people-quitting
  plot-competence
end

to plot-competence
  set-current-plot "Average Competence"
  plot mean [competence] of turtles
end

to plot-people-quitting
  set-current-plot "People Resigning"
  ifelse draw-what = "Number" [
    plot nb-leaving
  ][
  ifelse draw-what = "Average" [
    ifelse nb-leaving = 0 [
      plot 0
    ]
    [
      plot comp-leaving / nb-leaving
    ]
  ][
    plot comp-leaving
  ]]
end

to plot-dismissals
  let xmin min dismissals
  set-current-plot "PDF-competence"
  set-histogram-num-bars 100
  set-plot-x-range xmin 10
  histogram [competence] of turtles
end

to plot-happiness
  set-current-plot "Happiness"
  set-current-plot-pen "initial"
  plot 1.0
  set-current-plot-pen "happiness"
  plot average-happiness
end

to plot-efficiency
  set-current-plot "Efficiency"
  set-current-plot-pen "average"
  plot calculate-efficiency
  set-current-plot-pen "initial"
  plot initial-efficiency
end

to update-happiness
  ifelse seniority = 5 [
    set happiness 1.0
  ]
  [
    let min-comp item seniority dismissals
    let perc (competence - min-comp) * unhappiness-not-prom-perc / 100
    set happiness happiness * (1 - perc)
    if happiness < 0.0 [
      set happiness 0.0
    ]
    if happiness > 1.0 [
      set happiness 1.0
    ]
    set competence competence * (1 + ((happiness - thres-happiness) * impact-happ-comp-perc / 100.0))
    if competence < 0.0 [
      set competence 0.0
    ]
    if competence > 10.0 [
      set competence 10.0
    ]
  ]
end

to update-competence-from-experience
  if seniority != 5[
    set competence competence * (1.0 + experience-gain-percentage / 100.0)
    if competence > 10.0 [
      set competence 10.0
    ]
  ]
end

to update-competence
  ;First we gain experience
  ask turtles [update-competence-from-experience]
  ;But we lose happiness
  ask turtles [update-happiness]
end

to update-happiness-upon-promotion
  let m happiness
  if item seniority resp > happiness [
    set m item seniority resp
  ]
  set happiness m + (random-float (1 - m))
end

to promote [x]
  set seniority seniority + 1
  
  update-happiness-upon-promotion
  
  ;competence due to new role
  set competence (ratio-comp-kept-perc * competence / 100 + (1 - ratio-comp-kept-perc / 100) * get-new-competence)
  if competence > 10.0 [
    set competence 10.0
  ]
  
  ;Change its position in the grid
  set-position x
  
end

to hire-new-employee [x]
  set-turtle-shape
  set seniority 0
  set-position x
  assign-age-and-competence
end

to promote-candidate [sen x]
  ifelse sen = 0 [
    ;We have to hire!
    hatch 1 [hire-new-employee x]
  ]
  [
    let employee nobody
    ifelse promotion-criteria = "Most Competent" [
      ;Look for the most competent in seniority sen - 1, if multiple ones, choose randomly and promote
      set employee most-competent (sen - 1)
    ][
    ifelse promotion-criteria = "Least Competent" [
      ;Look for the least competent in seniority sen - 1, if multiple ones, choose randomly and promote
      set employee least-competent (sen - 1)
    ][
    ifelse promotion-criteria = "Random" [
      ;Look for a random employee in seniority sen - 1, and promote
      set employee one-of (turtles with [seniority = sen - 1])
    ][
    ;Alternating strategy
      ;Draw a random variable and see which strategy do we apply
      ifelse random-float 1 < alternating-weight [
        ;Least competent
        set employee least-competent (sen - 1)
      ]
      [
        ;Most competent
        set employee most-competent (sen - 1)
      ]
    ]]]

    ;Well now that we promote it him, fill the gaps
    ifelse employee != nobody [
      promote-candidate (sen - 1) ([xcor] of employee)
    ]
    [
      ;If employee is nobody, this level is empty, we should fill it, and we should promot
      ;one from below, and then we should repromote him
      promote-candidate (sen - 1) x
      promote-candidate sen x
    ]
    
    ask employee [promote x]
  ]
end

to dismiss
  ;Record its x coordinate, and seniority
  let x xcor
  let sen seniority
  ;Promote a new one
  promote-candidate sen x
  ;Dismiss the guy
  die
end 

;Utilities

to set-position [x]
  setxy x (1.5 + seniority * 5)
end

to set-turtle-shape
  set color red
  set shape "person"
  set size 4
end

to update-color
  ifelse (competence < item seniority dismissals) or
         (age >= retirement-age) [
    set color yellow
  ]
  [
    ifelse competence = 10 [
      set color 65
    ]
    [
      set color 10 + 10 * (competence - min dismissals) / (10 - min dismissals)
    ]
  ]
end


;Helper reporting routines


to-report least-competent [sen]
  report one-of ((turtles with [seniority = sen]) with-min [competence])
end

to-report most-competent [sen]
  report one-of ((turtles with [seniority = sen]) with-max [competence])
end

to-report calculate-employee-efficiency
  let sen seniority
  let sen-mul 0
  let jun-mul 0
  ;Senior effect on him
  if sen < 5 [
    let sen-eff mean [competence] of turtles with [ seniority = sen + 1]
    set sen-mul ((sen-eff / competence) - 1) * impact-senior-junior / 100
  ]
  
  ;Junior effect on him
  if sen > 0 [
    let jun-eff mean [competence] of turtles with [ seniority = sen - 1]
    set jun-mul ((jun-eff / competence) - 1) * impact-junior-senior / 100
  ]
  
  let temp competence * (1 + sen-mul) * (1 + jun-mul)
  if temp > 10 [
    report 10
  ]
  report temp
end

to-report calculate-efficiency
  let row 0
  let tot 0
  let sc 0
  foreach resp [
    set tot (tot + (? * count turtles with [seniority = row]))
    set sc (sc + (? * sum [calculate-employee-efficiency] of turtles with [seniority = row]))
    set row row + 1
  ]
  ;max competency is 10, but to make it a % we multiply by 100
  report 10.0 * sc / tot
end

to assign-age-and-competence
  ;We start with the age at the most junior level at 25, and then increase by 5
  set age (25 + 5 * seniority)
  set competence get-new-competence
  set happiness 0.5
  update-happiness-upon-promotion
  update-color
end

to-report get-new-competence
  let min-comp item seniority dismissals
  let comp random-truncated-normal 0.0 10.0 mean-competence variance-competence
  ifelse comp <= min-comp [
    report get-new-competence
  ]
  [
    report comp
  ]
end

to-report random-truncated-normal [lo hi m v]
  let temp random-normal m v
  ifelse (temp < lo or temp > hi) [
    report random-truncated-normal lo hi m v
  ]
  [
    report temp
  ]
end

to-report does-he-leave
  ;An employee can leave whether by being fired, by resigning, or by retiring
  
  ;He gets fired if his competence falls below a certain level
  let min-comp item seniority dismissals
  if competence <= min-comp [
    report true
  ]
  
  ;He retires if his age is beyond retirement age
  if age > retirement-age [
    report true
  ]
  
  ;He resigns, if he is unhappy and finds another job elsewhere
  if employee-can-resign [
    if happiness < thres-happiness [
      ;An employee resigns with a probability of competence * (1 - happiness) * probability of finding another job
      let prob competence * (thres-happiness - happiness) * prob-find-job / thres-happiness
      if random-float 1 < prob [
        set nb-leaving nb-leaving + 1
        ifelse draw-what = "Average" [
          set comp-leaving comp-leaving + competence
        ]
        [
          if competence > comp-leaving [
            set comp-leaving competence
          ]
        ]
        report true
      ]
    ]
  ]
  report false
end

to-report prob-find-job
  ;An employee is as probable to find a job as high is his competence
  let min-comp item seniority dismissals
  report ((competence - min-comp) / (10 - min-comp))
end

to-report average-happiness
  let row 0
  let tot 0
  let sc 0
  foreach resp [
    set tot (tot + (? * count turtles with [seniority = row]))
    set sc (sc + (? * sum [happiness] of turtles with [seniority = row]))
    set row row + 1
  ]
  report sc / tot
end
@#$#@#$#@
GRAPHICS-WINDOW
364
10
803
509
16
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
0
35
1
1
1
ticks

SLIDER
185
10
277
43
n-level-1
n-level-1
1
11
1
1
1
NIL
HORIZONTAL

SLIDER
185
45
285
78
n-level-2
n-level-2
1
21
5
1
1
NIL
HORIZONTAL

SLIDER
185
80
295
113
n-level-3
n-level-3
1
51
11
1
1
NIL
HORIZONTAL

SLIDER
185
115
305
148
n-level-4
n-level-4
1
101
21
1
1
NIL
HORIZONTAL

SLIDER
185
150
315
183
n-level-5
n-level-5
1
251
41
1
1
NIL
HORIZONTAL

SLIDER
185
185
325
218
n-level-6
n-level-6
1
199
81
1
1
NIL
HORIZONTAL

BUTTON
5
10
170
43
1. Create Organisation
create-organisation
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

MONITOR
370
40
455
85
Total Members
count turtles
17
1
11

BUTTON
5
45
170
78
2. Assing Age And Competence
assign-age-and-competence-all
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL

SLIDER
5
85
177
118
mean-competence
mean-competence
0
10
7
0.1
1
NIL
HORIZONTAL

SLIDER
5
120
177
153
variance-competence
variance-competence
0
5
2
0.1
1
NIL
HORIZONTAL

PLOT
820
65
1030
215
PDF-competence
competence
PDF
0.0
10.0
0.0
10.0
true
false
PENS
"default" 0.1 1 -2674135 true

SLIDER
695
465
795
498
dismissal-threshold-1
dismissal-threshold-1
0
10
4
0.1
1
NIL
HORIZONTAL

MONITOR
820
10
915
55
Mean Competence
mean [competence] of turtles
2
1
11

MONITOR
920
10
1030
55
Variance Competence
variance [competence] of turtles
2
1
11

INPUTBOX
370
115
420
175
resp6
1
1
0
Number

INPUTBOX
370
180
420
240
resp5
0.9
1
0
Number

INPUTBOX
370
250
420
310
resp4
0.8
1
0
Number

INPUTBOX
370
315
420
375
resp3
0.6
1
0
Number

INPUTBOX
370
380
420
440
resp2
0.4
1
0
Number

INPUTBOX
370
445
420
505
resp1
0.2
1
0
Number

MONITOR
465
40
577
85
Initial Efficiency %
initial-efficiency
2
1
11

MONITOR
585
40
700
85
Average Efficiency %
calculate-efficiency
2
1
11

SLIDER
695
400
795
433
dismissal-threshold-2
dismissal-threshold-2
0
10
4.5
0.1
1
NIL
HORIZONTAL

SLIDER
695
340
795
373
dismissal-threshold-3
dismissal-threshold-3
0
10
5
0.1
1
NIL
HORIZONTAL

SLIDER
695
270
795
303
dismissal-threshold-4
dismissal-threshold-4
0
10
5.5
0.1
1
NIL
HORIZONTAL

SLIDER
695
205
795
238
dismissal-threshold-5
dismissal-threshold-5
0
10
6
0.1
1
NIL
HORIZONTAL

SLIDER
695
140
795
173
dismissal-threshold-6
dismissal-threshold-6
0
10
6.5
0.1
1
NIL
HORIZONTAL

SLIDER
5
160
177
193
retirement-age
retirement-age
50
80
65
1
1
NIL
HORIZONTAL

SLIDER
185
230
360
263
experience-gain-percentage
experience-gain-percentage
0
100
3
1
1
NIL
HORIZONTAL

SLIDER
185
270
360
303
unhappiness-not-prom-perc
unhappiness-not-prom-perc
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
185
310
360
343
ratio-comp-kept-perc
ratio-comp-kept-perc
0
100
90
1
1
NIL
HORIZONTAL

SLIDER
185
350
360
383
impact-happ-comp-perc
impact-happ-comp-perc
0
10
2
0.1
1
NIL
HORIZONTAL

CHOOSER
185
390
360
435
promotion-criteria
promotion-criteria
"Most Competent" "Least Competent" "Random" "Alternating Strategy"
3

TEXTBOX
190
445
220
480
Most Comp
11
0.0
1

SLIDER
220
440
325
473
alternating-weight
alternating-weight
0
1
0.6
0.01
1
NIL
HORIZONTAL

TEXTBOX
330
445
360
470
Least Comp
11
0.0
1

SWITCH
5
200
172
233
employee-can-resign
employee-can-resign
0
1
-1000

BUTTON
5
245
175
278
3. Start Simulation
start-simulation
T
1
T
OBSERVER
NIL
NIL
NIL
NIL

PLOT
820
225
1020
375
Efficiency
time
av-efficiency
0.0
10.0
0.0
10.0
true
false
PENS
"average" 1.0 0 -2674135 true
"initial" 1.0 0 -16777216 true

PLOT
5
285
175
435
Happiness
time
av-happiness
0.0
10.0
0.0
1.0
true
false
PENS
"initial" 1.0 0 -16777216 true
"happiness" 1.0 0 -2674135 true

PLOT
1030
225
1230
375
Average Competence per Level
Level
Competence
0.0
6.0
0.0
10.0
false
false
PENS
"default" 1.0 0 -2674135 true

SLIDER
5
445
177
478
thres-happiness
thres-happiness
0
1
0.8
0.01
1
NIL
HORIZONTAL

PLOT
1035
65
1230
215
People Resigning
time
# People
0.0
10.0
0.0
10.0
true
false
PENS
"default" 1.0 0 -2674135 true

CHOOSER
1035
10
1173
55
draw-what
draw-what
"Number" "Average" "Maximum"
1

PLOT
820
380
1020
530
Average Competence
time
Av Competence
0.0
10.0
0.0
10.0
true
false
PENS
"default" 1.0 0 -2674135 true

SLIDER
5
485
175
518
impact-junior-senior
impact-junior-senior
0
100
1
1
1
%
HORIZONTAL

SLIDER
185
485
360
518
impact-senior-junior
impact-senior-junior
0
100
10
1
1
%
HORIZONTAL

@#$#@#$#@
WHAT IS IT?
-----------
This section could give a general understanding of what the model is trying to show or explain.


HOW IT WORKS
------------
This section could explain what rules the agents use to create the overall behavior of the model.


HOW TO USE IT
-------------
This section could explain how to use the model, including a description of each of the items in the interface tab.


THINGS TO NOTICE
----------------
This section could give some ideas of things for the user to notice while running the model.


THINGS TO TRY
-------------
This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.


EXTENDING THE MODEL
-------------------
This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.


NETLOGO FEATURES
----------------
This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.


RELATED MODELS
--------------
This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.


CREDITS AND REFERENCES
----------------------
This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 4.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
