pro plot_transmission

plotps = 0

if plotps eq 0 then BEGIN
set_plot,'x'
device,DECOMPOSED=0
window,0,xsize=900,ysize=900
endif

if plotps eq 1 then BEGIN
    set_plot,'ps'
    filename='trans_map.ps'
    ;device,color=1,filename=filename,/portrait,$
    device,color=1,filename=filename,/landscape;,$
   ; xsize=16,ysize=24,yoffset=1.0
    thick = 6.0
endif


; list of nodes and links

;nodes

node_names = strarr(18)
node_lats = fltarr(18)
node_lons = fltarr(18)

node_names = [ $
'SA_inter1',$      ;0
'Portland',$       ;1
'Heywood',$        ;2
'Moorabool',$      ;3
'Ballarat',$       ;4
'Mildura',$        ;5
'SA_inter2',$      ;6
'NSW_inter1',$     ;7
'Dederang',$       ;8
'NSW_inter2',$     ;9
'NSW_inter3',$     ;10
'Snowy',$          ;11
'South Morang',$   ;12
'Thomastown',$     ;13
'Rowville',$       ;14
'Westernport',$    ;15
'Latrobe Valley',$ ;16
'TAS_inter1']      ;17


connections = intarr(18,18)

connections(0,2) = 500  ; SA int to Heywood
connections(1,2) = 500  ; Portland to Heywood
connections(2,3) = 500  ; Heywood to Moorabool
connections(3,4) = 500  ; Moorabool to Ballarat
connections(4,5) = 500  ; Ballarat to Mildura
connections(5,6) = 500  ; Mildura to SA2
connections(5,7) = 500  ; Mildura NSW1
connections(4,8) = 1000  ; Ballarat to Dederang
connections(8,9) = 500  ; Dederang to NSW2
connections(8,10) = 500 ; Dederang to NSW3
connections(8,11) = 500 ; Dederang to Snowy
connections(8,12) = 1500 ; Dederang to South Morang
connections(12,13) = 2000 ; South Morang to Thomastown
connections(3,13) = 1000  ; Morabool tto Thomastown
connections(13,14) = 5000 ; Thomastown to Rowville
connections(12,16) = 5000 ; SOuth Morang to Latrobe
connections(14,16) = 1000 ; Rowville to Westernport
connections(14,15) = 5000 ; Rowville to Latrobe
connections(16,17) = 600 ; Latrboe to TAS_inter

node_lats = [ $
-37.2,$ ; SA`
-38.3,$ ; Port
-38.1,$ ; Hey
-38.1,$ ; Moor
-37.6,$ ; Bal
-34.2,$ ; Mil
-34.2,$ ; SA2
-33.9,$ ; NSW
-36.5,$ ; Ded
-36.0,$ ; NSW2
-36.5,$ ; NSW3
-36.6,$ ; Snowy
-37.6,$
-37.7,$
-37.9,$
-38.2,$
-38.3,$
-38.4$
]

node_lons = [$
141.1,$ ; SA
141.6,$; Por
141.6,$ ; Hey
144.3,$ ; Moor
143.9,$a ; Bal
142.1,$ ; Mil
141.0,$ ; SA2
142.7,$ ; NSW
147.0,$ ; Ded
147.0,$ ; NSW2
148.6,$ ; NSW3
147.2,$ ; Snowy
145.1,$
145.0,$
145.2,$
145.2,$
146.4,$
147.1$
]


loadct,39
limit = [-40,140,-32,150]
map_set,/CYLINDRICAL,limit=limit
map_continents,/hires,/coasts

color = 100
a = findgen(17)*(!PI*2/16.)
usersym,cos(a),sin(a),/fill,color=color


for i = 0,17 do BEGIN

  plots,node_lons(i),node_lats(i),psym=8,symsize=2

  xyouts,node_lons(i)+0.1,node_lats(i),node_names(i)

  print,i+1,': ',node_names(i),node_lats(i),node_lons(i)

  ;stop

endfor

for ix = 0,17 do BEGIN

    for iy = 0,17 do BEGIN

       if connections(ix,iy) ne 0 then BEGIN
          if connections(ix,iy) gt 0 then color = 100
          if connections(ix,iy) ge 500 then color = 150
          if connections(ix,iy) ge 1000 then color = 180
          if connections(ix,iy) ge 2000 then color = 210
          if connections(ix,iy) ge 4000 then color = 240
          ;print,node_lons(ix),node_lons(iy),' to ',node_lats(ix),node_lats(iy)   ,' Capacity = ' ,connections(ix,iy)
          print,ix+1,' to ',iy+1,' Capacity = ' ,connections(ix,iy)
          plots,[node_lons(ix),node_lons(iy)],[node_lats(ix),node_lats(iy)]   ,color=color
          ;stop
       endif
    endfor
endfor


if plotps then device,/close

stop






end
