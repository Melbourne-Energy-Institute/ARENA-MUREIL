pro select

plotps = 0

if plotps eq 0 then BEGIN
    set_plot,'x'
    device,DECOMPOSED=0
    window,0,xsize=900,ysize=900
    !p.background = 255
endif

if plotps eq 1 then BEGIN
    set_plot,'ps'
    filename='mask.ps'
    device,color=1,filename=filename,/portrait,$
    ;device,color=1,filename=filename,/landscape,$
    xsize=16,ysize=24,yoffset=1.0
    thick = 6.0
    !p.background = 255
endif


loadct,39


limit = [-45,112,-10,154] ; Australia
limit = [-39.5,140,-34,151] ; Victoria
posi  =  [0.1,0.2,0.9,0.9]


; get the states
readcsv,lons,lats,states,'STATES2.csv'
ii = where(states eq -9999.00)
states = states + 1
states(ii) = 0
ii = where(states eq 9)
states(ii) = 7
levels = indgen(10)
colors = indgen(11)*25
colors(0) = !p.background
;;plot_pixel,states,lons,lats,posi,levels,colors,limit

; code: WA = 3, NT = 2, QLD = 6, NSW = 7, VIC = 4, TAS = 1, SA = 4, ACT = 8

; get state parks

readcsv,lons,lats,NPARKS,'NATIONAL_PARKS2.csv'
readcsv,lons,lats,CAPAD,'CAPAD.csv'

ii = where(NPARKS eq -9999.0,nii)
data2 = NPARKS
data2(ii) = 0.0

ii = where(CAPAD eq -9999.0,nii)
nparks = CAPAD
nparks(ii) = 0.0

; add on the state parks where missing
ii = where(nparks eq 0 and data2 ne 0)
levels = indgen(40)*2
colors = indgen(41)*6
colors(0) = !p.background

;plot_pixel,nparks,lons,lats,posi,levels,colors,limit

readcsv,lons,lats,urban,'BUILTUP.csv'
ii = where(urban eq -9999.00)
urban = urban+1
urban(ii) = 0

levels = indgen(3)
colors = indgen(4)*60
colors(0) = !p.background
;plot_pixel,urban,lons,lats,posi,levels,colors,limit

readcsv,lons,lats,elecgrid,'DistToTMN_new2.csv'

ii = where(elecgrid gt 2000)
elecgrid(ii) = 2000.

;ii = where(states eq 0 or states eq 3 or states eq 2)
;elecgrid(ii) = 2000


levels = indgen(20)*10
;level = [0,0.1,0.2,0.5,1.0,2,3,4,6,8,10,20,50,100,200,500,1000,2000]
colors = reverse(indgen(19)*12)
colors(n_elements(colors)-1) = !p.background
plot_pixel,elecgrid,lons,lats,posi,levels,colors,limit


; now create a mask for the solar map

mask = elecgrid
mask = mask * (-1) +2000
mask = mask/2000.
;ii = where(elecgrid le 12)
;mask(ii) = 1.0

colors = findgen(10)*25
levels=[0,0.3,0.6,0.8,0.85,0.9,0.95,0.98,.099,0.995,1]
colors(0) = !p.background
;plot_pixel,mask,lons,lats,posi,levels,colors,limit

ii = where(states eq 3 or states eq 2)
mask(ii) = 0.0
;plot_pixel,mask,lons,lats,posi,levels,colors,limit

ii = where(nparks ne 0)
mask(ii) = 0.0
;plot_pixel,mask,lons,lats,posi,levels,colors,limit

ii = where(urban eq 1)
mask(ii) = 0
;plot_pixel,mask,lons,lats,posi,levels,colors,limit

getvar,'dsr_annualav',dsr,'dsr_annualav.nc'
getvar,'u80_annualav',wind,'u80_annualav.nc'
getvar,'lons',lons_dsr,'dsr_annualav.nc'
getvar,'lats',lats_dsr,'dsr_annualav.nc'

lats_dsr = lats_dsr - 0.11

; trim the mask file to be the same as the dsr
diff = (lons - lons_dsr(0))^2
lon_start = where(diff eq min(diff))
diff = (lons - lons_dsr(n_elements(lon_dsr)-1))^2
lon_end = where(diff eq min(diff))
diff = (lats - lats_dsr(0))^2
lat_start = where(diff eq min(diff))
diff = (lats - lats_dsr(n_elements(lat_dsr)-1))^2
lat_end = where(diff eq min(diff))

mask = mask(lon_start:lon_end,lat_start:lat_end)
elecgrid_trim = elecgrid(lon_start:lon_end,lat_start:lat_end)

levels = indgen(20)*10
colors = reverse(indgen(19)*12)
colors(n_elements(colors)-1) = !p.background
plot_pixel,elecgrid_trim,lons_dsr,lats_dsr,posi,levels,colors,limit
;plot_pixel,mask,lons_dsr,lats_dsr,posi,levels,colors,limit

levels = indgen(20)*10+100
colors = indgen(21)*12
colors(0) = !p.background
;plot_pixel,dsr,lons_dsr,lats_dsr,posi,levels,colors,limit
levels = indgen(20)*50+100
;plot_pixel,wind,lons_dsr,lats_dsr,posi,levels,colors,limit
;plot_pixel,dsr*mask,lons_dsr,lats_dsr,posi,levels,colors,limit


dsr_masked = dsr* mask
wind_masked = wind* mask

nsolar = 2
radius = 20
levels = indgen(20)*10+100
site_selection,dsr_masked,nsolar,radius,ibest_dsr,jbest_dsr,lats_dsr,lons_dsr,levels,colors,posi,limit
nwind = 2
radius = 10
levels = indgen(20)*50+100
site_selection,wind_masked,nwind,radius,ibest_wind,jbest_wind,lats_dsr,lons_dsr,levels,colors,posi,limit

; need to map the elecgrid to the same grid as the dsr and wind
dist_wind = elecgrid_trim(ibest_wind,jbest_wind)
dist_solar = elecgrid_trim(ibest_dsr,jbest_dsr)

if plotps then device,/close

windfile = '/mnt/meteo0/data/dargaville/rogerd/ACCESS-A/u80_complete_all-ACCESS.nc'
solarfile = '/mnt/meteo0/data/dargaville/rogerd/ACCESS-A/dsr_complete_all-ACCESS.nc'

extract,ibest_dsr,jbest_dsr,solarfile,ibest_wind,jbest_wind,windfile,data_selected,time

; weekly averages

;weeklyav,data_selected,data_averaged
;ii = indgen(n_elements(data_averaged(0,*)))*24*7
;time = time(ii)
;!p.multi=[0,2,2]
;plot,time,data_averaged(0,*),color=1,xtickunits='time',ytitle='Solar Irradiance Wm/2',$
; xrange=[julday(1,1,2010),julday(1,1,2011)]
;oplot,time,data_averaged(1,*),color=60
;oplot,time,data_averaged(2,*),color=240
;plot,time,data_averaged(3,*),color=1,xtickunits='time',ytitle='2.5MW turbine output',$
; xrange=[julday(1,1,2010),julday(1,1,2011)]
;oplot,time,data_averaged(4,*),color=60
;oplot,time,data_averaged(5,*),color=240


; write the output to a new file

;drop the NANs

counter = 0
data_final = fltarr(nwind+nsolar+1,17520)
time_final = dblarr(17520)

for i = 0,17519 do BEGIN

    if finite(total(data_selected(*,i))) eq 1 then BEGIN
        data_final(*,counter) = data_selected(*,i)
        time_final(counter) = time(i)
        counter = counter + 1
    endif
endfor

data_final = data_final(*,0:counter-1)
time_final = time_final(0:counter-1)


filename='ROGERS_wind_solar.nc'
varname = 'data'
ncid = NCDF_CREATE(filename,/CLOBBER)
soldimid = NCDF_DIMDEF(ncid,'solar_stations',nsolar)
winddimid = NCDF_DIMDEF(ncid,'wind_stations',nwind)
totdimid = NCDF_DIMDEF(ncid,'all_stations',nwind+nsolar)
zdimid = NCDF_DIMDEF(ncid,'time',n_elements(time_final))
tempid = NCDF_DIMDEF(ncid,'ntypes',2)

index = [tempid,totdimid]
dist_transm = NCDF_VARDEF(ncid,'dist_transm',index)
solar_indexid = NCDF_VARDEF(ncid,'solar_id',soldimid)
wind_indexid = NCDF_VARDEF(ncid,'wind_id',winddimid)
solid = NCDF_VARDEF(ncid,'solar',[soldimid,zdimid])
windid = NCDF_VARDEF(ncid,'wind',[winddimid,zdimid])
demandid = NCDF_VARDEF(ncid,'demand',zdimid)
zid = NCDF_VARDEF(ncid,'time',zdimid)
NCDF_control,ncid,/endef

tempdata = intarr(2,nwind+nsolar)
tempdata(1,0:nsolar-1) = dist_solar
tempdata(1,nsolar:nsolar+nwind-1) = dist_wind
tempdata(0,0:nsolar-1) = indgen(nsolar)+1001
tempdata(0,nsolar:nsolar+nwind-1) = indgen(nwind)+2001

NCDF_VARPUT,ncid,solar_indexid,indgen(nsolar)+1001
NCDF_VARPUT,ncid,wind_indexid,indgen(nwind)+2001
NCDF_VARPUT,ncid,dist_transm,tempdata
NCDF_VARPUT,ncid,solid,data_final(0:nsolar-1,*)
NCDF_VARPUT,ncid,windid,data_final(nsolar:nsolar+nwind-1,*)
NCDF_VARPUT,ncid,demandid,reform(data_final(nsolar+nwind,*))
NCDF_CLOSE, ncid

stop

end

pro extract,ibest_dsr,jbest_dsr,solarfile,ibest_wind,jbest_wind,windfile,data_all,time

nsolar = n_elements(jbest_dsr)
nwind = n_elements(jbest_wind)

data_all = fltarr(nsolar+nwind+1,17520)

counter = 0

for i = 0,nsolar-1 do BEGIN
    getvarsite,'dsr',data,solarfile,ibest_dsr(i),jbest_dsr(i)
    insert_spaces,'dsr',data,data_long
    data_all(counter,*) = data_long
    counter = counter + 1
endfor
for i = 0,nwind-1 do BEGIN
    getvarsite,'utotal',data,windfile,ibest_wind(i),jbest_wind(i)
    powercurve,data,power
    insert_spaces,'wind',power,data_long
    data_all(counter,*) = data_long
    counter = counter+1
endfor

restore,'/mnt/meteo0/data/dargaville/rhuva/SAVE_all'

time = time - 10/24.

caldat,time,month,day,year
ii = where(year eq 2010 or year eq 2011)

; grab every second point
temp = lindgen(17520)*2
tot_demand = total(demand,1)
tot_demand = tot_demand(ii(temp))

data_all(nsolar+nwind,*) = tot_demand

time = time(ii)
time = time(temp)

!p.multi=[0,2,2]

;plot,time,data_all(nsolar+nwind,*),color=1,xtickunits='time'
;plot,time,data_all(0,*),color=1,xtickunits='time'
;plot,time,data_all(nsolar,*),color=1,xtickunits='time'

end

pro insert_spaces,type,data,data_long

data_long = fltarr(17520)

if type eq 'dsr' then BEGIN
   data_long(0:293) = data(0:293)
   data_long(294:407) = !VALUES.F_NAN
   data_long(408:833) = data(294:719)
   data_long(834:911) = !VALUES.F_NAN
   data_long(912:923) = data(720:731)
   data_long(924:935) = !VALUES.F_NAN
   data_long(936:8753) = data(732:8549)
   data_long(8754:8759) = !VALUES.F_NAN
   data_long(8760:17519) = data(8550:17309)
endif

if type eq 'wind' then BEGIN
    data_long(0:293) = data(0:293)
    data_long(294:407) =  !VALUES.F_NAN
    data_long(408:719) = data(294:605)
    data_long(720:725) =  !VALUES.F_NAN
    data_long(726:833) = data(606:713)
    data_long(834:911) =  !VALUES.F_NAN
    data_long(912:923) = data(714:725)
    data_long(924:935) =  !VALUES.F_NAN
    data_long(936:8753) = data(726:8543)
    data_long(8754:8759) =  !VALUES.F_NAN
    data_long(8760:17519) = data(8544:17303)
endif 

end

pro site_selection,data,nsites,radius,ibest,jbest,lats,lons,levels,colors,posi,limit

; do site selection - find the best point and remove area around it

nlats = n_elements(lats)
nlons = n_elements(lons)

ibest = intarr(nsites)
jbest = intarr(nsites)

for in = 0,nsites-1 do BEGIN

    best = where(data eq max(data))

    jbest(in) = fix(best / nlons)
    ibest(in) = best - jbest(in)*nlons

    print,best,ibest(in),jbest(in)

    ; block out an area around the site

    disttopoint = fltarr(nlons,nlats)
    for ii = 0,nlons-1 do BEGIN
        for jj = 0,nlats-1 do BEGIN
            disttopoint(ii,jj) = sqrt((ibest(in)-ii)^2 + (jbest(in)-jj)^2)
        endfor
    endfor
    kk = where(disttopoint lt radius)
    data(kk) = 0.0
endfor    
;plot_pixel,data,lons,lats,posi,levels,colors,limit
;plots,lons(ibest),lats(jbest),psym=2,color=1

end


pro plot_pixel,data,lons,lats,posi,levels,colors,limit

map_set,0,180,/CYLINDRICAL,limit=limit,position=posi
;map_grid,/label,font=1,latdel=30,londel=30
pixelplot,data,lons,lats,levels,colors
map_set,0,180,/CYLINDRICAL,/continents,/NOERASE,limit=limit,position=posi,color=0,mlinethick=1,/hires
map_grid,/label,increment=30,color=0

;stop

end

pro powercurve,data,power

power = fltarr(n_elements(data))

ii = where(data lt 4.0,nii)
if nii gt 0 then power(ii) = 0
ii = where(data gt 13.0,nii)
if nii gt 0 then power(ii) = 2500
ii = where(data ge 4.0 and data lt 9.,nii)
if nii gt 0 then power(ii) = data(ii)*data(ii)*38.5 - 231.1*data(ii) + 358.0
ii = where(data ge 9.0 and data le 13.,nii)
if nii gt 0 then power(ii) = -1*data(ii)*data(ii)*81.4 + 2065.4*data(ii) - 10596.0

end

pro weeklyav,datain,dataout

nfields = n_elements(datain(*,0))
; how many loops?
nsteps = n_elements(datain(0,*))
nsegments = fix(nsteps / (24*7))
dataout = fltarr(nfields,nsegments)

for i = 0,nfields-1 do BEGIN
    istart = 0
    iend = istart +(24*7)-1
    for j = 0,nsegments-1 do BEGIN
        dataout(i,j) = total(datain(i,istart:iend))/(24*7)
        istart = istart + 24*7
        iend = istart +(24*7)-1
    endfor
endfor

end
