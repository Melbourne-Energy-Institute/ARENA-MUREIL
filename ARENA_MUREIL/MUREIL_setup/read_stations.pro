pro read_stations

file = 'CARMA_AUS.csv'

plotps = 0

if plotps eq 0 then BEGIN
set_plot,'x'
device,DECOMPOSED=0
window,0,xsize=900,ysize=900
endif

if plotps eq 1 then BEGIN
    set_plot,'ps'
    filename='map.ps'
    ;device,color=1,filename=filename,/portrait,$
    device,color=1,filename=filename,/landscape;,$
   ; xsize=16,ysize=24,yoffset=1.0
    thick = 6.0
endif


openr,lun,file,/get_lun

nstats = 760

temp = ''

readf,lun,temp

headers = strsplit(temp,',',/EXTRACT)

iname = where(headers eq 'name')
icarbon = where(headers eq 'carbon_2007')
ienergy = where(headers eq 'energy_2007')
ilat = where(headers eq 'latitude')
ilon = where(headers eq 'longitude')

name = strarr(nstats)
carbon= fltarr(nstats)
energy = fltarr(nstats)
lats = strarr(nstats)
lons = strarr(nstats)

loadct,39
limit = [-45,110,-10,155]
map_set,/CYLINDRICAL,limit=limit
map_continents,/hires,/coasts


for i = 0,nstats-1 do BEGIN ; grab the nstats biggest stations

    readf,lun,temp
    values = strsplit(temp,',',/EXTRACT)

    name(i) = values(iname)
    carbon(i) = float(values(icarbon))
    energy(i) = float(values(ienergy))
    lons(i) = float(values(ilon))
    lats(i) = float(values(ilat))

    ; make a circle of right colour
    c_intense = carbon(i)/float(energy(i))
    color = c_intense * 100 + 100
    ;if c_intense lt 0.9 then color = 250
    ;if c_intense lt 0.5 then color = 200
    ;if c_intense lt 0.1 then color = 150
    a = findgen(17)*(!PI*2/16.)
    usersym,cos(a),sin(a),/fill,color=color


    symsize = alog10(energy(i))
    symsize=symsize^6/30000
   

    plots,lons(i),lats(i),psym=8,symsize=symsize
    usersym,cos(a),sin(a),color=0
    plots,lons(i),lats(i),psym=8,symsize=symsize
;endfor
;for i = 0,50 do BEGIN ; grab the nstats biggest stations
    offset = 0 
    if i eq 2 then offset = -0.2
    if i eq 5 then offset = -0.2
    if i eq 6 then offset = -0.45
    if i eq 8 then offset = -0.2
    if i eq 11 then offset = -0.2
    if i eq 12 then offset = 0.45
    if i eq 14 then offset = 0.1
    if i eq 16 then offset = -0.2
    if i eq 17 then offset = -0.2
    if i eq 23 then offset = -0.2
    if i eq 24 then offset = -0.2
    if i eq 26 then offset = 0.2
    ;xyouts,lons(i)+1,lats(i)+offset,name(i)
    ;if i ge 26 then stop
    print,i,' ',name(i),carbon(i),energy(i),c_intense,color,offset
endfor

free_lun,lun

if plotps then device,/close

stop

end
