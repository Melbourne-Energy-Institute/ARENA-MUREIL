pro makets

nwind_stats = 100
nsun_stats = 10

maskrange = 0.3
maskrange_sun = 1.0

skip = 1

plotps = 0

loadct,39
!p.color=0
!p.background=255


if plotps eq 0 then BEGIN
set_plot,'x'
device,DECOMPOSED=0
device,set_font='Helvetica Bold',/TT_FONT
window,0,xsize=1000,ysize=600
thick = 2
endif

if skip eq 0 then BEGIN

; get the list of filenames for the model output
spawn,'ls d04_stripped/wrfout_d04_2009-*.nc',filenames

nfiles = n_elements(filenames)
nfiles=nfiles-1
nsteps  = nfiles * 6

; read in the data into arrays
for icount = 0,nfiles-1 do BEGIN

    if icount eq 0 then BEGIN

        getvar,'XLAT',lats,filenames(icount)
        newlats = lats(*,*,0)
        getvar,'XLONG',lons,filenames(icount)
        newlons = lons(*,*,0)
        getvar,'Z0',Zo,filenames(icount)

        ; create a land-sea mask
        mask = Zo(*,*,0)
        ii = where(Zo(*,*,0) gt 0.005)
        mask(ii) = 1.0
        ii = where(Zo(*,*,0) le 0.005)
        mask(ii) = 0.0

        nx = n_elements(newlons(*,0))
        ny = n_elements(newlons(0,*))

    endif

    getvar,'U_stripped',u3d,filenames(icount)
    getvar,'V_stripped',v3d,filenames(icount)
    getvar,'SWDOWN',sw,filenames(icount)

    u = reform(u3d(0:677,*,0,*))
    v = reform(v3d(*,0:371,0,*))

    if icount eq 0 then BEGIN
        ;create big arrays
        speed = fltarr(nx,ny,nsteps)
        power_ts = fltarr(nx,ny,nsteps)
        SW_main = fltarr(nx,ny,nsteps)
    endif 

    ; append the array onto a bigger one
    print,icount*6,(icount+1)*6-1
    SW_main(*,*,icount*6:(icount+1)*6-1)=sw
    speed(*,*,icount*6:(icount+1)*6-1) = sqrt(u*u+v*v)

    ; calculate the wind power based on a GE 2.5 MW generator
    temp = sqrt(u*u+v*v)
    power = temp
    ii = where(temp lt 4.0,nii)
    if nii gt 0 then power(ii) = 0
    ii = where(temp gt 13.0,nii)
    if nii gt 0 then power(ii) = 2500
    ii = where(temp ge 4.0 and temp lt 9.,nii)
    if nii gt 0 then power(ii) = temp(ii)*temp(ii)*38.5 - 231.1*temp(ii) + 358.0
    ii = where(temp ge 9.0 and temp le 13.,nii)
    if nii gt 0 then power(ii) = -1*temp(ii)*temp(ii)*81.4 + 2065.4*temp(ii) - 10596.0

    ; power is in kW
    power_ts(*,*,icount*6:(icount+1)*6-1) = power
endfor

av_speed = total(speed,3)/nsteps
tot_power = total(power_ts,3)/2000./(nsteps/48) ; in MWh (0.5 time step, kW to GW) per 2.5MW farm per day

save,file='WRF_saved_large',speed,SW_main,power_ts,newlons,newlats,mask,Zo,sd,av_speed,tot_power,nsteps
save,file='WRF_saved_small',av_speed,tot_power,newlons,newlats,mask,Zo,sd,nsteps
endif

if skip eq 1 then BEGIN
    print,'RESTORING FROM FILE'
    restore,file='WRF_saved_large'
    print,'DONE RESTORING FROM FILE'
endif
if skip eq 2 then BEGIN
    print,'RESTORING FROM SMALL FILE'
    restore,file='WRF_saved_small'
    print,'DONE RESTORING FROM FILE'
endif

if skip lt 3 then BEGIN

nx = n_elements(newlons(*,0))
ny = n_elements(newlons(0,*))


; plot the average wind power
levels=findgen(17)*3
nlevels = n_elements(levels)
iticks = indgen((nlevels+1)/2)*2

if plotps eq 1 then BEGIN
    set_plot,'ps'
    filename='map.ps'
    device,color=1,filename=filename,/landscape
    thick = 6.0
endif

if plotps eq 0 then BEGIN
    map_set,/CYLINDRICAL,limit=[-40,138,-33,151],/ADVANCE,position=[0.05,0.08,0.95,0.98],$
       label=2,latlab=138,lonlab=-33.2,color=0
    erase,color=255
endif
map_set,/CYLINDRICAL,limit=[-40,138,-33,151],/ADVANCE,position=[0.05,0.08,0.95,0.98],$
    label=2,latlab=138,lonlab=-33.2,color=0,/noerase
temp = tot_power*mask
ii = where(temp eq 0)
temp(ii) = 10000000.
contour,temp,newlons,newlats,/fill,levels=levels,/overplot,xticks=1,yticks=1
map_set,/CYLINDRICAL,limit=[-40,138,-33,151],/ADVANCE,position=[0.05,0.08,0.95,0.98],$
    label=2,latlab=138,lonlab=-33.2,color=0,/noerase
map_continents,/COASTS,/HIRES,color=0

colorbar,position=[0.1,0.15,0.45,0.17],$
    range=[levels(0),levels(n_elements(levels)-1)],$
    divisions=(nlevels-1)/2,ticknames=string(levels(iticks),format='(i2)'),ncolors=256,color=0,$
    charsize=1.5,charthick=3

cur_stats_lats = [-38.27,-38.3,-38.66,-37.38,-37.36,-38.6,-38.4]
cur_stats_lons = [141.98,142.0,146.30,143.10,143.60,145.5,141.4]
cur_stat_names=[' Codrington (18MW) ',' Yambuk (30MW) ',' Toora (21MW) ',' Challicum (53MW) ',$
    ' Waubra (192MW) ',' Wonthaggi (12MW) ',' Portland (51MW) ']

aligns = [1.0,0.0,0.0,1.0,0.0,0.0,1.0]
offset = [-0.1,0,0.1,0,0,-0.15,0.1]
cap = [18,30,21,53,192,12,51]
nstats = n_elements(cur_stat_names)

; get times series for the separate locations
mask2 = mask

spots_wind = lonarr(nwind_stats)

for icount = 0,nwind_stats-1 do BEGIN
    spot = where(tot_power*mask2 eq max(tot_power*mask2))
    spots_wind(icount) = spot
    print,spot,newlats(spot),newlons(spot)

    usersym,[-1,0,1,-1],[-1,1,-1,-1],/fill,color=250
    oplot,newlons(spot),newlats(spot), psym=8,color=250,symsize=3

    x1 = newlons(spot)
    y1 = newlats(spot)

    ; remove area from the mask
    blank = where(newlons gt x1(0)-maskrange and newlons lt x1(0)+maskrange and  $
        newlats gt y1(0)-maskrange and newlats lt y1(0)+maskrange)
    mask2(blank)=0
endfor

usersym,[-1,1,0,-1],[1,1,-1,1],/fill,color=0
usersym,[-1,0,1,-1],[-1,1,-1,-1],/fill,color=250
plots,145,-39.88, psym=8,color=250,symsize=3
xyouts,145.5,-39.95,'Possible wind farm sites',color=0,charsize=2,charthick=5

if plotps eq 1 then BEGIN
    device,/close
    spawn,'convert -density 300 map.ps map.jpg'
endif
;if plotps eq 0 then stop

SW_av = total(SW_main,3)/n_elements(SW_main(0,0,*))

; plot the average solar power
levels=findgen(20)*8+100
nlevels = n_elements(levels)
iticks = indgen((nlevels+1)/2)*2

if plotps eq 1 then BEGIN
    set_plot,'ps'
    filename='solar_map.ps'
    device,color=1,filename=filename,/landscape
    thick = 6.0
endif

if plotps eq 0 then BEGIN
    map_set,/CYLINDRICAL,limit=[-40,138,-33,151],/ADVANCE,position=[0.05,0.08,0.95,0.98],$
       label=2,latlab=138,lonlab=-33.2,color=0
    erase,color=255
endif
map_set,/CYLINDRICAL,limit=[-40,138,-33,151],/ADVANCE,position=[0.05,0.08,0.95,0.98],$
    label=2,latlab=138,lonlab=-33.2,color=0,/noerase
temp = SW_av*mask
ii = where(temp eq 0)
temp(ii) = 10000000.
contour,temp,newlons,newlats,/fill,levels=levels,/overplot,xticks=1,yticks=1
map_set,/CYLINDRICAL,limit=[-40,138,-33,151],/ADVANCE,position=[0.05,0.08,0.95,0.98],$
    label=2,latlab=138,lonlab=-33.2,color=0,/noerase
map_continents,/COASTS,/HIRES,color=0

colorbar,position=[0.1,0.15,0.45,0.17],$
    range=[levels(0),levels(n_elements(levels)-1)],$
    divisions=(nlevels-1)/2,ticknames=string(levels(iticks),format='(i3)'),ncolors=256,color=0,$

mask2 = mask

spots_sun = lonarr(nsun_stats)

for icount = 0,nsun_stats-1 do BEGIN
    spot = where(SW_av*mask2 eq max(SW_av*mask2))
    spots_sun(icount) = spot
    print,spot,newlats(spot),newlons(spot)

    usersym,[-1,0,1,-1],[-1,1,-1,-1],/fill
    oplot,newlons(spot),newlats(spot), psym=8,color=0,symsize=3

    x1 = newlons(spot)
    y1 = newlats(spot)

    ; remove area from the mask
    blank = where(newlons gt x1(0)-maskrange_sun and newlons lt x1(0)+maskrange_sun and  $
        newlats gt y1(0)-maskrange_sun and newlats lt y1(0)+maskrange_sun)
    mask2(blank)=0
endfor

usersym,[-1,1,0,-1],[1,1,-1,1],/fill,color=0
usersym,[-1,0,1,-1],[-1,1,-1,-1],/fill,color=250
plots,145,-39.88, psym=8,color=250,symsize=3
xyouts,145.5,-39.95,'Possible solar farm sites',color=0,charsize=2,charthick=5


if plotps eq 1 then BEGIN
    device,/close
    spawn,'convert -density 300 map.ps map.jpg'
endif
if plotps eq 0 then stop


; find closest points to current stations
times = findgen(nsteps)
times = times/48.

print,'=-=-=-=-=-=-=-=-=-=-=-=-=-'


temp_cur = fltarr(nstats,nsteps)

for i = 0,nstats-1 do BEGIN
    findloc,newlons,newlats,cur_stats_lons(i),cur_stats_lats(i),ix,iy,ispot
    temp_cur(i,*) = power_ts(ix,iy,*) * cap(i)/2500
endfor

temp_cur_tot = total(temp_cur,1) / total(cap) * 100.

nlons = n_elements(newlons(*,0))
nlats = n_elements(newlons(0,*))

print,'nlons,nlats = ',nlons,nlats

findloc,newlons,newlats,144.9,-37.8,ix,iy,ispot
solar_melb = SW_main(ix,iy,*)

nsteps = n_elements(power_ts(0,0,*))

ts_wind = fltarr(nwind_stats,nsteps)
for icount = 0,nwind_stats-1 do BEGIN
   iy = spots_wind(icount)/ nlons
   ix = spots_wind(icount) - iy * nlons
   ts_wind(icount,*) = power_ts(ix,iy,*)
endfor
ts_sun = fltarr(nsun_stats,nsteps)
for icount = 0,nsun_stats-1 do BEGIN
   iy = spots_sun(icount)/ nlons
   ix = spots_sun(icount) - iy * nlons
   ts_sun(icount,*) = SW_main(ix,iy,*)
endfor

ts_tot = total(ts_wind,1)/(2500L*nwind_stats)*100

endif  ; end if over skip = 1,2

if skip ne 3 then save,solar_melb,times,ts_tot,temp_cur_tot,ts_wind,nwind_stats,nsteps,nstats,$
    cur_stats_lons,cur_stats_lats,temp_cur,cap,spots_wind,newlats,newlons,$
    ts_sun,nsun_stats,spots_sun,$
    file='SAVE_ts'
   
if skip eq 3 then BEGIN
     print,'RESTORING from SAVE_ts'
     restore,'SAVE_ts'
endif


plot,times,ts_wind(0,*),xtitle='Days',ytitle='Power output (MW) per point'
for icount = 1,nwind_stats-1 do BEGIN
    oplot,times,ts_wind(icount,*),color=icount*20+20
endfor

if plotps eq 0 then stop


if plotps eq 1 then BEGIN
    set_plot,'ps'
    filename='ts_1.ps'
    device,color=1,filename=filename,xsize=24,ysize=16,yoffset=1.0
    thick = 6.0
endif

plot,times,ts_tot,yrange=[0,112],xtitle='Days (starting at midnight)',ytitle='% capacity',$
    xthick=5,ythick=5,charsize=2,charthick=5,thick=5,/nodata,background=255,color=0,$
    position=[0.2,0.2,0.9,0.9],ystyle=1
oplot,times,ts_tot,color=160,thick=5
oplot,times,temp_cur_tot,color=100,thick=5
oplot,[2.5,3.0],[107,107],color=100,thick=5
xyouts,3.1,105,'Current network',color=0,charsize=2,charthick=2
oplot,[2.5,3.0],[102,102],color=160,thick=5
xyouts,3.1,100,'Theoretical network',color=0,charsize=2,charthick=2
oplot,[2.5,3.0],[97,97],color=240,thick=5
xyouts,3.1,95,'Melbourne solar',color=0,charsize=2,charthick=2

oplot,times,solar_melb/max(solar_melb)*75,color=240,thick=5

if plotps eq 1 then BEGIN
    device,/close
    spawn,'convert -density 300 ts_1.ps ts_1.jpg'
endif

if plotps eq 1 then BEGIN
    set_plot,'ps'
    filename='ts_2.ps'
    ;device,color=1,filename=filename,xsize=24,ysize=16,yoffset=1.0,/landscape
    device,color=1,filename=filename,/landscape
    thick = 6.0
endif

plot,times,ts_tot,yrange=[-3000,9000],xtitle='Days (starting at midnight)',ytitle='MW',$
    xthick=5,ythick=5,charsize=2,charthick=5,thick=5,/nodata,background=255,color=0,$
    position=[0.2,0.2,0.9,0.9],ystyle=1

restore,'../Electricity/SAVE_all'

juldayend = julday(9,7,2009)
juldaystart= julday(9,1,2009)

ii = where(time gt juldaystart and time lt juldayend)

oplot,time(ii)-juldaystart-0.5,demand(ii),color=0,thick=5

tot_pot = ts_tot*60 + solar_melb/max(solar_melb)*3000

; 3 GW solar and 60*377 Wind (20 GW)

diff = demand(ii(24:263))-tot_pot
oplot,times,diff,color=0,thick=5

; polyfill the diff line

ii = where(diff le 0)
jj = where(diff gt 0)

diff_temp = diff
diff_temp(ii) = 0.0

times2 = fltarr(nsteps+2)
times2(0:nsteps-1) = times
times2(nsteps)=times(nsteps-1)
times2(nsteps+1) = 0.0

diff2 = fltarr(nsteps+2)
diff2(0:nsteps-1) = diff_temp
diff2(nsteps)=0.0
diff2(nsteps+1) = 0.0
polyfill,times2,diff2,color=240

diff_temp = diff
diff_temp(jj) = 0.0
diff2 = fltarr(nsteps+2)
diff2(0:nsteps-1) = diff_temp
diff2(nsteps)=0.0
diff2(nsteps+1) = 0.0
polyfill,times2,diff2,color=140

oplot,times,tot_pot,color=80,thick=5


oplot,[2.2,2.4],[8200,8200],color=0,thick=5
oplot,[2.2,2.4],[7500,7500],color=80,thick=5

xyouts,2.5,8100,'Demand',color=0,charsize=2,charthick=5
xyouts,2.5,7400,'Supply',color=0,charsize=2,charthick=5

; add legend for color filled

usersym,[0,0,1,1,0],[0,1,1,0,0],/FILL,color=240
plots,2.2,-1250,psym=8,symsize=5
usersym,[0,0,1,1,0],[0,1,1,0,0],/FILL,color=140
plots,2.2,-2150,psym=8,symsize=5

xyouts,2.5,-1200,'Deficit',color=0,charsize=2,charthick=5
xyouts,2.5,-2100,'Excess',color=0,charsize=2,charthick=5

oplot,[1.25,1.83],[6600,6600],color=0,thick=2
oplot,[1.25,1.25],[6650,6550],color=0,thick=2
oplot,[1.83,1.83],[6650,6550],color=0,thick=2

oplot,[0.83,1.25],[4000,4000],color=0,thick=2
oplot,[1.25,1.25],[4050,3950],color=0,thick=2
oplot,[0.83,0.83],[4050,3950],color=0,thick=2

xyouts,0.5,3500,'Overnight demand',color=0,charthick=3,charsize=1.2
xyouts,1.0,7000,'Daytime demand',color=0,charthick=3,charsize=1.2

if plotps eq 1 then BEGIN
    device,/close
    spawn,'convert -density 300 ts_2.ps ts_2.jpg'
endif

; write out the time series ts_tot and temp_cur

openw,lun,'current_actual.txt',/get_lun
for i = 0,nstats -1 do BEGIN
    for j = 0,nsteps-1 do BEGIN
        printf,lun,i,',',cur_stats_lons(i),',',cur_stats_lats(i),',',times(j),',',temp_cur(i,j)
    endfor
endfor
free_lun,lun

openw,lun,'current_per2.5MW.txt',/get_lun
for i = 0,nstats -1 do BEGIN
    for j = 0,nsteps-1 do BEGIN
        printf,lun,i,',',cur_stats_lons(i),',',cur_stats_lats(i),',',times(j),',',temp_cur(i,j)/cap(i)*2.5
    endfor
endfor
free_lun,lun


openw,lun,'wind_theory.txt',/get_lun
for i = 0,nwind_stats -1 do BEGIN
    for j = 0,nsteps-1 do BEGIN
        printf,lun,i,',',newlons(spots_wind(i)),',',newlats(spots_wind(i)),',',times(j),',',ts_wind(i,j)/1000.
    endfor
endfor
free_lun,lun

openw,lun,'sun_theory.txt',/get_lun
for i = 0,nsun_stats -1 do BEGIN
    for j = 0,nsteps-1 do BEGIN
        printf,lun,i,',',newlons(spots_sun(i)),',',newlats(spots_sun(i)),',',times(j),',',ts_sun(i,j)/1000.
    endfor
endfor
free_lun,lun

stop
end

