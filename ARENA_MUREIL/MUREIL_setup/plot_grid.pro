pro plotgrid

; read in the lats and lons of the nodes
file = '/home/UNIMELB/rogerd/MUREIL/test_regression/flow_1/nodes.csv'
readnodes,lats,lons,names,file

; read in the connection matrix
file = '/home/UNIMELB/rogerd/MUREIL/test_regression/flow_1/lines.csv'
readmatrix,linkname,linkfrom,linkto,capfrom,capto,suscept,linetype,file

; plot a maps and draw the lines
plotps = 0
filename='trans_map.ps'
setupmaps,plotps,filename

loadct,39

; plot the 21 nodes
plotnodes,lons,lats,names

; plot the connections
plotconnects,capto,names,linkfrom,linkto,lons,lats

; add the AEMO100% regions
setAEMO,AEMOlat,AEMOlon

;plot AEMO points
plotAEMO,AEMOlon,AEMOlat

; plot results from ramping mureil case
;plotmureil,AEMOlon,AEMOlat,'/home/UNIMELB/rogerd/MUREIL/slow_cp-40_low_carbon_price.nc'

; plot the exisiting fossil plant
plot_fossil

; write in the cap factors for different sites
;wind_capacity,AEMOlon,AEMOlat

if plotps then device,/close

; for each region, find nearest node, apply tranmission penalty
calcpenalty,AEMOlon,AEMOlat,lons,lats,names

stop
end

pro readnodes,lats,lons,names,file
lats = fltarr(21)
lons=fltarr(21)
names = strarr(21)
openr,lun,file,/get_lun
temp=''
readf,lun,temp
for i = 0,20 do BEGIN
    readf,lun,temp
    temp2 = strsplit(temp,',',/EXTRACT)
    lats(i) = float(temp2(4))
    lons(i) = float(temp2(3))
    names(i) = temp2(1)
endfor
free_lun,lun
end

pro readmatrix,linkname,linkfrom,linkto,capfrom,capto,suscept,linetype,file
linkname = strarr(26)
linkfrom = strarr(26)
linkto = strarr(26)
capfrom = intarr(26)
capto = intarr(26)
suscept = fltarr(26)
linetype = strarr(26)
openr,lun,file,/get_lun
temp=''
readf,lun,temp
i = 0
while not EOF(lun) do BEGIN
    readf,lun,temp
    temp2 = strsplit(temp,',',/EXTRACT)
    print,temp2
    linkname(i) = temp2(0)
    linkfrom(i) = temp2(1)
    linkto(i) = temp2(2)
    capfrom(i) = fix(temp2(3))
    capto(i) = fix(temp2(4))
    suscept(i) = float(temp2(5))
    linetype(i) = temp2(5)
    print,linkname(i),linkfrom(i),linkto(i)
    i = i + 1
endwhile
free_lun,lun
end

pro setupmaps,plotps,filename
if plotps eq 0 then BEGIN
    set_plot,'x'
    device,DECOMPOSED=0
    ;window,0,xsize=600,ysize=900
    window,0,xsize=900,ysize=700
endif

if plotps eq 1 then BEGIN
    set_plot,'ps'
    device,color=1,filename=filename,$
    xsize=10,ysize=14,/portrait
endif

;limit = [-44,130,-15,155] ;NATIONAL
;limit = [-32,140,-15,155] ;QLD
;limit = [-36,145,-30,155] ;NSW
limit = [-40,140,-34,150] ;VIC
map_set,/CYLINDRICAL,limit=limit
map_continents,/hires,/coasts


end

pro plotnodes,lons,lats,names

color = 100
a = findgen(17)*(!PI*2/16.)
usersym,cos(a),sin(a),/fill,color=color


for i = 0,20 do BEGIN
  plots,lons(i),lats(i),psym=8,symsize=2
  xyouts,lons(i)+0.1,lats(i),names(i);font=1
  print,i+1,': ',names(i),lats(i),lons(i)
endfor

end
pro plotconnects,capto,names,linkfrom,linkto,lons,lats
for ix = 0,25 do BEGIN
     node1 = where(names eq linkfrom(ix))
     node2 = where(names eq linkto(ix))
     color = 0
     if capto(ix) gt 500 then color = 50
     if capto(ix) gt 1000 then color = 100
     if capto(ix) gt 1500 then color = 150
     if capto(ix) gt 2500 then color = 200
     if capto(ix) gt 3500 then color = 250
     if capto(ix) gt 500 then thick = 2
     if capto(ix) gt 1000 then thick = 4
     if capto(ix) gt 1500 then thick = 6
     if capto(ix) gt 2500 then thick = 8
     if capto(ix) gt 3500 then thick = 10
     color=150
     print,linkfrom(ix),' ',linkto(ix),capto(ix),color
     plots,[lons(node1),lons(node2)],[lats(node1),lats(node2)]   ,color=color,thick=thick
     xyouts,(lons(node1)+lons(node2))/2-1.4,(lats(node1)+lats(node2))/2,string(capto(ix))
endfor

end

pro setAEMO,AEMOlat,AEMOlon

AEMOlat = [-18,-20,-20,-21,-22,-22,-23,-25,-25,-25,-25,-27,-27,-27,-27,-27,-27,$
           -30,-30,-30,-30,-30,-30,-30,-32,-33,-32,-31,-32,-32,-33,-36,-34,-35,-35,-36,$
           -37,-38,-38,-41,-41,-43,-43]

AEMOlon= [146,142,145,148,143,146,151,144,146,148,152,138,141,144,147,150,153,$
          132,137,141,144,146,149,152,132,136,141,144,146,149,151,141,143,145,146,149,$
          143,145,147,145,148,145,148]
end
pro plotAEMO,AEMOlon,AEMOlat
          
color = 200
a = findgen(17)*(!PI*2/16.)
usersym,cos(a),sin(a),/fill,color=color

for i = 0,42 do BEGIN
  plots,AEMOlon(i),AEMOlat(i),psym=8,symsize=2
  ;xyouts,AEMOlon(i)-1,AEMOlat(i),string(i+1),font=1
endfor

end

pro calcpenalty,AEMOlon,AEMOlat,lons,lats,names

; plots the translation from site to node

 temp  = ' '

for i = 0,42 do BEGIN

   latdiff = sqrt((AEMOlon(i) - lons)^2)
   londiff = sqrt((AEMOlat(i) - lats)^2)
   distance = sqrt(latdiff^2 + londiff^2)

   kk = where(distance eq min(distance))
   penalty = (min(distance) - 2.0) 
   if penalty lt 0 then penalty = 0
   print,'AEMO polygon ',i+1,' is closest to node ',names(kk(0)),kk(0),' penalty = ',penalty

   if kk(0)+1 lt 10 then temp = temp + '100'+string(kk(0)+1,format='(i1)') + ' '
   if kk(0)+1 ge 10 then temp = temp + '10'+string(kk(0)+1,format='(i2)') + ' '
   
endfor

print,temp
end

pro plotmureil,AEMOlon,AEMOlat,file

; read in the values from the output file
getvar,'wind_cap',wind_cap,file
getvar,'solar_cap',solar_cap,file
getvar,'ts_gas',ts_gas,file
getvar,'ts_browncoal',ts_brown,file
getvar,'ts_blackcoal',ts_black,file
getvar,'ts_wind',ts_wind,file
getvar,'ts_solar',ts_solar,file
getvar,'ts_hydro',ts_hydro,file

usersym,[-1,1,0,-1],[-1,-1,1,-1] , /fill,color=150

; plot the wind points
for i = 0,42 do BEGIN
    print,AEMOlon(i),AEMOlat(i),wind_cap(i)
   ; xyouts,AEMOlon(i),AEMOlat(i),string(wind_cap(i),format='(i4)')
    if wind_cap(i) gt 0.0 then plots,AEMOlon(i),AEMOlat(i),psym=8,symsize=wind_cap(i)/1000
endfor

; plot the solar points
a = findgen(17)*(!PI*2/16.)
usersym,cos(a),sin(a),/fill,color=190
for i = 0,42 do BEGIN
    print,AEMOlon(i),AEMOlat(i),solar_cap(i)
   ; xyouts,AEMOlon(i),AEMOlat(i),string(solar_cap(i),format='(i4)')
    if solar_cap(i) gt 0.0 then plots,AEMOlon(i),AEMOlat(i),psym=8,symsize=solar_cap(i)/1000
endfor

end

pro wind_capacity,AEMOlon,AEMOlat

path = '/home/UNIMELB/rogerd/MUREIL/data'
getvar,'wind',wind,path+'/ROGERS_wind_solar_big.nc'
getvar,'solar',solar,path+'/ROGERS_wind_solar_big.nc'
getvar,'demand',demand,path+'/ROGERS_wind_solar_big.nc'

nstats = n_elements(AEMOlon)
nsteps = n_elements(wind(0,*))

for i = 0,nstats-1 do BEGIN

   cap_fac = total(wind(i,*))/nsteps
   print,cap_fac
   temp = string(cap_fac*100,format='(i2)')
   if cap_fac gt 0.0 then xyouts,AEMOlon(i)+0.5,AEMOlat(i),temp,charsize=1.2;,font=1,charsiz=1.2

endfor

end

pro plot_fossil

file = '/home/UNIMELB/rogerd/MUREIL_setup/CARMA_AUS.csv'

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

offset = 0 
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

    if c_intense gt 0.4 and energy(i) gt 100000 then BEGIN
   
        plots,lons(i),lats(i),psym=8,symsize=symsize
        ; put a black circle around it
        usersym,cos(a),sin(a),color=0
        plots,lons(i),lats(i),psym=8,symsize=symsize

        ;xyouts,lons(i),lats(i),name(i),alignment=0.5
        ;offset = offset + 1
        if offset eq 4 then offset = 0
        ;if i ge 26 then stop
        print,i,' ',name(i),carbon(i),energy(i),c_intense,color,offset,lats(i),lons(i)
    endif
endfor

free_lun,lun

end


