pro nodal_demand

!p.multi=[0,2,3]

; make a csv file with hourly demand data for each node in the 21 node model

; or a netCDF file

year = 2013

nodes = ['NQ','CQ','SWQ','SEQ','NNSW','Hunter','Central','SYD','STHRN','CAN','SWNSW','NVIC','CVIC','LV','MEL','WVIC','SESA','ADE','NSA','FNSA','TAS']

statenodes = ['QLD1','QLD1','QLD1','QLD1','NSW1','NSW1','NSW1','NSW1','NSW1','NSW1','NSW1','VIC1','VIC1','VIC1','VIC1','VIC1','SA1','SA1','SA1','SA1','TAS1']

; data from roam for breakdown

peak = [9,21,7,63,9,19,5,53,6,6,5,5,8,5,81,1,6,71,12,11,100]
offpeak = [19,34,7,40,4,31,7,39,7,5,7,6,7,6,80,1,9,59,12,20,100]

; read in the demand data
states = ['NSW1','QLD1','SA1','TAS1','VIC1','SNOWY']
file = '/home/UNIMELB/rogerd/DEMAND/ALL_DEMAND.nc'

getvar,'date',dates,file
getvar,'demand',demand,file
getvar,'price',price,file

caldat,dates,months,days,years,hours,minutes

; get the year and hourly data

;mm = where(years eq year and minutes eq 0,nmm)
mm = where(years eq year and minutes eq 0  and hours lt 4 and days eq 1 and months eq 1,nmm)
if nmm eq 0 then stop

select_demand = demand(*,mm)

regional_demand = fltarr(21,nmm)

is_1 = 10

for i = 0,20 do BEGIN

    is = where(states eq statenodes(i))

    ; is this peak or offpeak? 
    peak_offpeak,dates(mm),statenodes(i),peak_or_not

    kk = where(peak_or_not eq 1)
    regional_demand(i,kk) = select_demand(is(0),kk) * peak(i)/100.
    kk = where(peak_or_not eq 2)
    regional_demand(i,kk) = select_demand(is(0),kk) * offpeak(i)/100.
endfor

; fix the Portland smelter problem
ii = where(nodes eq 'MEL')
jj = where(nodes eq 'WVIC')

regional_demand(ii,*) = regional_demand(ii,*) - 900
regional_demand(jj,*) = regional_demand(jj,*) + 900

for i = 0,20 do BEGIN

    is = where(states eq statenodes(i))

    if is(0) ne is_1 then BEGIN
         ;plot,select_demand(is(0),0:1000)
         ;runtot = fltarr(1000)
         counter = 0
     endif

    counter = counter + 1

    is_1 = is(0)

    ;runtot = runtot+regional_demand(i,0:1000)
    ;oplot,runtot,color=counter*40

endfor

; create the output file

; first a netCDF

;ncid = NCDF_CREATE('demand_regional.nc',/CLOBBER)
ncid = NCDF_CREATE('demand_regional_short.nc',/CLOBBER)
xdimid = NCDF_DIMDEF(ncid,'time',nmm)
if (xdimid eq -1) then stop,'error'
ydimid = NCDF_DIMDEF(ncid,'nodes',21)
if (ydimid eq -1) then stop,'error'

nodes_id = NCDF_VARDEF(ncid,'demand_hdr',ydimid,/SHORT)
xid = NCDF_VARDEF(ncid,'time',xdimid,/DOUBLE)
if xid eq -1 then stop
;dims = [xdimid,ydimid]
dims = [ydimid,xdimid]
demandid = NCDF_VARDEF(ncid,'demand',dims,/FLOAT)
if demandid eq -1 then stop

NCDF_control,ncid,/endef

temp = dates(mm)
NCDF_VARPUT,ncid,nodes_id,indgen(21)
NCDF_VARPUT,ncid,xid,temp
NCDF_VARPUT,ncid,demandid,regional_demand

NCDF_CLOSE, ncid


; then a csv

;openw,lun,'demand_regional.csv',/get_lun
openw,lun,'demand_regional_short.csv',/get_lun

header = 'Time,'

for i=0,20 do BEGIN
   header = header + nodes(i)
   if i lt 20 then header = header + ','
endfor

printf,lun,header

caldat,dates(mm),months,days,years,hours,minutes

for i = 0,nmm-1 do BEGIN
    if days(i) gt 10 then line = string(days(i),format='(i2)') $
        else line = '0'+string(days(i),format='(i1)')

    line = line+'/'
    if months(i) gt 10 then line = line+string(months(i),format='(i2)') $
         else line = line + '0'+ string(months(i),format='(i1)')
    line = line+'/'+string(years(i),format='(i4)')+' '
    if hours(i) lt 10 then line = line + '0'+string(hours(i),format='(i1)') $
        else line = line + string(hours(i),format='(i2)')
    line = line + ':00,'

    for j=0,20 do BEGIN
        line = line + string(regional_demand(j,i) ,format='(f6.1)')
        if j lt 20 then line = line + ','
    endfor

    printf,lun,line

    print,i

endfor

free_lun,lun

stop

end

