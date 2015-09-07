pro plot_parks

loadct,39

set_plot,'x'
device,DECOMPOSED=0
window,0,xsize=800,ysize=1000


; read in the state parks data base and plot out the maps

read_CSV,lons,lats,NPARKS,'NATIONAL_PARKS2.csv'
read_CSV,lons,lats,CAPAD,'CAPAD.csv'

read_CSV,lons2,lats2,states,'STATES2.csv'

; mask the data fields to do just victoria

ii = where(states eq 4,complement=kk)

NPARKS(kk) = 0.
CAPAD(kk) = 0.

; plot the data over a map of Australia

; plot as tiles for each type

levels = [1,2,3,4]

limit = [-50,110,-5,160] ; Australia
limit = [-39.5,140,-34,151] ; Victoria
posi  =  [0.1,0.2,0.9,0.9]

; plot the data
ii = where(NPARKS eq -9999.0,nii)
data2 = NPARKS
data2(ii) = 0.0

ii = where(CAPAD eq -9999.0,nii)
data3 = CAPAD
data3(ii) = 0.0
colors = [0,30,70,190,250]

; add on the state parks where missing

ii = where(data3 eq 0 and data2 ne 0)

data3(ii) = 80

;  plot the states
;ii = where(states eq -9999.0,nii)
;data2 = states
;data2(ii) = 0.0
;colors = indgen(9) *31


posi  =  [0.1,0.6,0.9,0.9]
map_set,0,180,/CYLINDRICAL,limit=limit,position=posi
map_grid,/label,font=1,latdel=30,londel=30
pixelplot,data2,lons,lats,levels,colors
map_set,0,180,/CYLINDRICAL,/continents,/NOERASE,limit=limit,position=posi,color=255,mlinethick=1,/hires
map_grid,/label,font=1,latdel=30,londel=30

levels = indgen(10)
colors = indgen(11)*28

posi  =  [0.1,0.2,0.9,0.5]
map_set,0,180,/CYLINDRICAL,limit=limit,position=posi,/NOERASE
map_grid,/label,font=1,latdel=30,londel=30
pixelplot,data3/10,lons,lats,levels,colors
map_set,0,180,/CYLINDRICAL,/continents,/NOERASE,limit=limit,position=posi,color=255,mlinethick=1,/hires
map_grid,/label,font=1,latdel=30,londel=30

; write out the data to a file

ii = where(lons gt 140.9 and lons lt 150.,nii)
jj = where(lats lt -33.9 and lats gt -39.2,njj)

openw,lun,'VIC_PARKS.txt',/get_lun
printf,lun,nii,njj
for ix = 0,nii-1 do BEGIN
    for iy = 0,njj-1 do BEGIN
        printf,lun,lats(jj(iy)),lons(ii(ix))+0.00001,data3(ii(ix),jj(iy)),format='(3f14.5)'
    endfor
endfor
free_lun,lun

stop


stop 
end

pro pixelplot,data,lons,lats,levs,colors

nlons = n_elements(lons)
nlats = n_elements(lats)
nlevs = n_elements(levs)

lons2 = lons - (lons(2)-lons(1))/2.
lats2 = lats + (lats(1)-lats(2))/1.

for i = 1,nlons-2 do BEGIN
    for j = 1,nlats-2 do BEGIN
        icol= data(i,j)
        color = colors(icol)
        ;print,data(i,j),lons(i),lats(j),data(i,j),color
        polyfill,[lons2(i),lons2(i+1),lons2(i+1),lons2(i),lons2(i)],[lats2(j),lats2(j),lats2(j+1),lats2(j+1),lats2(j)],color=color

;        stop
    endfor
endfor

end

pro read_CSV,lons,lats,data,filename

lats = reverse(findgen(543) * 0.11 - 55. )  ; need to check the offset if we're going the right way
lons = findgen(680) * 0.11 + 95.

nlats = n_elements(lats)
nlons = n_elements(lons)

data = fltarr(nlons,nlats)

openr,lun,filename,/get_lun

temp = ''

readf,lun,temp

ilat = 0

while not EOF(lun) do BEGIN
    temp2 = strsplit(temp,',',/EXTRACT)
    data(*,ilat) = float(temp2)
    ilat = ilat + 1
    readf,lun,temp
endwhile

free_lun,lun

stop

end
